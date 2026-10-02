import 'dart:convert';
import 'package:flutter/foundation.dart' show kReleaseMode, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'api_service.dart' show ApiException;

/// Extrai o `detail` de um corpo de erro do backend (formato {"detail": "..."}).
String _detailDe(String body, int status) {
  try {
    final parsed = jsonDecode(body);
    if (parsed is Map && parsed['detail'] != null) {
      final d = parsed['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty && d.first is Map && d.first['msg'] != null) {
        return d.first['msg'].toString();
      }
      return d.toString();
    }
  } catch (_) {}
  return 'Erro $status';
}

/// Serviço para os módulos financeiros adicionais: Contas a Pagar, Metas de Economia e Insights.
class FinanceiroExtService {
  static const String _prodUrl = 'https://nosso-bolso-api.onrender.com';

  static String get baseUrl {
    if (kReleaseMode) return _prodUrl;
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return _prodUrl;
    }
    return 'http://localhost:8000';
  }

  static const _kTimeout    = Duration(seconds: 30);
  static const _kAiTimeout  = Duration(seconds: 90);

  static Map<String, String> _headers({bool json = false}) {
    final token = supabase.auth.currentSession?.accessToken;
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> _get(String url, {Map<String, String>? params, Duration? timeout}) async {
    final uri = Uri.parse(url).replace(queryParameters: params ?? {});
    final res = await http.get(uri, headers: _headers()).timeout(timeout ?? _kTimeout);
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('GET $url failed ${res.statusCode}: ${res.body}');
  }

  static Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse(url), headers: _headers(json: true), body: jsonEncode(body))
        .timeout(_kTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) return jsonDecode(res.body) as Map<String, dynamic>;
    throw ApiException(_detailDe(res.body, res.statusCode), res.statusCode);
  }

  static Future<Map<String, dynamic>> _patch(String url, Map<String, dynamic> body) async {
    final res = await http.patch(Uri.parse(url), headers: _headers(json: true), body: jsonEncode(body))
        .timeout(_kTimeout);
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw ApiException(_detailDe(res.body, res.statusCode), res.statusCode);
  }

  static Future<void> _delete(String url) async {
    final res = await http.delete(Uri.parse(url), headers: _headers()).timeout(_kTimeout);
    if (res.statusCode != 200) throw ApiException(_detailDe(res.body, res.statusCode), res.statusCode);
  }

  /// GET que devolve lista sob uma chave (o backend às vezes devolve {"key": [...]}
  /// e às vezes a lista direto). Normaliza os dois casos.
  static Future<List<Map<String, dynamic>>> _getList(String url, {Map<String, String>? params, String? key, Duration? timeout}) async {
    final uri = Uri.parse(url).replace(queryParameters: params ?? {});
    final res = await http.get(uri, headers: _headers()).timeout(timeout ?? _kTimeout);
    if (res.statusCode != 200) throw ApiException(_detailDe(res.body, res.statusCode), res.statusCode);
    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    if (decoded is Map && key != null && decoded[key] is List) {
      return (decoded[key] as List).cast<Map<String, dynamic>>();
    }
    return const [];
  }

  // ── Contas a Pagar ────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getContas(
    String familiaId, {
    String? mes,
    bool incluirPagas = true,
  }) async {
    final res = await _get(
      '$baseUrl/api/v1/financeiro/contas-pagar',
      params: {
        'familia_id': familiaId,
        if (mes != null) 'mes': mes,
        'incluir_pagas': '$incluirPagas',
      },
    );
    return (res['contas'] as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> criarConta(Map<String, dynamic> payload) =>
      _post('$baseUrl/api/v1/financeiro/contas-pagar', payload);

  static Future<Map<String, dynamic>> marcarPaga(String contaId, {bool pago = true}) =>
      _patch('$baseUrl/api/v1/financeiro/contas-pagar/$contaId/pagar', {'pago': pago});

  static Future<void> deletarConta(String contaId) =>
      _delete('$baseUrl/api/v1/financeiro/contas-pagar/$contaId');

  static Future<Map<String, dynamic>> getResumoContas(String familiaId, String mes) =>
      _get('$baseUrl/api/v1/financeiro/contas-pagar/resumo',
          params: {'familia_id': familiaId, 'mes': mes});

  // ── Metas de Economia ─────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getMetas(String familiaId) async {
    final res = await _get('$baseUrl/api/v1/financeiro/metas-economia',
        params: {'familia_id': familiaId});
    return (res['metas'] as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> criarMeta(Map<String, dynamic> payload) =>
      _post('$baseUrl/api/v1/financeiro/metas-economia', payload);

  static Future<Map<String, dynamic>> contribuirMeta(
    String metaId, {
    required double valor,
    String descricao = '',
  }) =>
      _patch('$baseUrl/api/v1/financeiro/metas-economia/$metaId/contribuir',
          {'valor': valor, 'descricao': descricao});

  static Future<void> deletarMeta(String metaId) =>
      _delete('$baseUrl/api/v1/financeiro/metas-economia/$metaId');

  // ── Astrix Insights ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getInsights(
    String membroId,
    String familiaId,
  ) =>
      _get(
        '$baseUrl/api/v1/saude/insights',
        params: {'membro_id': membroId, 'familia_id': familiaId},
        timeout: _kAiTimeout,
      );

  // ── Parcelas ──────────────────────────────────────────────────────────────
  // Compras parceladas com contagem regressiva. O backend gera as N transações.

  /// Lista as parcelas da família. Cada item traz `parcelas_pagas` e
  /// `parcelas_restantes` (calculados pelo backend a partir das datas).
  static Future<List<Map<String, dynamic>>> getParcelas(
    String familiaId, {
    bool apenasAtivas = true,
  }) =>
      _getList('$baseUrl/parcelas/', params: {
        'familia_id': familiaId,
        'apenas_ativas': '$apenasAtivas',
      });

  /// Cria uma compra parcelada. O backend gera automaticamente as N transações
  /// (uma por mês). Retorna a parcela-mãe + quantas transações foram geradas.
  static Future<Map<String, dynamic>> criarParcela({
    required String descricao,
    required double valorTotal,
    required int numParcelas,
    required String dataPrimeira, // 'YYYY-MM-DD'
    required String familiaId,
    required String usuarioId,
    String? envelopeId,
    String? cartao,
  }) =>
      _post('$baseUrl/parcelas/', {
        'descricao': descricao,
        'valor_total': valorTotal,
        'num_parcelas': numParcelas,
        'data_primeira': dataPrimeira,
        'familia_id': familiaId,
        'usuario_id': usuarioId,
        if (envelopeId != null) 'envelope_id': envelopeId,
        if (cartao != null && cartao.isNotEmpty) 'cartao': cartao,
      });

  /// Cancela uma parcela. Por padrão remove só as parcelas ainda não vencidas
  /// (o trigger do banco estorna o saldo automaticamente).
  static Future<void> cancelarParcela(
    String parcelaId, {
    required String familiaId,
    bool apenasFuturas = true,
  }) =>
      _delete('$baseUrl/parcelas/$parcelaId'
          '?familia_id=$familiaId&apenas_futuras=$apenasFuturas');

  // ── Fechamento mensal e visões ────────────────────────────────────────────

  /// Fecha o mês: grava o snapshot de cada envelope e zera os de consumo.
  /// Idempotente — rodar de novo no mesmo mês só atualiza o snapshot.
  static Future<Map<String, dynamic>> fecharMes(String familiaId, String mes) =>
      _post('$baseUrl/fechamento/fechar', {
        'familia_id': familiaId,
        'mes': mes,
      });

  /// Visão de um mês: retrato do fechamento (histórico) ou cálculo ao vivo.
  static Future<Map<String, dynamic>> getVisaoMes(String familiaId, String mes) =>
      _get('$baseUrl/fechamento/mes/$mes', params: {'familia_id': familiaId});

  /// Visão do ano: série mensal por categoria + resumo (padrões).
  static Future<Map<String, dynamic>> getVisaoAno(String familiaId, String ano) =>
      _get('$baseUrl/fechamento/ano/$ano', params: {'familia_id': familiaId});

  /// Retrospectiva do mês: resultado do ciclo (fechou devendo X, coberto por
  /// fora). A consciência do mês — nunca expõe a reserva de emergência.
  static Future<Map<String, dynamic>> getRetrospectiva(String familiaId, String mes) =>
      _get('$baseUrl/fechamento/retrospectiva/$mes', params: {'familia_id': familiaId});

  // ── Fechamento do dia (ritual das 23h30) ───────────────────────────────────

  /// Gastos do dia da família, pendências com envelope sugerido, R$/dia e streak.
  static Future<Map<String, dynamic>> getResumoDia() => _get('$baseUrl/dia/resumo');

  /// Confirma as pendências (sugestão ou ajuste) e fecha o dia da família.
  static Future<Map<String, dynamic>> fecharDia({
    Map<String, String> ajustes = const {},
    List<String> descartar = const [],
  }) =>
      _post('$baseUrl/dia/fechar', {
        'ajustes': [
          for (final e in ajustes.entries) {'compra_id': e.key, 'envelope_id': e.value},
        ],
        'descartar': descartar,
      });

  // ── Reconciliação de fatura (CSV do Nubank) ────────────────────────────────

  /// Sobe o CSV da fatura e recebe o laudo (os 4 baldes). NÃO grava nada — é o
  /// diagnóstico para o usuário confirmar. `bytes` é o conteúdo do arquivo.
  static Future<Map<String, dynamic>> analisarFatura({
    required String familiaId,
    required List<int> bytes,
    required String nomeArquivo,
  }) async {
    final uri = Uri.parse('$baseUrl/reconciliacao/analisar')
        .replace(queryParameters: {'familia_id': familiaId});
    final req = http.MultipartRequest('POST', uri);
    final token = supabase.auth.currentSession?.accessToken;
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.files.add(http.MultipartFile.fromBytes('arquivo', bytes, filename: nomeArquivo));

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw ApiException(_detailDe(res.body, res.statusCode), res.statusCode);
  }

  /// Aplica as decisões confirmadas pelo usuário (inserir esquecidos, ajustar
  /// divergências). O balde 3 (só no app) não gera ação — manter é o default.
  static Future<Map<String, dynamic>> aplicarReconciliacao({
    required String familiaId,
    required String usuarioId,
    required List<Map<String, dynamic>> inserir,
    required List<Map<String, dynamic>> ajustarValor,
  }) =>
      _post('$baseUrl/reconciliacao/aplicar', {
        'familia_id': familiaId,
        'usuario_id': usuarioId,
        'inserir': inserir,
        'ajustar_valor': ajustarValor,
      });
}
