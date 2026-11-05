import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'usuarios_provider.dart';

/// Orçado gravado para o mês (envelope_id → valor). Envelope sem valor aqui usa
/// o valor planejado do próprio envelope. Se o servidor ainda não tem o orçado
/// por mês, volta vazio e tudo segue como antes.
final orcamentoMesProvider = FutureProvider.autoDispose.family<Map<String, double>, String>((ref, mes) async {
  final fam = ref.watch(perfilUsuarioLogadoProvider).valueOrNull?['familia_id'] as String? ?? '';
  if (fam.isEmpty) return {};
  try {
    final itens = await ApiService.get('/orcamento/$mes', fam);
    return {
      for (final i in itens.cast<Map<String, dynamic>>())
        if (i['fonte'] == 'mes') i['envelope_id'] as String: (i['valor_planejado'] as num).toDouble(),
    };
  } catch (_) {
    return {};
  }
});

/// Envelopes com o valor planejado do mês aplicado.
List<Map<String, dynamic>> aplicarOrcadoDoMes(List<Map<String, dynamic>> envelopes, Map<String, double> orcado) => [
      for (final e in envelopes)
        if (orcado.containsKey(e['id'])) {...e, 'valor_planejado': orcado[e['id']]} else e,
    ];
