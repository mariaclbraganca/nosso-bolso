import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';
import 'gemini_key_service.dart';
import 'notificacao_fila_service.dart';
import '../utils/moeda.dart';

/// Processa notificações do Nubank capturadas pelo listener central (IfoodNotificationService).
/// Estratégia: tenta regex primeiro (rápido, sem custo). Se falhar, usa Gemini como fallback.
class NubankNotificationService {
  static const _pkgNubank = 'com.nu.production';

  // Compra no cartão: "Compra de R$ 183,68 aprovada em Posto Da Mata para o cartão..."
  static final _regexCompra = RegExp(
    r'[Cc]ompra de R\$\s*([\d.,]+)\s+aprovada?\s+em\s+(.+?)(?:\s+para\b|\.{2,}|par\.{0,3}\s*$|\.\s*$|\s*$)',
    caseSensitive: false,
  );
  // Pix enviado: "Você enviou R$ 50,00 para João Silva."
  static final _regexPixEnviado = RegExp(
    r'[Vv]oc[êe]\s+(?:pagou|enviou)\s+R\$\s*([\d.,]+)\s+para\s+(.+?)(?:\.+\s*$|\s*$)',
    caseSensitive: false,
  );
  // Pix recebido: "Você recebeu uma transferência de R$ 0,10 de João Silva."
  static final _regexPixRecebido = RegExp(
    r'[Vv]oc[êe]\s+recebeu\s+(?:uma\s+transferência\s+de\s+)?R\$\s*([\d.,]+)\s+de\s+(.+?)(?:\.+\s*$|\s*$)',
    caseSensitive: false,
  );

  /// Chamado pelo IfoodNotificationService para cada notificação recebida.
  static Future<void> processar(NotificationEvent evt) async {
    final pkg = evt.packageName ?? '';
    if (pkg != _pkgNubank) return;

    final titulo = evt.title ?? '';
    final corpo = evt.text ?? '';
    // tickerText não é bloqueado por vis=PRIVATE — fonte mais confiável para Nubank
    final ticker = (evt.raw?['tickerText'] as String?) ?? '';

    // Log local (não polui o Sentry com eventos de sucesso)
    debugPrint('[Nubank] Raw event — title=$titulo text=$corpo ticker=$ticker');

    // Prioridade: ticker (mais completo) > title+text > só title
    final texto = ticker.isNotEmpty ? ticker
        : '$titulo $corpo'.trim().isNotEmpty ? '$titulo $corpo'.trim()
        : titulo;
    await processarTexto(texto);
  }

  // Textos processados recentemente (evita listener + bandeja processarem 2x).
  static final Map<String, DateTime> _recentes = {};

  static bool _jaProcessado(String texto) {
    final agora = DateTime.now();
    _recentes.removeWhere((_, t) => agora.difference(t).inMinutes >= 5);
    if (_recentes.containsKey(texto)) return true;
    _recentes[texto] = agora;
    return false;
  }

  /// Processa texto de notificação diretamente (usado pelo ActiveNotificationsService).
  static Future<void> processarTexto(String texto) async {
    if (texto.isNotEmpty && _jaProcessado(texto)) {
      debugPrint('[Nubank] Texto repetido ignorado (dedup local)');
      return;
    }
    debugPrint('[Nubank] Notificação recebida: $texto');

    if (texto.isEmpty) {
      Sentry.addBreadcrumb(Breadcrumb(
        message: '[Nubank] Texto vazio — ignorado',
        category: 'nubank',
        level: SentryLevel.warning,
      ));
      return;
    }

    String? estabelecimento;
    double? valor;
    String origem = 'nubank';

    // 1. Compra no cartão
    final matchCompra = _regexCompra.firstMatch(texto);
    if (matchCompra != null) {
      valor = _parseValor(matchCompra.group(1)!);
      estabelecimento = _limparNome(matchCompra.group(2)!);
      origem = 'nubank_cartao';
      Sentry.addBreadcrumb(Breadcrumb(
        message: '[Nubank] Regex compra OK',
        category: 'nubank',
        level: SentryLevel.info,
        data: {'estabelecimento': estabelecimento, 'valor': valor},
      ));
    }

    // 2. Pix enviado
    if (valor == null) {
      final matchPix = _regexPixEnviado.firstMatch(texto);
      if (matchPix != null) {
        valor = _parseValor(matchPix.group(1)!);
        estabelecimento = _limparNome(matchPix.group(2)!);
        origem = 'nubank_pix_enviado';
        Sentry.addBreadcrumb(Breadcrumb(
          message: '[Nubank] Regex Pix enviado OK',
          category: 'nubank',
          level: SentryLevel.info,
          data: {'estabelecimento': estabelecimento, 'valor': valor},
        ));
      }
    }

    // 3. Pix recebido — registra como receita (valor negativo sinaliza entrada)
    if (valor == null) {
      final matchRecebido = _regexPixRecebido.firstMatch(texto);
      if (matchRecebido != null) {
        valor = _parseValor(matchRecebido.group(1)!);
        estabelecimento = _limparNome(matchRecebido.group(2)!);
        origem = 'nubank_pix_recebido';
        Sentry.addBreadcrumb(Breadcrumb(
          message: '[Nubank] Regex Pix recebido OK',
          category: 'nubank',
          level: SentryLevel.info,
          data: {'de': estabelecimento, 'valor': valor},
        ));
      }
    }

    // 2. Fallback: Gemini parseia o texto quando regex falha
    if (valor == null || estabelecimento == null) {
      debugPrint('[Nubank] Regex falhou, tentando Gemini para: $texto');
      Sentry.addBreadcrumb(Breadcrumb(
        message: '[Nubank] Regex falhou — usando Gemini',
        category: 'nubank',
        level: SentryLevel.warning,
        data: {'texto': texto},
      ));
      final resultado = await _parsearComGemini(texto);
      if (resultado != null) {
        valor = resultado['valor'] as double?;
        estabelecimento = resultado['estabelecimento'] as String?;
      }
    }

    if (valor == null || valor <= 0 || estabelecimento == null) {
      debugPrint('[Nubank] Não foi possível extrair dados de: $texto');
      await Sentry.captureMessage(
        '[Nubank] Falha total ao extrair dados',
        level: SentryLevel.error,
        withScope: (scope) => scope.setExtra('texto', texto),
      );
      return;
    }

    final hoje = DateTime.now().toIso8601String().substring(0, 10);
    debugPrint('[Nubank] Capturado ($origem): $estabelecimento R\$$valor em $hoje');
    // Mapeia origem → tipo que o backend entende (roteia receita vs gasto)
    final tipo = switch (origem) {
      'nubank_pix_recebido' => 'pix_recebido',
      'nubank_pix_enviado' => 'pix_enviado',
      _ => 'compra',
    };
    await _criarCompraPendente(estabelecimento, valor, hoje, origem, tipo);
  }

  /// Usa Gemini para extrair valor e estabelecimento de textos que o regex não capturou.
  static Future<Map<String, dynamic>?> _parsearComGemini(String texto) async {
    try {
      final body = {
        'contents': [
          {
            'parts': [
              {
                'text': '''Extraia o valor em reais e o nome do estabelecimento desta notificação financeira do Nubank.
O texto pode estar truncado pelo Android (terminando com "..." ou "par...").

Notificação: "$texto"

Responda SOMENTE com JSON, sem markdown:
{"valor": 183.68, "estabelecimento": "Posto Da Mata"}

Regras:
- valor: número decimal com ponto (não vírgula)
- estabelecimento: nome limpo em Title Case, sem "para o cartão", sem "..."
- Se não for uma compra ou Pix, responda: {"valor": null, "estabelecimento": null}'''
              }
            ]
          }
        ],
        'generationConfig': {'temperature': 0.0},
      };

      final resp = await GeminiKeyService.post(body, timeout: const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text == null) return null;

      final jsonStr = geminiExtrairJson(text);
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

      final valorRaw = parsed['valor'];
      final estabRaw = parsed['estabelecimento'] as String?;

      if (valorRaw == null || estabRaw == null) return null;

      final valor = (valorRaw as num).toDouble();
      if (valor <= 0) return null;

      return {'valor': valor, 'estabelecimento': _limparNome(estabRaw)};
    } catch (e) {
      debugPrint('[Nubank] Erro no fallback Gemini: $e');
      return null;
    }
  }

  static Future<void> _criarCompraPendente(
    String estabelecimento,
    double valor,
    String data,
    String origem,
    String tipo,
  ) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        await Sentry.captureMessage('[Nubank] session null — não inseriu',
            level: SentryLevel.warning,
            withScope: (s) => s.setExtra('origem', origem));
        return;
      }

      // Tenta pegar do metadata da sessão (caminho rápido)
      String familiaId = session.user.userMetadata?['familia_id'] as String? ?? '';

      // Fallback: busca direto na tabela de usuários se o metadata estiver vazio
      if (familiaId.isEmpty) {
        final row = await Supabase.instance.client
            .from('usuarios')
            .select('familia_id')
            .eq('id', session.user.id)
            .maybeSingle();
        familiaId = row?['familia_id'] as String? ?? '';
      }

      if (familiaId.isEmpty) {
        await Sentry.captureMessage('[Nubank] familia_id vazio mesmo após fallback DB',
            level: SentryLevel.error,
            withScope: (s) => s.setExtra('email', session.user.email ?? ''));
        return;
      }

      const endpoint = '/api/v1/compras/notificacao-nubank';
      final body = {
        'familia_id': familiaId,
        'estabelecimento': estabelecimento,
        'valor': valor,
        'data': data,
        'tipo': tipo,
        'usuario_id': session.user.id,
      };
      final resp = await http
          .post(
            Uri.parse('${ApiService.baseUrl}$endpoint'),
            headers: ApiService.authHeaders(json: true),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      // 201 = criado; 200 = duplicata ignorada ou receita lançada
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        debugPrint('[Nubank] Processado ($tipo): $estabelecimento R\$$valor');
        await NotificacaoFilaService.flush(); // drena fila acumulada
      } else if (resp.statusCode >= 500 ||
          resp.statusCode == 408 ||
          resp.statusCode == 429) {
        // Falha transitória → não perde a compra: enfileira p/ retry.
        await NotificacaoFilaService.enfileirar(endpoint, body);
      } else {
        await Sentry.captureMessage('[Nubank] API retornou ${resp.statusCode}',
            level: SentryLevel.error,
            withScope: (s) {
              s.setExtra('body', resp.body);
              s.setExtra('origem', origem);
            });
      }
    } catch (e, st) {
      // Rede caiu no meio → enfileira p/ reenviar quando reconectar.
      debugPrint('[Nubank] Erro ao criar compra pendente, enfileirando: $e');
      await NotificacaoFilaService.enfileirar(
        '/api/v1/compras/notificacao-nubank',
        {
          'estabelecimento': estabelecimento,
          'valor': valor,
          'data': data,
          'tipo': tipo,
        },
      );
      await Sentry.captureException(e, stackTrace: st);
    }
  }

  static double? _parseValor(String raw) {
    final v = parseMoeda(raw);
    return v > 0 ? v : null;
  }

  static String _limparNome(String raw) {
    return raw
        .trim()
        .replaceAll(RegExp(r'[.]{2,}'), '') // remove "..."
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}
