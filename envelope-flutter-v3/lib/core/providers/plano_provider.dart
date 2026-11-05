import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../plano/plano_mes.dart';
import '../services/api_service.dart';
import 'compras_provider.dart';
import 'contas_provider.dart';
import 'envelopes_provider.dart';
import 'fixos_provider.dart';
import 'mes_provider.dart';
import 'orcamento_mes_provider.dart';
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

/// Envelope que guarda dinheiro (reserva ou objetivo): acumula, não é gasto do mês.
bool ehReserva(Map<String, dynamic> env) =>
    env['is_reserva'] == true || env['natureza'] == 'reserva' || env['natureza'] == 'objetivo';

/// Envelope do vale-alimentação (conta própria, fora do limite do salário).
bool ehEnvelopeVa(Map<String, dynamic> env) =>
    (env['nome_envelope'] as String? ?? '').toLowerCase().replaceAll('ã', 'a').contains('vale alimenta');

/// A captura é do mês [mes]? (sem data, vale no mês atual, como antes.)
bool _doMes(Map<String, dynamic> p, String mes) {
  final d = (p['data_compra'] ?? p['data'])?.toString() ?? '';
  return d.length < 7 || d.substring(0, 7) == mes;
}

/// Forma de pagamento de uma despesa. Lançamentos antigos sem forma vieram da
/// captura do cartão; no envelope de VA, a forma é sempre VA.
String formaDaDespesa(Map<String, dynamic> t, Set<String> idsVa) =>
    idsVa.contains(t['envelope_id']) ? 'va' : (t['forma_pagamento'] as String?) ?? 'credito';

/// Compras do mês para o limite: despesas confirmadas + capturas do Nubank
/// ainda sem envelope (já descontam do disponível). A captura vale no mês da
/// data da COMPRA: uma pendência de outubro não entra no mês nem na fatura de
/// novembro, mesmo que ainda esteja sem envelope.
List<CompraMes> comprasDoMes(
  List<Map<String, dynamic>> transacoes,
  List<Map<String, dynamic>> pendentes,
  Set<String> idsVa, {
  String? mes,
}) =>
    [
      for (final t in transacoes)
        if (t['tipo'] == 'despesa')
          (valor: (t['valor'] as num).toDouble(), envelopeId: t['envelope_id'] as String?, forma: formaDaDespesa(t, idsVa)),
      for (final p in pendentes)
        if (mes == null || _doMes(p, mes))
          (
          valor: ((p['valor_total'] ?? p['valor']) as num? ?? 0).toDouble(),
          envelopeId: null,
          forma: p['tipo_notificacao'] == 'pix_enviado' ? 'pix' : 'credito',
        ),
    ];

/// O limite de compras do mês selecionado (mesma conta do protótipo aprovado).
final limiteMesProvider = Provider.autoDispose<AsyncValue<LimiteMes>>((ref) {
  final mes = ref.watch(mesAtualProvider);
  final receitas = ref.watch(entradasMesProvider(mes));
  final receitasAnteriores = ref.watch(entradasMesProvider(somarMeses(mes, -1))).valueOrNull ?? const [];
  final compromissos = ref.watch(compromissosCartaoProvider);
  if (receitas.hasError) return AsyncValue.error(receitas.error!, receitas.stackTrace!);
  if (compromissos.hasError) return AsyncValue.error(compromissos.error!, compromissos.stackTrace!);
  if (!receitas.hasValue || !compromissos.hasValue) return const AsyncValue.loading();

  final orcado = ref.watch(orcamentoMesProvider(mes)).valueOrNull ?? const <String, double>{};
  final todosEnvelopes = aplicarOrcadoDoMes(ref.watch(envelopesProvider).valueOrNull ?? const <Map<String, dynamic>>[], orcado)
      .where((e) => e['deleted_at'] == null)
      .toList();
  final idsVa = {for (final e in todosEnvelopes) if (ehEnvelopeVa(e)) e['id'] as String};
  final boletos = ref.watch(contasMesProvider(mes)).valueOrNull ?? const <Map<String, dynamic>>[];

  // Sobra do VA do mês anterior (acumula um mês para o outro).
  final mesAnterior = somarMeses(mes, -1);
  final todas = ref.watch(transacoesStreamProvider).valueOrNull ?? const <Map<String, dynamic>>[];
  final gastoVaAnterior = todas
      .where((t) => t['deleted_at'] == null && t['tipo'] == 'despesa' && idsVa.contains(t['envelope_id']))
      .where((t) => (t['data']?.toString() ?? '').startsWith(mesAnterior))
      .fold(0.0, (s, t) => s + (t['valor'] as num).toDouble());
  final vaMensal = receitas.value!.where((r) => r['tipo'] == 'vale').fold(0.0, (s, r) => s + ((r['valor'] as num?) ?? 0));
  final sobraVa = gastoVaAnterior > 0 && vaMensal > gastoVaAnterior ? vaMensal - gastoVaAnterior : 0.0;

  return AsyncValue.data(LimiteMes(
    mes: mes,
    receitas: receitas.value!,
    contasDoMes: [...ref.watch(fixosMesAtualProvider), ...boletos],
    compromissos: compromissos.value!,
    envelopes: todosEnvelopes.where((e) => !ehReserva(e) && !idsVa.contains(e['id'])).toList(),
    compras: comprasDoMes(
      ref.watch(transacoesComDetalhesProvider),
      ref.watch(comprasPendentesProvider).valueOrNull ?? const [],
      idsVa,
      mes: mes,
    ),
    vaSobraAnterior: sobraVa,
    dinheiroAnterior: salarioAnterior(receitasAnteriores),
  ));
});

/// Salário do mês anterior que paga as contas deste mês: o recebido (ou a
/// parte reservada para as contas) ou, se ainda não marcado, o previsto.
double salarioAnterior(List<Map<String, dynamic>> receitasAnteriores) => receitasAnteriores
    .where((r) => (r['tipo'] ?? 'dinheiro') == 'dinheiro')
    .fold(0.0, (s, r) => s + ((r['recebido'] == true ? r['valor_recebido'] : null) ?? r['valor'] as num? ?? 0).toDouble());

/// Paga parte de uma conta (gasto fixo); o backend registra no Extrato.
Future<void> pagarParteDaConta(String fixoId, double valor) =>
    ApiService.post('/fixos/$fixoId/pagamento', {'valor': valor});
