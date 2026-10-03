import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/saude_provider.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';

/// Evolução de calorias (com a linha da meta), proteína e peso.
class HistoricoSaudeScreen extends ConsumerStatefulWidget {
  const HistoricoSaudeScreen({super.key, required this.membroId});
  final String membroId;

  @override
  ConsumerState<HistoricoSaudeScreen> createState() => _HistoricoSaudeScreenState();
}

class _HistoricoSaudeScreenState extends ConsumerState<HistoricoSaudeScreen> {
  String _periodo = 'semanal';

  List<(String, double)> _serie(Map? series, String chave) => [
        for (final p in ((series?[chave] as List?) ?? const []))
          ((p['data'] as String?) ?? '', ((p['valor'] as num?) ?? 0).toDouble()),
      ];

  @override
  Widget build(BuildContext context) {
    final dados = ref.watch(historicoProvider((membroId: widget.membroId, periodo: _periodo)));
    return Scaffold(
      appBar: AppBar(title: const Text('Evolução')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
        children: [
          Segmentado<String>(
            opcoes: const {'semanal': '7 dias', 'mensal': '30 dias'},
            valor: _periodo,
            onChanged: (p) => setState(() => _periodo = p),
          ),
          const SizedBox(height: NBSpacing.l),
          ...dados.when(
            loading: () => [const SizedBox(height: 240, child: UnicornCarregando(texto: 'Juntando os registros…'))],
            error: (e, _) => [
              UnicornErro(
                mensagem: 'Não consegui carregar a evolução.',
                onTentar: () => ref.invalidate(historicoProvider),
              ),
            ],
            data: (d) {
              final series = d['series'] as Map?;
              final meta = (d['meta_calorica_kcal'] as num?)?.toDouble() ?? 0;
              final peso = _serie(series, 'peso');
              final media = (d['media_movel_peso_kg'] as num?)?.toDouble();
              return [
                _Grafico(
                  titulo: 'Calorias por dia',
                  legenda: meta > 0 ? 'Linha tracejada: meta de ${meta.round()} kcal' : null,
                  pontos: _serie(series, 'calorias'),
                  cor: NBColors.verde,
                  meta: meta > 0 ? meta : null,
                  barras: true,
                ),
                const SizedBox(height: NBSpacing.l),
                _Grafico(titulo: 'Proteína por dia (g)', pontos: _serie(series, 'proteina'), cor: NBColors.reserva, barras: true),
                const SizedBox(height: NBSpacing.l),
                if (peso.length >= 2)
                  _Grafico(
                    titulo: 'Peso (kg)',
                    legenda: media == null ? null : 'Média recente: ${media.toStringAsFixed(1).replaceAll('.', ',')} kg',
                    pontos: peso,
                    cor: NBColors.lavanda,
                  )
                else
                  CartaoNB(
                    child: Text(
                      peso.isEmpty
                          ? 'Nenhuma pesagem neste período. Registre o peso na aba Saúde.'
                          : 'Uma pesagem só. Registre mais vezes para ver a curva.',
                      style: NBText.corpo.copyWith(color: NBColors.tintaSuave),
                    ),
                  ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

class _Grafico extends StatelessWidget {
  const _Grafico({
    required this.titulo,
    required this.pontos,
    required this.cor,
    this.legenda,
    this.meta,
    this.barras = false,
  });

  final String titulo;
  final String? legenda;
  final List<(String, double)> pontos;
  final Color cor;
  final double? meta;
  final bool barras;

  @override
  Widget build(BuildContext context) {
    final maxValor = [...pontos.map((p) => p.$2), meta ?? 0].fold<double>(0, (a, b) => b > a ? b : a);
    final minPeso = barras ? 0.0 : pontos.map((p) => p.$2).reduce((a, b) => a < b ? a : b) - 1;
    final teto = maxValor <= 0 ? 1.0 : maxValor * 1.15;
    String rotuloX(double x) {
      final i = x.round();
      if (i < 0 || i >= pontos.length) return '';
      final passo = pontos.length > 10 ? 7 : 1;
      if (i % passo != 0 && i != pontos.length - 1) return '';
      final data = pontos[i].$1;
      return data.length >= 10 ? '${data.substring(8, 10)}/${data.substring(5, 7)}' : '';
    }

    final eixos = FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 36,
          getTitlesWidget: (v, meta) => Text(v.round().toString(), style: NBText.legenda.copyWith(fontSize: 10)),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: 1,
          getTitlesWidget: (v, _) => Text(rotuloX(v), style: NBText.legenda.copyWith(fontSize: 10)),
        ),
      ),
    );
    final grade = FlGridData(
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) => const FlLine(color: NBColors.linha, strokeWidth: 1),
    );
    final linhaMeta = meta == null
        ? null
        : ExtraLinesData(horizontalLines: [
            HorizontalLine(y: meta!, color: NBColors.ambarBarra, strokeWidth: 1.5, dashArray: [6, 4]),
          ]);

    return CartaoNB(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: NBText.rotulo),
          if (legenda != null) Text(legenda!, style: NBText.legenda),
          const SizedBox(height: NBSpacing.m),
          SizedBox(
            height: 180,
            child: barras
                ? BarChart(BarChartData(
                    maxY: teto,
                    minY: 0,
                    gridData: grade,
                    borderData: FlBorderData(show: false),
                    titlesData: eixos,
                    extraLinesData: linhaMeta,
                    barGroups: [
                      for (var i = 0; i < pontos.length; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: pontos[i].$2,
                            color: cor,
                            width: pontos.length > 10 ? 5 : 14,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ]),
                    ],
                  ))
                : LineChart(LineChartData(
                    minY: minPeso,
                    maxY: teto,
                    gridData: grade,
                    borderData: FlBorderData(show: false),
                    titlesData: eixos,
                    lineBarsData: [
                      LineChartBarData(
                        spots: [for (var i = 0; i < pontos.length; i++) FlSpot(i.toDouble(), pontos[i].$2)],
                        color: cor,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(show: true, color: cor.withValues(alpha: 0.12)),
                      ),
                    ],
                  )),
          ),
        ],
      ),
    );
  }
}
