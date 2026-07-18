import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/financeiro_ext_service.dart';
import 'usuarios_provider.dart';

// Insights financeiros (relatórios) — provider original
final insightsProvider = FutureProvider.family<List<dynamic>, String>((ref, mes) async {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  if (perfil == null || perfil['familia_id'] == null) return [];
  try {
    final res = await ApiService.get('/insights/insights', perfil['familia_id'], params: {'mes_atual': mes});
    return res as List<dynamic>;
  } catch (_) {
    return [];
  }
});

// Astrix Insights — relatório semanal com IA (finanças + nutrição + exercício)
final astrixInsightsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final perfil    = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  final membroId  = perfil?['id'] as String? ?? '';
  final familiaId = perfil?['familia_id'] as String? ?? '';
  if (membroId.isEmpty || familiaId.isEmpty) return {};
  return FinanceiroExtService.getInsights(membroId, familiaId);
});
