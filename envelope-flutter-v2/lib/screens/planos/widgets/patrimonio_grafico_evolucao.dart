import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';

/// Mini-gráfico de evolução histórica do patrimônio familiar
class GraficoEvolucao extends StatefulWidget {
  final List<({String mes, double total})> evolucao;
  final NumberFormat fmt;
  const GraficoEvolucao({super.key, required this.evolucao, required this.fmt});

  @override
  State<GraficoEvolucao> createState() => _GraficoEvolucaoState();
}

class _GraficoEvolucaoState extends State<GraficoEvolucao> {
  int? _toucado;

  @override
  Widget build(BuildContext context) {
    final dados = widget.evolucao;
    final minY = dados.map((e) => e.total).reduce((a, b) => a < b ? a : b);
    final maxY = dados.map((e) => e.total).reduce((a, b) => a > b ? a : b);
    final range = (maxY - minY).clamp(1.0, double.infinity);
    final chartMinY = (minY - range * 0.1).clamp(0.0, double.infinity);
    final chartMaxY = maxY + range * 0.1;

    final spots = dados.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.total)).toList();
    final cresceu = dados.last.total >= dados.first.total;
    final corLinha = cresceu ? AppColors.grn : AppColors.red;
    final diff = dados.last.total - dados.first.total;
    final pct = dados.first.total > 0 ? (diff / dados.first.total * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(
            'EVOLUÇÃO',
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
          const SizedBox(width: 8),
          if (dados.length >= 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: corLinha.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(
                '${diff >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}% em ${dados.length} meses',
                style: AppTextStyles.caption.copyWith(color: corLinha, fontSize: 10),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: LineChart(
            LineChartData(
              minY: chartMinY,
              maxY: chartMaxY,
              clipData: const FlClipData.all(),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= dados.length) return const SizedBox.shrink();
                      final mes = dados[idx].mes;
                      const meses = ['', 'jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
                      final m = int.tryParse(mes.split('-')[1]) ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(meses[m], style: AppTextStyles.caption.copyWith(fontSize: 9)),
                      );
                    },
                    reservedSize: 18,
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchCallback: (event, response) {
                  if (response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
                    setState(() => _toucado = response.lineBarSpots!.first.spotIndex);
                  } else if (event is FlTapUpEvent || event is FlPanEndEvent) {
                    setState(() => _toucado = null);
                  }
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surf,
                  getTooltipItems: (spots) => spots.map((s) {
                    final idx = s.spotIndex;
                    final item = dados[idx];
                    return LineTooltipItem(
                      widget.fmt.format(item.total),
                      AppTextStyles.caption.copyWith(color: corLinha, fontWeight: FontWeight.w700),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: corLinha,
                  barWidth: 2,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, idx) => FlDotCirclePainter(
                      radius: idx == _toucado ? 5 : 3,
                      color: idx == _toucado ? corLinha : AppColors.card,
                      strokeWidth: 2,
                      strokeColor: corLinha,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [corLinha.withOpacity(0.18), corLinha.withOpacity(0.0)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
