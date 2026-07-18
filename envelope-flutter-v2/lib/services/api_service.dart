import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import '../constants.dart';

class ApiService {
  static const String _envUrl = String.fromEnvironment('API_URL');
  static const String _prodUrl = 'https://nosso-bolso-api.onrender.com';

  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    // Release build (qualquer plataforma) sempre usa produção
    if (kReleaseMode) return _prodUrl;
    // Debug em mobile não enxerga localhost — também aponta pra produção
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
         defaultTargetPlatform == TargetPlatform.iOS)) {
      return _prodUrl;
    }
    return 'http://localhost:8000';
  }

  /// Headers padrão com JWT do Supabase Auth.
  ///
  /// O backend exige Authorization: Bearer <jwt> em todas as rotas. Lemos do
  /// `supabase.auth.currentSession?.accessToken` (mantido pelo supabase_flutter
  /// e renovado automaticamente). Se não houver sessão, o request vai sem
  /// token — backend devolverá 401 e o app deve redirecionar pro login.
  static Map<String, String> _headers({bool json = false}) {
    final token = supabase.auth.currentSession?.accessToken;
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// GET genérico com familia_id
  static Future<List<dynamic>> get(String endpoint, String familiaId, {Map<String, String>? params}) async {
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: {
      'familia_id': familiaId,
      ...?params,
    });

    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Falha ao carregar dados: ${response.statusCode}');
  }

  /// POST genérico
  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(json: true),
      body: jsonEncode(data),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception('Falha ao criar: ${response.body}');
  }

  /// PUT genérico
  static Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(json: true),
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Falha ao atualizar: ${response.body}');
  }

  /// PATCH genérico
  static Future<Map<String, dynamic>> patch(String endpoint, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(json: true),
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Falha ao atualizar (patch): ${response.body}');
  }

  /// DELETE genérico com familia_id opcional
  static Future<void> delete(String endpoint, {String? familiaId}) async {
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: {
      if (familiaId != null) 'familia_id': familiaId,
    });

    final response = await http.delete(uri, headers: _headers());
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw error['detail'] ?? 'Erro ao deletar';
    }
  }

  /// Headers públicos para uso em chamadas diretas com http.get/post/etc.
  /// (telas que não passam por ApiService.get/post — ex: compras_pendentes_screen)
  static Map<String, String> authHeaders({bool json = false}) =>
      _headers(json: json);
}
