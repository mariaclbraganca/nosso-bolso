import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/transacoes_provider.dart';
import '../../core/providers/usuarios_provider.dart';
import '../../core/utils/extrato_calculos.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';

class RelatoriosTab extends ConsumerWidget {
  const RelatoriosTab({super.key});

  static const _coresDonut = [
    NBColors.verde,
    NBColors.ambar,
    NBColors.reserva,
    NBColors.lavanda,
    NBColors.tinta,
    Color(0xFF8C5E58),
    Color(0xFF5A7D7C),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transacoes = ref.watch(transacoesComDetalhesProvider);
    final membros = ref.watch(listaUsuariosProvider).valueOrNull ?? [];
    final calculo = ExtratoCalculos.calcular(transacoes);

    if (calculo.totalDespesa <= 0 && calculo.totalReceita <= 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: UnicornVazio(
          type: UnicornType.astrix,
          titulo: 'Sem dados para o gráfico',
          texto: 'Lance receitas e gastos para ver os relatórios visuais.',
        ),
      );
    }

    final topEnvelopes = ExtratoCalculos.topEnvelopes(calculo.porEnvelope, n: 6);

    return ListView(
      padding: const EdgeInsets.all(NBSpacing.margemTela),
      children: [
        const CabecalhoSecao(titulo: 'Distribuição dos Gastos'),
        const SizedBox(height: NBSpacing.s),
        if (topEnvelopes.isNotEmpty)
          CartaoNB(
            child: Column(
              children: [
                SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        for (var i = 0; i < topEnvelopes.length; i++)
                          PieChartSectionData(
                            value: topEnvelopes[i].value,
                            color: _coresDonut[i % _coresDonut.length],
                            title: '${(topEnvelopes[i].value / calculo.totalDespesa * 100).round()}%',
                            titleStyle: NBText.legenda.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                            radius: 38,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < topEnvelopes.length; i++)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _coresDonut[i % _coresDonut.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('${topEnvelopes[i].key}: ${brl(topEnvelopes[i].value, curto: true)}', style: NBText.legenda),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: NBSpacing.l),
        if (membros.length > 1) ...[
          const CabecalhoSecao(titulo: 'Gastos por Membro da Família'),
          const SizedBox(height: NBSpacing.s),
          CartaoNB(
            child: Column(
              children: [
                for (final m in membros) ...[
                  _GastoMembroLinha(
                    membro: m,
                    transacoes: transacoes,
                    totalDespesaGeral: calculo.totalDespesa,
                  ),
                  if (m != membros.last) const Divider(height: 16),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

class _GastoMembroLinha extends StatelessWidget {
  final Map<String, dynamic> membro;
  final List<Map<String, dynamic>> transacoes;
  final double totalDespesaGeral;

  const _GastoMembroLinha({
    required this.membro,
    required this.transacoes,
    required this.totalDespesaGeral,
  });

  @override
  Widget build(BuildContext context) {
    final nome = membro['nome'] as String? ?? 'Membro';
    final id = membro['id'];
    double gastoMembro = 0;

    for (final t in transacoes) {
      if (t['usuario_id'] == id && t['tipo'] == 'despesa') {
        gastoMembro += (t['valor'] as num?)?.toDouble() ?? 0.0;
      }
    }

    final pct = totalDespesaGeral > 0 ? (gastoMembro / totalDespesaGeral).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(nome, style: NBText.rotulo),
            Text(brl(gastoMembro), style: NBText.valorCartao.copyWith(fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6),
        BarraProgresso(fracao: pct, cor: NBColors.verde),
      ],
    );
  }
}
