import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/financeiro_ext_service.dart';
import 'usuarios_provider.dart';

/// Resumo do dia da família (ritual das 23h30): gastos, pendências com envelope
/// sugerido, quanto dá pra gastar por dia até o fim do mês e streak.
final resumoDiaProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  if (perfil?['familia_id'] == null) return {};
  return FinanceiroExtService.getResumoDia();
});
