import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/saude_provider.dart';

// Backend às vezes retorna {} vazio em vez de [] quando não há dados
List<Map<String, dynamic>> _asList(dynamic value) {
  if (value is List) return value.cast<Map<String, dynamic>>();
  return [];
}

class HistoricoSaudeView extends ConsumerStatefulWidget {
  final String membroId;
  const HistoricoSaudeView({super.key, required this.membroId});

  @override
  ConsumerState<HistoricoSaudeView> createState() => _HistoricoSaudeViewState();
}

class _HistoricoSaudeViewState extends ConsumerState<HistoricoSaudeView> {
  String _periodo = 'semanal';

  @override
  Widget build(BuildContext context) {
    final historicoAsync = ref.watch(historicoProvider((membroId: widget.membroId, periodo: _periodo)));
    final pesoAsync      = ref.watch(historicoPesoProvider(widget.membroId));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildFiltros()),
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
            data: (hist) => _buildGraficoCalorias(hist),
          ),
        ),
        SliverToBoxAdapter(
          child: pesoAsync.when(
            loading: () => const SizedBox.shrink(),
            error:   (_, __) => const SizedBox.shrink(),
            data:    (peso) => _buildGraficoPeso(peso),
          ),
        ),
        SliverToBoxAdapter(
          child: historicoAsync.maybeWhen(
            data: (hist) => _buildEstatisticas(hist),
            orElse: () => const SizedBox.shrink(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ── Filtros de período ────────────────────────────────────────────────────

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _periodoBtn('semanal', '7 dias'),
          const SizedBox(width: 8),
          _periodoBtn('mensal', '30 dias'),
        ],
      ),
    );
  }

  Widget _periodoBtn(String valor, String label) {
    final selected = _periodo == valor;
    return GestureDetector(
      onTap: () => setState(() => _periodo = valor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.grn.withOpacity(0.2) : AppColors.surf,
          borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
          border: Border.all(color: selected ? AppColors.grn : AppColors.bord),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? AppColors.grn : AppColors.mu,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ── Gráfico de calorias ───────────────────────────────────────────────────

  Widget _buildGraficoCalorias(Map<String, dynamic> hist) {
    final series    = _asList(hist['series']);
    final metaKcal  = (hist['meta_calorica_kcal'] as num?)?.toDouble() ?? 2000;

    // Dados de fallback
    final dadosFinal = series.isNotEmpty ? series : _fallbackSeries();

    final spots = dadosFinal.asMap().entries.map((e) {
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
              getDrawingHorizontalLine: (_) => const FlLine(
                color: AppColors.bord, strokeWidth: 0.5,
              ),
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
                    if (i < 0 || i >= dadosFinal.length) return const SizedBox.shrink();
                    final data = dadosFinal[i]['data'] as String? ?? '';
                    final parts = data.split('-');
                    if (parts.length < 3) return const SizedBox.shrink();
                    return Text(
                      '${parts[2]}/${parts[1]}',
                      style: const TextStyle(fontSize: 9, color: AppColors.mu),
                    );
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
                color: AppColors.grn,
                barWidth: 2.5,
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.grn.withOpacity(0.1),
                ),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 3,
                    color: AppColors.grn,
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

  // ── Gráfico de peso ───────────────────────────────────────────────────────

  Widget _buildGraficoPeso(Map<String, dynamic> pesoData) {
    final registros = _asList(pesoData['registros']);
    final mediaMovel = (pesoData['media_movel_7d'] as num?)?.toDouble();

    if (registros.isEmpty) return const SizedBox.shrink();

    final spots = registros.asMap().entries.map((e) {
      final peso = (e.value['peso_kg'] as num?)?.toDouble() ?? 0;
      return FlSpot(e.key.toDouble(), peso);
    }).toList();

    final pesos  = spots.map((s) => s.y).toList();
    final minP   = pesos.reduce((a, b) => a < b ? a : b) - 1;
    final maxP   = pesos.reduce((a, b) => a > b ? a : b) + 1;

    return _ChartCard(
      title: 'Evolução de Peso',
      subtitle: mediaMovel != null ? 'Tendência 7d: ${mediaMovel.toStringAsFixed(1)}kg' : null,
      child: SizedBox(
        height: 160,
        child: LineChart(
          LineChartData(
            minY: minP,
            maxY: maxP,
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
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: AppColors.mu.withOpacity(0.4),
                barWidth: 1.5,
                dotData: const FlDotData(show: false),
              ),
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

  // ── Estatísticas do período ───────────────────────────────────────────────

  Widget _buildEstatisticas(Map<String, dynamic> hist) {
    final series      = _asList(hist['series']);
    final totalRefeis = (hist['total_refeicoes'] as num?)?.toInt() ?? 0;
    final mediaKcal   = (hist['media_calorias_kcal'] as num?)?.toInt() ?? 0;
    final diasAtivos  = series.where((s) => ((s['calorias_kcal'] as num?)?.toDouble() ?? 0) > 0).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RESUMO DO PERÍODO',
              style: TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatItem(label: 'Dias ativos', value: '$diasAtivos', icon: '📅', color: AppColors.grn),
                _StatItem(label: 'Refeições', value: '$totalRefeis', icon: '🍽️', color: AppColors.acc),
                _StatItem(label: 'Média kcal', value: '$mediaKcal', icon: '⚡', color: AppColors.org),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Fallback data ─────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _fallbackSeries() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return {
        'data': '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        'calorias_kcal': 0,
      };
    });
  }
}

// ── Widgets internos ──────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _ChartCard({required this.title, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.tx),
          ),
          if (subtitle != null)
            Text(subtitle!, style: const TextStyle(fontSize: 11, color: AppColors.mu)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.mu)),
        ],
      ),
    );
  }
}
