import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'usuarios_provider.dart';

final insightsProvider = FutureProvider.family<List<dynamic>, String>((ref, mes) async {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  if (perfil == null || perfil['familia_id'] == null) return [];

  final res = await ApiService.get('/dashboard/insights', perfil['familia_id'], params: {'mes_atual': mes});
  return res as List<dynamic>;
});
