import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/financeiro_ext_service.dart';
import 'usuarios_provider.dart';

/// Lista de parcelas ativas da família (compras parceladas em andamento).
/// Cada item traz `parcelas_pagas` e `parcelas_restantes` vindos do backend.
final parcelasProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final perfil    = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  final familiaId = perfil?['familia_id'] as String? ?? '';
  if (familiaId.isEmpty) return [];
  return FinanceiroExtService.getParcelas(familiaId, apenasAtivas: true);
});

/// Total dos compromissos parcelados restantes (soma das parcelas ainda a vencer).
/// Útil para um card "compromissos futuros" no dashboard.
final totalCompromissosProvider = Provider.autoDispose<double>((ref) {
  final parcelas = ref.watch(parcelasProvider).asData?.value ?? [];
  double total = 0;
  for (final p in parcelas) {
    final restantes = (p['parcelas_restantes'] as num?)?.toInt() ?? 0;
    final valorParcela = (p['valor_parcela'] as num?)?.toDouble() ?? 0;
    total += restantes * valorParcela;
  }
  return total;
});

/// Sugestões de cartão para o form de parcela (baseado no contexto do app).
const List<String> cartoesSugestao = ['Frederico', 'Alanna', 'Aruã', 'Outro'];
