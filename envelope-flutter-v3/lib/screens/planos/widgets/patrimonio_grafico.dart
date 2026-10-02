import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/patrimonio_provider.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';

class PatrimonioGrafico extends ConsumerWidget {
  const PatrimonioGrafico({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evolucao = ref.watch(evolucaoPatrimonioProvider);

    if (evolucao.length < 2) {
      return const SizedBox.shrink();
    }

    final spots = <FlSpot>[];
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (int i = 0; i < evolucao.length; i++) {
      final val = evolucao[i].total;
      spots.add(FlSpot(i.toDouble(), val));
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
    }

    // Margem no gráfico
    final diff = maxY - minY;
    final paddingY = diff > 0 ? diff * 0.15 : 1000.0;
    final finalMinY = (minY - paddingY).clamp(0.0, double.infinity);
    final finalMaxY = maxY + paddingY;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CartaoNB(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EVOLUÇÃO DO PATRIMÔNIO', style: NBText.eyebrow),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < evolucao.length) {
                            final partes = evolucao[idx].mes.split('-');
                            final mesNum = int.tryParse(partes.last) ?? 1;
                            const mLabels = ['', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(mLabels[mesNum], style: NBText.legenda),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (evolucao.length - 1).toDouble(),
                  minY: finalMinY,
                  maxY: finalMaxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: NBColors.verde,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: NBColors.verde.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
