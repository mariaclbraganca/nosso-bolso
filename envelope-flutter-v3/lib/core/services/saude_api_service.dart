import 'dart:convert';
import 'package:flutter/foundation.dart' show kReleaseMode, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import '../constants.dart';

class SaudeApiService {
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

  static const String _prefix = '/api/v1/saude';

  static Map<String, String> _headers({bool json = false}) {
    final token = supabase.auth.currentSession?.accessToken;
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static const _kDefaultTimeout = Duration(seconds: 30);
  static const _kAiTimeout = Duration(seconds: 90); // Gemini + cold start do Render

  static Future<Map<String, dynamic>> _getMap(
    String path, {
    Map<String, String>? params,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$baseUrl$_prefix$path')
        .replace(queryParameters: params ?? {});
    final res = await http.get(uri, headers: _headers())
        .timeout(timeout ?? _kDefaultTimeout);
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('GET $path failed ${res.statusCode}: ${res.body}');
  }

  static Future<List<Map<String, dynamic>>> _getList(
    String path, {
    Map<String, String>? params,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$baseUrl$_prefix$path')
        .replace(queryParameters: params ?? {});
    final res = await http.get(uri, headers: _headers())
        .timeout(timeout ?? _kDefaultTimeout);
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }
    throw Exception('GET $path failed ${res.statusCode}: ${res.body}');
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl$_prefix$path'),
      headers: _headers(json: true),
      body: jsonEncode(body),
    ).timeout(timeout ?? _kDefaultTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('POST $path failed ${res.statusCode}: ${res.body}');
  }

  static Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http.patch(
      Uri.parse('$baseUrl$_prefix$path'),
      headers: _headers(json: true),
      body: jsonEncode(body),
    ).timeout(_kDefaultTimeout);
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('PATCH $path failed ${res.statusCode}: ${res.body}');
  }

  // ── Perfil Metabólico ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getPerfilMetabolico(String membroId) async {
    try {
      return await _getMap('/perfil-metabolico/$membroId');
    } catch (e) {
      if (e.toString().contains('404')) return null;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> criarPerfilMetabolico(
    Map<String, dynamic> payload,
  ) => _post('/perfil-metabolico', payload);

  static Future<Map<String, dynamic>> atualizarPerfilMetabolico(
    String membroId,
    Map<String, dynamic> payload,
  ) => _patch('/perfil-metabolico/$membroId', payload);

  // ── Anamnese ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> turnoAnamnese(
    List<Map<String, String>> historico,
  ) => _post('/anamnese/chat', {'historico_mensagens': historico}, timeout: _kAiTimeout);

  // ── Extrato / Refeições ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getExtratoDiario(
    String membroId,
    String data,
  ) => _getMap('/extrato', params: {'membro_id': membroId, 'data': data});

  static Future<List<Map<String, dynamic>>> getRefeicoesDia(
    String membroId,
    String data,
  ) => _getList('/refeicao', params: {'membro_id': membroId, 'data': data});

  static Future<List<Map<String, dynamic>>> getRefeicoeRecentes(
    String membroId, {
    int limite = 10,
  }) =>
      _getList('/refeicao/recentes',
          params: {'membro_id': membroId, 'limite': '$limite'},
          timeout: _kDefaultTimeout);

  static Future<Map<String, dynamic>> registrarRefeicao(
    Map<String, dynamic> payload,
  ) => _post('/refeicao/registrar', payload);

  static Future<void> deletarRefeicao(String refeicaoId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl$_prefix/refeicao/$refeicaoId'),
      headers: _headers(),
    );
    if (res.statusCode != 200) throw Exception('DELETE refeição: ${res.body}');
  }

  // ── Hidratação ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getHidratacao(
    String membroId,
    String data,
  ) => _getMap('/hidratacao', params: {'membro_id': membroId, 'data': data});

  static Future<Map<String, dynamic>> registrarHidratacao(
    String membroId,
    String familiaId, {
    int volumeMl = 250,
    String? data,
  }) =>
      _post('/hidratacao', {
        'membro_id': membroId,
        'familia_id': familiaId,
        'volume_ml': volumeMl,
        if (data != null) 'data': data,
      });

  // ── Sugestão de Jantar ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getSugestaoJantar(
    String familiaId,
    List<String> membroIds, {
    List<String> itensAusentes = const [],
  }) =>
      _getMap('/sugerir-jantar', params: {
        'familia_id': familiaId,
        'membro_ids': membroIds.join(','),
        if (itensAusentes.isNotEmpty) 'itens_ausentes': itensAusentes.join(','),
      });

  // ── Peso ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getHistoricoPeso(
    String membroId,
  ) => _getMap('/peso/$membroId');

  static Future<Map<String, dynamic>> registrarPeso(
    Map<String, dynamic> payload,
  ) => _post('/peso', payload);

  // ── Histórico (gráficos) ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getHistorico(
    String membroId, {
    String periodo = 'mensal',
  }) => _getMap('/historico', params: {'membro_id': membroId, 'periodo': periodo});

  // ── Morning Digest ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMorningDigest(
    String membroId,
    String familiaId,
  ) => _getMap('/digest', params: {'membro_id': membroId, 'familia_id': familiaId});

  // ── Produto por Barcode ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getProdutoBarcode(
    String barcode,
    String familiaId,
  ) async {
    try {
      return await _getMap('/produto/$barcode', params: {'familia_id': familiaId});
    } catch (e) {
      if (e.toString().contains('404')) return null;
      rethrow;
    }
  }

  // ── Progresso Físico ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> registrarProgressoFisico(
    Map<String, dynamic> payload,
  ) => _post('/progresso-fisico', payload);

  static Future<List<Map<String, dynamic>>> getProgressoFisico(
    String membroId,
  ) => _getList('/progresso-fisico/$membroId');

  // ── Analisar Cardápio ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> analisarCardapio(
    Map<String, dynamic> payload,
  ) => _post('/analisar-cardapio', payload);

  // ── Monitoramento ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMonitoramento(
    String membroId,
  ) async {
    try {
      return await _getMap('/monitoramento/$membroId');
    } catch (e) {
      if (e.toString().contains('404')) return {};
      rethrow;
    }
  }

  // ── Preparo em Lote ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> registrarPreparoLote(
    Map<String, dynamic> payload,
  ) => _post('/preparo-lote', payload);

  // ── Exercício ─────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getCatalogoExercicios() async {
    final res = await _getMap('/exercicio/catalogo');
    return (res['catalogo'] as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> getExercicioDia(
    String membroId,
    String data,
  ) =>
      _getMap('/exercicio/dia', params: {'membro_id': membroId, 'data': data});

  static Future<Map<String, dynamic>> registrarExercicio(
    Map<String, dynamic> payload,
  ) =>
      _post('/exercicio/registrar', payload);

  static Future<void> deletarExercicio(
    String exercicioItemId,
    String membroId,
    String data,
  ) async {
    final uri = Uri.parse('$baseUrl$_prefix/exercicio/$exercicioItemId')
        .replace(queryParameters: {'membro_id': membroId, 'data': data});
    final res = await http.delete(uri, headers: _headers())
        .timeout(_kDefaultTimeout);
    if (res.statusCode != 200) throw Exception('DELETE exercício: ${res.body}');
  }

  static Future<List<Map<String, dynamic>>> getHistoricoExercicio(
    String membroId, {
    int dias = 30,
  }) async {
    final res = await _getMap('/exercicio/historico',
        params: {'membro_id': membroId, 'dias': '$dias'});
    return (res['historico'] as List).cast<Map<String, dynamic>>();
  }
}
