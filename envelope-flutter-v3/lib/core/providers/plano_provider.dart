import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../plano/plano_mes.dart';
import '../services/api_service.dart';
import 'contas_provider.dart';
import 'envelopes_provider.dart';
import 'fixos_provider.dart';
import 'mes_provider.dart';
import 'transacoes_provider.dart';
import 'usuarios_provider.dart';

String _familia(Ref ref) =>
    ref.watch(perfilUsuarioLogadoProvider).valueOrNull?['familia_id'] as String? ?? '';

/// Entradas previstas do mês (o backend replica as recorrentes do mês anterior).
final entradasMesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, mes) async {
  final fam = _familia(ref);
  if (fam.isEmpty) return [];
  final lista = await ApiService.get('/plano/entradas', fam, params: {'mes': mes});
  return lista.cast<Map<String, dynamic>>();
});

/// Parcelas e assinaturas do cartão que caem nas próximas faturas.
final compromissosCartaoProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final fam = _familia(ref);
  if (fam.isEmpty) return [];
  final lista = await ApiService.get('/plano/cartao', fam);
  return lista.cast<Map<String, dynamic>>();
});

/// Resgate da reserva = receita lançada com "reserva" na descrição.
bool ehResgateReserva(Map<String, dynamic> t) =>
    t['tipo'] == 'receita' && (t['descricao'] as String? ?? '').toLowerCase().contains('reserva');

/// Plano do mês selecionado, juntando entradas, fixos, boletos, envelopes,
/// gastos e o cartão.
final planoMesProvider = Provider.autoDispose<AsyncValue<PlanoMes>>((ref) {
  final mes = ref.watch(mesAtualProvider);
  final entradas = ref.watch(entradasMesProvider(mes));
  final compromissos = ref.watch(compromissosCartaoProvider);
  final boletos = ref.watch(contasMesProvider(mes));
  if (entradas.hasError) return AsyncValue.error(entradas.error!, entradas.stackTrace!);
  if (compromissos.hasError) return AsyncValue.error(compromissos.error!, compromissos.stackTrace!);
  if (!entradas.hasValue || !compromissos.hasValue) return const AsyncValue.loading();

  final transacoes = ref.watch(transacoesComDetalhesProvider);
  final envelopes = (ref.watch(envelopesProvider).valueOrNull ?? const [])
      .where((e) => e['deleted_at'] == null && e['is_reserva'] != true)
      .toList();

  return AsyncValue.data(PlanoMes(
    mes: mes,
    entradas: entradas.value!,
    contas: [
      for (final f in ref.watch(fixosMesAtualProvider)) {...f, 'origem': 'fixo'},
      for (final b in boletos.valueOrNull ?? const <Map<String, dynamic>>[]) {...b, 'origem': 'boleto'},
    ],
    envelopes: envelopes,
    gastoPorEnvelope: ref.watch(gastosPorEnvelopeNoMesProvider),
    compromissos: compromissos.value!,
    gastoNoCartao: transacoes
        .where((t) => t['tipo'] == 'despesa' && t['forma_pagamento'] == 'credito')
        .fold(0.0, (s, t) => s + ((t['valor'] as num?)?.toDouble() ?? 0)),
    resgatesReserva: transacoes.where(ehResgateReserva).fold(0.0, (s, t) => s + ((t['valor'] as num?)?.toDouble() ?? 0)),
  ));
});
