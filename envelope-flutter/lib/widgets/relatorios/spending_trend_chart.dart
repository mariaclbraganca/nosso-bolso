import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/transacoes_provider.dart';

/// Gráfico de linha: evolução de gastos acumulados ao longo do mês
class SpendingTrendChart extends ConsumerWidget {
  const SpendingTrendChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transacoes = ref.watch(transacoesComDetalhesProvider);
    final now = DateTime.now();
    final diasNoMes = DateTime(now.year, now.month + 1, 0).day;

    // Acumular gastos por dia
    final Map<int, double> gastoPorDia = {};
    for (var t in transacoes) {
      if (t['tipo'] == 'despesa' && t['created_at'] != null) {
        final dt = DateTime.parse(t['created_at']);
        final dia = dt.day;
        gastoPorDia[dia] = (gastoPorDia[dia] ?? 0) + (t['valor'] as num).toDouble();
      }
    }

    // Calcular acumulado
    final List<FlSpot> spots = [];
    double acumulado = 0;
    for (int d = 1; d <= now.day; d++) {
      acumulado += gastoPorDia[d] ?? 0;
      spots.add(FlSpot(d.toDouble(), acumulado));
    }

    if (spots.isEmpty) return const SizedBox.shrink();

    final maxY = acumulado > 0 ? acumulado * 1.15 : 100.0;
    final fmtS = NumberFormat.simpleCurrency(locale: 'pt_BR', decimalDigits: 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Evolução de gastos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(fmtS.format(acumulado), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.red)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Acumulado até dia ${now.day}/$diasNoMes', style: const TextStyle(fontSize: 10, color: AppColors.mu)),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minX: 1,
                  maxX: diasNoMes.toDouble(),
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (v) => const FlLine(color: AppColors.bord, strokeWidth: 0.5),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: maxY / 4,
                        getTitlesWidget: (v, m) => Text(fmtS.format(v), style: const TextStyle(fontSize: 9, color: AppColors.mu)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (diasNoMes / 5).ceilToDouble(),
                        getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9, color: AppColors.mu)),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: AppColors.red,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.red.withOpacity(0.25), AppColors.red.withOpacity(0.02)],
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                        'Dia ${s.x.toInt()}\n${fmtS.format(s.y)}',
                        const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.tx),
                      )).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
