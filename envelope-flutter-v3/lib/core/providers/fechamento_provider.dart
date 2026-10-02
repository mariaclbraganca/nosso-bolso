import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/financeiro_ext_service.dart';
import 'usuarios_provider.dart';

/// Visão de um mês específico (retrato do fechamento ou cálculo ao vivo).
/// Recebe o mês no formato 'YYYY-MM'.
final visaoMesProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, mes) async {
  final perfil    = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  final familiaId = perfil?['familia_id'] as String? ?? '';
  if (familiaId.isEmpty) return {};
  return FinanceiroExtService.getVisaoMes(familiaId, mes);
});

/// Visão do ano (série mensal por categoria + resumo de padrões).
/// Recebe o ano no formato 'YYYY'.
final visaoAnoProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, ano) async {
  final perfil    = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  final familiaId = perfil?['familia_id'] as String? ?? '';
  if (familiaId.isEmpty) return {};
  return FinanceiroExtService.getVisaoAno(familiaId, ano);
});

/// Retrospectiva de um mês fechado (resultado do ciclo).
/// Recebe o mês no formato 'YYYY-MM'.
final retrospectivaProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, mes) async {
  final perfil    = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  final familiaId = perfil?['familia_id'] as String? ?? '';
  if (familiaId.isEmpty) return {};
  return FinanceiroExtService.getRetrospectiva(familiaId, mes);
});
