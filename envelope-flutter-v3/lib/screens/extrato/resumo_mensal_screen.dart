import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/mes_provider.dart';
import '../../core/providers/transacoes_provider.dart';
import '../../core/utils/extrato_calculos.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';

class ResumoMensalScreen extends ConsumerWidget {
  const ResumoMensalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesAtualProvider);
    final stats = ref.watch(statsPorMesProvider(mes));
    final transacoes = ref.watch(transacoesComDetalhesProvider);
    final calculo = ExtratoCalculos.calcular(transacoes);

    final comprometido = ExtratoCalculos.pctComprometido(stats.totalReceita, stats.totalDespesa);
    final status = ExtratoCalculos.statusFinanceiro(stats.totalReceita, stats.totalDespesa);
    final top = ExtratoCalculos.topEnvelopes(calculo.porEnvelope, n: 5);
    final nomeMes = mesLabelLongo(mes);

    return Scaffold(
      appBar: AppBar(title: Text('Resumo de $nomeMes')),
      body: ListView(
        padding: const EdgeInsets.all(NBSpacing.margemTela),
        children: [
          CartaoNB(
            cor: status == 'alerta' ? NBColors.estouroClaro : NBColors.verdeClaro,
            borda: status == 'alerta' ? NBColors.estouro : NBColors.verde,
            child: Row(
              children: [
                UnicornWidget(
                  type: status == 'alerta' ? UnicornType.geronimo : UnicornType.astrix,
                  size: 52,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status == 'alerta'
                            ? 'Atenção às contas'
                            : status == 'atencao'
                                ? 'Mês equilibrado'
                                : 'Excelente controle!',
                        style: NBText.secao.copyWith(
                          color: status == 'alerta' ? NBColors.estouro : NBColors.verdeProfundo,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status == 'alerta'
                            ? 'As saídas superaram os ganhos. Remaneje reservas para cobrir.'
                            : '${comprometido.toStringAsFixed(0)}% da renda foi comprometida com os envelopes.',
                        style: NBText.corpo.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NBSpacing.l),
          const CabecalhoSecao(titulo: 'Balanço Geral'),
          const SizedBox(height: NBSpacing.s),
          CartaoNB(
            child: Column(
              children: [
                LinhaPrevia(rotulo: 'Entradas do ciclo', valor: stats.totalReceita, corValor: NBColors.verde),
                LinhaPrevia(rotulo: 'Saídas totais', valor: stats.totalDespesa, corValor: NBColors.tinta),
                LinhaPrevia(rotulo: 'Total abastecido', valor: stats.totalAbastecido, corValor: NBColors.reserva),
                const Divider(height: 16),
                LinhaPrevia(rotulo: 'Saldo final', valor: stats.saldo, corValor: stats.saldo < 0 ? NBColors.estouro : NBColors.verde),
              ],
            ),
          ),
          const SizedBox(height: NBSpacing.l),
          const CabecalhoSecao(titulo: 'Top 5 Envelopes com Mais Gastos'),
          const SizedBox(height: NBSpacing.s),
          if (top.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nenhuma despesa registrada neste mês.', style: TextStyle(color: NBColors.tintaSuave)),
            )
          else
            CartaoNB(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (var i = 0; i < top.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: NBColors.afundado, shape: BoxShape.circle),
                            child: Text('${i + 1}', style: NBText.legenda.copyWith(fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(top[i].key, style: NBText.corpo)),
                          Text(brl(top[i].value), style: NBText.rotulo.copyWith(color: NBColors.tinta)),
                        ],
                      ),
                    ),
                    if (i < top.length - 1) const Divider(),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
