import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../providers/saude_provider.dart';

class HistoricoScreen extends ConsumerStatefulWidget {
  final String membroId;

  const HistoricoScreen({super.key, required this.membroId});

  @override
  ConsumerState<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends ConsumerState<HistoricoScreen> {
  String _periodo = 'semanal';

  @override
  Widget build(BuildContext context) {
    final historicoAsync = ref.watch(historicoProvider((membroId: widget.membroId, periodo: _periodo)));
    final pesoAsync = ref.watch(historicoPesoProvider(widget.membroId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(
              child: historicoAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator(color: AppColors.grn)),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Erro: $e', style: const TextStyle(color: AppColors.red)),
                ),
                data: (hist) => _buildCaloricChart(hist),
              ),
            ),
            SliverToBoxAdapter(
              child: pesoAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (peso) => _buildWeightChart(peso),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Histórico', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.tx)),
          const SizedBox(height: 12),
          Row(
            children: [
              _periodoBtn('semanal', '7 dias'),
              const SizedBox(width: 8),
              _periodoBtn('mensal', '30 dias'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodoBtn(String valor, String label) {
    final isSelected = _periodo == valor;
    return GestureDetector(
      onTap: () => setState(() => _periodo = valor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.grn.withOpacity(0.2) : AppColors.surf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.grn : AppColors.bord),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? AppColors.grn : AppColors.mu,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCaloricChart(Map<String, dynamic> hist) {
    final series = (hist['series'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final metaKcal = (hist['meta_calorica_kcal'] as num?)?.toDouble() ?? 2000;

    if (series.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Sem dados de calorias ainda.', style: TextStyle(color: AppColors.mu))),
      );
    }

    final spots = series.asMap().entries.map((e) {
      final kcal = (e.value['calorias_kcal'] as num?)?.toDouble() ?? 0;
      return FlSpot(e.key.toDouble(), kcal);
    }).toList();

    return _ChartCard(
      title: 'Calorias Diárias',
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: (metaKcal * 1.3).ceilToDouble(),
            gridData: FlGridData(
              show: true,
              getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.bord, strokeWidth: 0.5),
              drawVerticalLine: false,
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (value, _) {
                    final i = value.toInt();
                    if (i < 0 || i >= series.length) return const SizedBox.shrink();
                    final data = series[i]['data'] as String? ?? '';
                    final parts = data.split('-');
                    if (parts.length < 3) return const SizedBox.shrink();
                    return Text('${parts[2]}/${parts[1]}', style: const TextStyle(fontSize: 9, color: AppColors.mu));
                  },
                ),
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: metaKcal,
                  color: AppColors.grn.withOpacity(0.5),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    labelResolver: (_) => 'Meta',
                    style: const TextStyle(fontSize: 10, color: AppColors.grn),
                  ),
                ),
              ],
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.acc,
                barWidth: 2.5,
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.acc.withOpacity(0.1),
                ),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 3,
                    color: AppColors.acc,
                    strokeWidth: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeightChart(Map<String, dynamic> pesoData) {
    final registros = (pesoData['registros'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final mediaMovel = (pesoData['media_movel_7d'] as num?)?.toDouble();

    if (registros.isEmpty) return const SizedBox.shrink();

    final spots = registros.asMap().entries.map((e) {
      final peso = (e.value['peso_kg'] as num?)?.toDouble() ?? 0;
      return FlSpot(e.key.toDouble(), peso);
    }).toList();

    final pesos = spots.map((s) => s.y).toList();
    final minPeso = pesos.reduce((a, b) => a < b ? a : b) - 1;
    final maxPeso = pesos.reduce((a, b) => a > b ? a : b) + 1;

    return _ChartCard(
      title: 'Evolução de Peso',
      subtitle: mediaMovel != null ? 'Tendência 7d: ${mediaMovel.toStringAsFixed(1)}kg' : null,
      child: SizedBox(
        height: 160,
        child: LineChart(
          LineChartData(
            minY: minPeso,
            maxY: maxPeso,
            gridData: FlGridData(
              show: true,
              getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.bord, strokeWidth: 0.5),
              drawVerticalLine: false,
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, _) => Text(
                    v.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 9, color: AppColors.mu),
                  ),
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              // Linha bruta (cinza fino)
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: AppColors.mu.withOpacity(0.4),
                barWidth: 1.5,
                dotData: const FlDotData(show: false),
              ),
              // Linha de tendência (colorida)
              if (mediaMovel != null)
                LineChartBarData(
                  spots: spots.map((s) => FlSpot(s.x, mediaMovel)).toList(),
                  isCurved: false,
                  color: AppColors.blu,
                  barWidth: 2.5,
                  dashArray: [6, 3],
                  dotData: const FlDotData(show: false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _ChartCard({required this.title, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.tx)),
          if (subtitle != null)
            Text(subtitle!, style: const TextStyle(fontSize: 11, color: AppColors.mu)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
