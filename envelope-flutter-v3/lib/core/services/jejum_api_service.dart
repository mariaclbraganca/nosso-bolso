import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Chamadas REST do módulo Jejum Intermitente (/api/v1/saude/jejum/*).
class JejumApiService {
  static String get _base => '${ApiService.baseUrl}/api/v1/saude/jejum';

  static Future<Map<String, dynamic>> getConfig(
      String usuarioId, String familiaId) async {
    final uri = Uri.parse('$_base/config/$usuarioId')
        .replace(queryParameters: {'familia_id': familiaId});
    final resp = await http.get(uri, headers: ApiService.authHeaders());
    if (resp.statusCode != 200) {
      throw Exception('Falha ao carregar config: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> salvarConfig(
      String usuarioId, Map<String, dynamic> payload) async {
    final resp = await http.put(
      Uri.parse('$_base/config/$usuarioId'),
      headers: ApiService.authHeaders(json: true),
      body: jsonEncode(payload),
    );
    if (resp.statusCode != 200) {
      throw Exception('Falha ao salvar config: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> iniciar({
    required String usuarioId,
    required String familiaId,
    double? metaHoras,
    int? humorInicio,
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/iniciar'),
      headers: ApiService.authHeaders(json: true),
      body: jsonEncode({
        'usuario_id': usuarioId,
        'familia_id': familiaId,
        if (metaHoras != null) 'meta_horas': metaHoras,
        if (humorInicio != null) 'humor_inicio': humorInicio,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Falha ao iniciar jejum: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> finalizar(
    String registroId, {
    required String status, // completo | interrompido | joker
    int? humorFim,
    String? reflexao,
    String? sentimento,          // leve | dificuldade | cansada_firme | energia
    List<String>? oQueAjudou,    // ["hidratacao","cafe","parceiro"]
    String? motivoInterrupcao,   // fome | social | estresse | quis
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/finalizar/$registroId'),
      headers: ApiService.authHeaders(json: true),
      body: jsonEncode({
        'status': status,
        if (humorFim != null) 'humor_fim': humorFim,
        if (reflexao != null && reflexao.isNotEmpty) 'reflexao': reflexao,
        if (sentimento != null) 'sentimento': sentimento,
        if (oQueAjudou != null && oQueAjudou.isNotEmpty) 'o_que_ajudou': oQueAjudou,
        if (motivoInterrupcao != null) 'motivo_interrupcao': motivoInterrupcao,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Falha ao finalizar jejum: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Ajusta o horário de início de um jejum em andamento (corrige quem
  /// esqueceu de registrar na hora). Recalcula o tempo decorrido.
  static Future<Map<String, dynamic>> ajustarInicio(
      String registroId, DateTime novoInicio) async {
    final resp = await http.post(
      Uri.parse('$_base/ajustar-inicio/$registroId'),
      headers: ApiService.authHeaders(json: true),
      body: jsonEncode({'iniciado_em': novoInicio.toUtc().toIso8601String()}),
    );
    if (resp.statusCode != 200) {
      throw Exception('${jsonDecode(resp.body)['detail'] ?? resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Sugestão IA de protocolo: {protocolo, label, janela_inicio, janela_fim, aderencia_pct, justificativa}.
  static Future<Map<String, dynamic>> getSugestaoProtocolo(String usuarioId) async {
    final resp = await http.get(
      Uri.parse('$_base/sugestao-protocolo/$usuarioId'),
      headers: ApiService.authHeaders(),
    );
    if (resp.statusCode != 200) {
      throw Exception('Falha na sugestão de protocolo: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Sugestão IA de horário de janela para um protocolo.
  static Future<Map<String, dynamic>> getSugestaoJanela(
      String usuarioId, String protocolo) async {
    final uri = Uri.parse('$_base/sugestao-janela/$usuarioId')
        .replace(queryParameters: {'protocolo': protocolo});
    final resp = await http.get(uri, headers: ApiService.authHeaders());
    if (resp.statusCode != 200) {
      throw Exception('Falha na sugestão de janela: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Visão dupla do Fast Together: {eu, parceiro, mes:{sincronizados,...}}.
  static Future<Map<String, dynamic>?> getTogetherDupla(
      String usuarioId, String familiaId) async {
    final uri = Uri.parse('$_base/together/dupla/$usuarioId')
        .replace(queryParameters: {'familia_id': familiaId});
    final resp = await http.get(uri, headers: ApiService.authHeaders());
    if (resp.statusCode != 200) return null;
    final body = jsonDecode(resp.body);
    return body is Map<String, dynamic> ? body : null;
  }

  /// Registra o token FCM do usuário para pushes de jejum.
  static Future<void> registrarFcmToken(String usuarioId, String token) async {
    await http.post(
      Uri.parse('$_base/fcm-token'),
      headers: ApiService.authHeaders(json: true),
      body: jsonEncode({'usuario_id': usuarioId, 'fcm_token': token}),
    );
  }

  static Future<Map<String, dynamic>?> getAtivo(String usuarioId) async {
    final resp = await http.get(
      Uri.parse('$_base/ativo/$usuarioId'),
      headers: ApiService.authHeaders(),
    );
    if (resp.statusCode != 200) return null;
    final body = jsonDecode(resp.body);
    return body is Map<String, dynamic> ? body : null;
  }

  static Future<Map<String, dynamic>> getHistorico(String usuarioId,
      {int page = 1, int limit = 30}) async {
    final uri = Uri.parse('$_base/historico/$usuarioId')
        .replace(queryParameters: {'page': '$page', 'limit': '$limit'});
    final resp = await http.get(uri, headers: ApiService.authHeaders());
    if (resp.statusCode != 200) {
      throw Exception('Falha ao carregar histórico: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getInsights(String usuarioId) async {
    final resp = await http.get(
      Uri.parse('$_base/insights/$usuarioId'),
      headers: ApiService.authHeaders(),
    );
    if (resp.statusCode != 200) {
      throw Exception('Falha ao carregar insights: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>?> getTogether(
      String usuarioId, String familiaId) async {
    final uri = Uri.parse('$_base/together/$usuarioId')
        .replace(queryParameters: {'familia_id': familiaId});
    final resp = await http.get(uri, headers: ApiService.authHeaders());
    if (resp.statusCode != 200) return null;
    final body = jsonDecode(resp.body);
    return body is Map<String, dynamic> ? body : null;
  }

  static Future<Map<String, dynamic>> togetherConvite({
    required String familiaId,
    required String usuarioA,
    required String usuarioB,
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/together/convite'),
      headers: ApiService.authHeaders(json: true),
      body: jsonEncode({
        'familia_id': familiaId,
        'usuario_a': usuarioA,
        'usuario_b': usuarioB,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Falha ao criar vínculo: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static Future<void> togetherMotivar({
    required String togetherId,
    required String remetenteId,
    String? mensagem,
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/together/motivar'),
      headers: ApiService.authHeaders(json: true),
      body: jsonEncode({
        'together_id': togetherId,
        'remetente_id': remetenteId,
        if (mensagem != null && mensagem.isNotEmpty) 'mensagem': mensagem,
      }),
    );
    if (resp.statusCode == 429) {
      throw Exception('Limite de 2 incentivos por dia atingido');
    }
    if (resp.statusCode != 200) {
      throw Exception('Falha ao enviar incentivo: ${resp.body}');
    }
  }
}
