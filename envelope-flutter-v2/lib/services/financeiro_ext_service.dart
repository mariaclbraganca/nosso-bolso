import 'dart:convert';
import 'package:flutter/foundation.dart' show kReleaseMode, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import '../constants.dart';

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
    throw Exception('POST $url failed ${res.statusCode}: ${res.body}');
  }

  static Future<Map<String, dynamic>> _patch(String url, Map<String, dynamic> body) async {
    final res = await http.patch(Uri.parse(url), headers: _headers(json: true), body: jsonEncode(body))
        .timeout(_kTimeout);
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('PATCH $url failed ${res.statusCode}: ${res.body}');
  }

  static Future<void> _delete(String url) async {
    final res = await http.delete(Uri.parse(url), headers: _headers()).timeout(_kTimeout);
    if (res.statusCode != 200) throw Exception('DELETE $url failed ${res.statusCode}: ${res.body}');
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
}
