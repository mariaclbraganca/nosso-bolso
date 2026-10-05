import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/plano/plano_mes.dart';
import '../../core/providers/mes_provider.dart';
import '../../core/providers/plano_provider.dart';
import '../../core/services/api_service.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';
import '../home/widgets/home_cartao_saldo.dart' show nomeMes, ultimoDiaUtil;
import '../sheets/comum.dart';
import 'widgets/limite_resumo_card.dart';
import 'widgets/plano_sheets.dart';

/// Resumo do mês: resultado do ciclo do salário, receitas, de onde vem e para
/// onde vai o dinheiro, orçamento por envelope e os próximos meses.
class PlanoMesTab extends ConsumerWidget {
  const PlanoMesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesAtualProvider);
    void recarregar() {
      ref.invalidate(entradasMesProvider(mes));
      ref.invalidate(compromissosCartaoProvider);
    }

    return ref.watch(limiteMesProvider).when(
          loading: () => const UnicornCarregando(texto: 'Montando o resumo do mês…'),
          error: (e, _) => UnicornErro(mensagem: 'Não consegui carregar o resumo do mês.', onTentar: recarregar),
          data: (l) => RefreshIndicator(
            onRefresh: () async => recarregar(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 4, NBSpacing.margemTela, 120),
              children: [
                ResultadoCiclo(limite: l),
                const SizedBox(height: NBSpacing.l),
                _Receitas(limite: l),
                const SizedBox(height: NBSpacing.l),
                _OrcamentoPorEnvelope(limite: l),
                if (l.mes == '2026-10') ...[
                  const SizedBox(height: NBSpacing.l),
                  _Transicao(limite: l),
                ],
              ],
            ),
          ),
        );
  }
}

Color _cor(double v) => v < 0 ? NBColors.estouro : NBColors.verde;

/// Projeção final do ciclo: quanto falta (sai da reserva) ou sobra, se o
/// orçado for todo usado (ou mais, onde já passou).
class ResultadoCiclo extends StatelessWidget {
  const ResultadoCiclo({super.key, required this.limite});
  final LimiteMes limite;

  @override
  Widget build(BuildContext context) {
    final l = limite;
    final proj = l.resultadoProjetado;
    return CartaoNB(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('RESULTADO DO CICLO · SALÁRIO DE ${ultimoDiaUtil(l.mes)}', style: NBText.eyebrow),
        const SizedBox(height: 4),
        LinhaValorNB(proj < 0 ? 'FALTA DINHEIRO (projeção final)' : 'SOBRA (projeção final)', proj.abs(),
            forte: true, cor: _cor(proj)),
        const Divider(height: 8),
        Text(
          proj < 0
              ? 'Este valor sairá da sua reserva se você utilizar todo o saldo planejado nos envelopes.'
              : 'Mesmo usando todo o saldo planejado nos envelopes, o salário cobre o mês.',
          style: NBText.legenda,
        ),
      ]),
    );
  }
}

class _Receitas extends ConsumerWidget {
  const _Receitas({required this.limite});
  final LimiteMes limite;

  Future<void> _marcar(WidgetRef ref, Map<String, dynamic> e, bool recebido) async {
    try {
      await ApiService.patch('/plano/entradas/${e['id']}', {'recebido': recebido});
      ref.invalidate(entradasMesProvider(limite.mes));
    } catch (err) {
      avisar(mensagemErro(err), erro: true);
    }
  }

  static String _tipo(Map<String, dynamic> e, String mes) => switch (e['tipo']) {
        'vale' => 'saldo em cartão benefício',
        'eventual' => e['destino'] == 'reserva'
            ? 'eventual · para a reserva'
            : 'eventual${e['dia'] != null ? ' · dia ${e['dia']}' : ''} (prioridade: contas de ${nomeMes(mes)})',
        _ => 'garantida${e['dia'] != null ? ' · dia ${e['dia']}' : ''}',
      };

  /// Receita eventual ainda fora da conta: tocar no cadeado marca como recebida.
  Future<void> _confirmarRecebida(BuildContext context, WidgetRef ref, Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NBColors.cartao,
        title: Text('${e['nome'] ?? 'Receita'} caiu?', style: NBText.secao),
        content: Text('Ao marcar como recebida, ela passa a pagar as contas do mês e reduz o que sai da reserva.',
            style: NBText.corpo),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ainda não')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Marcar como recebida')),
        ],
      ),
    );
    if (ok == true) await _marcar(ref, e, true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receitas = limite.receitas;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('RECEITAS DO MÊS (+)', style: NBText.eyebrow)),
        IconButton(
          tooltip: 'Nova receita prevista',
          onPressed: () => abrirSheet(context, SheetEntrada(mes: limite.mes)),
          icon: const Icon(Icons.add_circle_outline, color: NBColors.verde),
        ),
      ]),
      if (receitas.isEmpty) Text('Cadastre as receitas previstas: salário e vale-alimentação.', style: NBText.legenda),
      for (final e in receitas)
        if (e['tipo'] == 'eventual' && e['recebido'] != true)
          CartaoNB(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onTap: () => abrirSheet(context, SheetEntrada(mes: limite.mes, entrada: e)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: IconButton(
                tooltip: 'Marcar como recebida',
                icon: const Icon(Icons.lock_outline_rounded, color: NBColors.tintaSuave),
                onPressed: () => _confirmarRecebida(context, ref, e),
              ),
              title: Text(e['nome'] as String? ?? '', style: NBText.corpo),
              subtitle: Text(_tipo(e, limite.mes), style: NBText.legenda),
              trailing: Text(brl((e['valor'] as num?) ?? 0), style: NBText.rotulo.copyWith(color: NBColors.tintaSuave)),
            ),
          )
        else
          CartaoNB(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onTap: () => abrirSheet(context, SheetEntrada(mes: limite.mes, entrada: e)),
            child: CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              controlAffinity: ListTileControlAffinity.leading,
              value: e['recebido'] == true,
              onChanged: (v) => _marcar(ref, e, v ?? false),
              title: Text(e['nome'] as String? ?? '', style: NBText.corpo),
              subtitle: Text(_tipo(e, limite.mes), style: NBText.legenda),
              secondary: Text(brl((e['valor'] as num?) ?? 0), style: NBText.rotulo),
            ),
          ),
    ]);
  }
}

class _OrcamentoPorEnvelope extends StatelessWidget {
  const _OrcamentoPorEnvelope({required this.limite});
  final LimiteMes limite;

  @override
  Widget build(BuildContext context) {
    final l = limite;
    final envs = [...l.envelopes]..sort((a, b) => l.orcadoDe(b).compareTo(l.orcadoDe(a)));
    final gasto = l.comprasDoMes + l.pendenteDeEnvelope;
    return CartaoNB(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PROGRESSO DOS ENVELOPES', style: NBText.eyebrow),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: Text('Planejado: ${brl(l.totalOrcado)}', style: NBText.legenda)),
          Text('Já gasto: ${brl(gasto)}', style: NBText.legenda),
        ]),
        const SizedBox(height: 6),
        for (final e in envs)
          if (l.orcadoDe(e) > 0 || l.realizadoDe(e) > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: Text('${e['emoji'] ?? '📦'} ${e['nome_envelope'] ?? ''}',
                        style: NBText.corpo.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    '${brl(l.realizadoDe(e))} de ${brl(l.orcadoDe(e))}',
                    style:
                        NBText.legenda.copyWith(color: l.disponivelDe(e) < 0 ? NBColors.estouro : NBColors.tintaSuave),
                  ),
                ]),
                const SizedBox(height: 4),
                BarraProgresso(
                  fracao: l.orcadoDe(e) > 0 ? l.realizadoDe(e) / l.orcadoDe(e) : 1,
                  cor: l.disponivelDe(e) < 0 ? NBColors.estouro : NBColors.verde,
                ),
              ]),
            ),
        const Divider(height: 16),
        LinhaValorNB('Saldo disponível para gastar hoje', l.podeGastar, forte: true, cor: _cor(l.podeGastar)),
      ]),
    );
  }
}

/// Outubro/2026: o mês da virada para o modelo novo.
class _Transicao extends StatelessWidget {
  const _Transicao({required this.limite});
  final LimiteMes limite;

  @override
  Widget build(BuildContext context) {
    final l = limite;
    return Container(
      padding: const EdgeInsets.all(NBSpacing.m),
      decoration: BoxDecoration(color: NBColors.ambarClaro, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('AVISO: TRANSIÇÃO DE OUTUBRO', style: NBText.eyebrow.copyWith(color: NBColors.ambarTexto)),
        const SizedBox(height: 4),
        Text(
          '${l.dinheiroAnterior > 0 ? 'Parte do salário de setembro (${brl(l.dinheiroAnterior)}) já pagou a fatura atual. ' : ''}'
          'O restante das contas de outubro sairá da reserva'
          '${l.eventuaisAReceber.isNotEmpty ? ' (ajudado pelo aluguel, quando ele cair)' : ''}.',
          style: NBText.corpo.copyWith(fontSize: 13.5, color: NBColors.ambarTexto),
        ),
      ]),
    );
  }
}
