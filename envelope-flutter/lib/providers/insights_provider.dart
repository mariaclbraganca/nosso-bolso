import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/financeiro_ext_service.dart';
import 'usuarios_provider.dart';

final insightsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final perfil    = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  final membroId  = perfil?['id'] as String? ?? '';
  final familiaId = perfil?['familia_id'] as String? ?? '';
  if (membroId.isEmpty || familiaId.isEmpty) return {};
  return FinanceiroExtService.getInsights(membroId, familiaId);
});
