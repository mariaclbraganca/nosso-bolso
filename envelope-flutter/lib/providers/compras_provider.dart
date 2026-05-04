import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'usuarios_provider.dart';

final comprasPendentesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  if (perfil == null) return [];
  final familiaId = perfil['familia_id'] as String? ?? '';
  final uri = Uri.parse('${ApiService.baseUrl}/api/v1/compras/pendentes')
      .replace(queryParameters: {'familia_id': familiaId});
  final resp = await http.get(uri);
  if (resp.statusCode == 200) {
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }
  return [];
});

final feedbackPendenteProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  if (perfil == null) return [];
  final familiaId = perfil['familia_id'] as String? ?? '';
  final uri = Uri.parse('${ApiService.baseUrl}/api/v1/compras/feedback-pendente')
      .replace(queryParameters: {'familia_id': familiaId});
  final resp = await http.get(uri);
  if (resp.statusCode == 200) {
    return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
  }
  return [];
});

final listaComprasProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, dias) async {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  if (perfil == null) return {};
  final familiaId = perfil['familia_id'] as String? ?? '';
  final uri = Uri.parse('${ApiService.baseUrl}/api/v1/compras/planejar')
      .replace(queryParameters: {'familia_id': familiaId, 'dias': '$dias'});
  final resp = await http.get(uri);
  if (resp.statusCode == 200) {
    return Map<String, dynamic>.from(jsonDecode(resp.body));
  }
  return {};
});

final comprasFalhasProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  if (perfil == null) return [];
  final familiaId = perfil['familia_id'] as String? ?? '';
  try {
    final uri = Uri.parse('${ApiService.baseUrl}/api/v1/compras/falhas')
        .replace(queryParameters: {'familia_id': familiaId});
    final resp = await http.get(uri).timeout(const Duration(seconds: 8));
    if (resp.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
    }
  } catch (_) {}
  return [];
});
