import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';

/// Fila local (SharedPreferences) de notificações financeiras capturadas que
/// não puderam ser enviadas ao backend (sem internet, sessão nula, backend
/// hibernando). Evita perder a compra: reenvia quando a conexão volta.
///
/// Cada item guarda o endpoint relativo e o corpo JSON. `flush()` tenta enviar
/// tudo e remove os que forem aceitos.
class NotificacaoFilaService {
  static const _key = 'fila_notificacoes_pendentes';
  static const _maxItens = 100; // teto de segurança

  /// Enfileira uma notificação para envio posterior.
  static Future<void> enfileirar(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fila = prefs.getStringList(_key) ?? [];
      fila.add(jsonEncode({'endpoint': endpoint, 'body': body}));
      if (fila.length > _maxItens) {
        fila.removeRange(0, fila.length - _maxItens); // descarta os mais antigos
      }
      await prefs.setStringList(_key, fila);
      debugPrint('[Fila] Enfileirado ($endpoint). Total: ${fila.length}');
    } catch (e) {
      debugPrint('[Fila] Erro ao enfileirar: $e');
    }
  }

  /// Tenta enviar tudo que está na fila. Mantém na fila só o que falhar.
  /// Seguro para chamar no init do app e após cada envio bem-sucedido.
  static Future<void> flush() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return; // sem sessão não adianta tentar

      final prefs = await SharedPreferences.getInstance();
      final fila = prefs.getStringList(_key) ?? [];
      if (fila.isEmpty) return;

      // Completa familia_id/usuario_id com a sessão atual — itens enfileirados
      // em background (isolate sem sessão) foram salvos sem esses campos.
      String familiaId =
          session.user.userMetadata?['familia_id'] as String? ?? '';
      if (familiaId.isEmpty) {
        try {
          final row = await Supabase.instance.client
              .from('usuarios')
              .select('familia_id')
              .eq('id', session.user.id)
              .maybeSingle();
          familiaId = row?['familia_id'] as String? ?? '';
        } catch (_) {}
      }

      final restantes = <String>[];
      for (final raw in fila) {
        var enviado = false;
        try {
          final item = jsonDecode(raw) as Map<String, dynamic>;
          final body = Map<String, dynamic>.from(item['body'] as Map);
          // Preenche campos que faltavam na captura em background.
          final f = body['familia_id'] as String?;
          if (f == null || f.isEmpty) body['familia_id'] = familiaId;
          body.putIfAbsent('usuario_id', () => session.user.id);
          final resp = await http
              .post(
                Uri.parse('${ApiService.baseUrl}${item['endpoint']}'),
                headers: ApiService.authHeaders(json: true),
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 20));
          // 2xx = aceito; 4xx (menos 401/408/429) = erro permanente, descarta
          final code = resp.statusCode;
          enviado = code >= 200 &&
              (code < 300 ||
                  (code >= 400 &&
                      code < 500 &&
                      code != 401 &&
                      code != 408 &&
                      code != 429));
        } catch (e) {
          enviado = false; // rede/timeout → mantém na fila
        }
        if (!enviado) restantes.add(raw);
      }

      await prefs.setStringList(_key, restantes);
      debugPrint('[Fila] Flush: ${fila.length - restantes.length} enviado(s), '
          '${restantes.length} pendente(s)');
    } catch (e) {
      debugPrint('[Fila] Erro no flush: $e');
    }
  }
}
