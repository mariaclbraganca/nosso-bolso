import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// GET genérico com familia_id
  static Future<List<dynamic>> get(String endpoint, String familiaId, {Map<String, String>? params}) async {
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: {
      'familia_id': familiaId,
      ...?params,
    });
    
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Falha ao carregar dados: ${response.statusCode}');
  }

  /// POST genérico
  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Content-Type': 'application/json'},
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
      headers: {'Content-Type': 'application/json'},
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
      headers: {'Content-Type': 'application/json'},
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
    
    final response = await http.delete(uri);
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw error['detail'] ?? 'Erro ao deletar';
    }
  }
}
