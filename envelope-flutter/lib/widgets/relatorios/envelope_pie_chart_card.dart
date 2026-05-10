import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

// Cores distintas para cada fatia do gráfico (igual protótipo)
const _kSliceColors = [
  Color(0xFFFF9800), // laranja
  Color(0xFFEF4444), // vermelho
  Color(0xFF8DC65B), // verde
  Color(0xFFA78BFA), // roxo
  Color(0xFF60A5FA), // azul
  Color(0xFF14B8A6), // teal
  Color(0xFFFFD700), // amarelo
  Color(0xFFEC4899), // rosa
];

class EnvelopePieChartCard extends StatelessWidget {
  final List<Map<String, dynamic>> envelopes;
  final double totGasto;
  final Map<String, double> gastosPorEnvelope;

  const EnvelopePieChartCard({
    super.key,
    required this.envelopes,
    required this.totGasto,
    required this.gastosPorEnvelope,
  });

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    final fmtS = NumberFormat.simpleCurrency(locale: 'pt_BR', decimalDigits: 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gastos por envelope', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            // Layout horizontal: pizza à esquerda, legenda à direita (protótipo)
            Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    children: [
                      PieChart(PieChartData(
                        sectionsSpace: 2.5,
                        centerSpaceRadius: 38,
                        sections: _getSections(items),
                      )),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(fmtS.format(totGasto), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const Text('gasto total', style: TextStyle(fontSize: 9, color: AppColors.mu)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items.take(6).map((item) => _buildLegendRow(item, fmtS)).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<_PieItem> _buildItems() {
    final List<_PieItem> result = [];
    final sorted = List<Map<String, dynamic>>.from(envelopes);
    sorted.sort((a, b) {
      final ga = gastosPorEnvelope[a['id']] ?? 0;
      final gb = gastosPorEnvelope[b['id']] ?? 0;
      return gb.compareTo(ga);
    });

    for (int i = 0; i < sorted.length && i < 8; i++) {
      final e = sorted[i];
      final gasto = gastosPorEnvelope[e['id']] ?? 0;
      if (gasto <= 0) continue;
      result.add(_PieItem(
        nome: (e['nome_envelope'] ?? '?').toString().split(' ')[0],
        emoji: e['emoji'] ?? '📦',
        valor: gasto,
        color: _kSliceColors[i % _kSliceColors.length],
        pct: totGasto > 0 ? gasto / totGasto : 0,
      ));
    }
    return result;
  }

  List<PieChartSectionData> _getSections(List<_PieItem> items) {
    if (items.isEmpty) {
      return [PieChartSectionData(value: 1, color: AppColors.bord, radius: 30, showTitle: false)];
    }
    return items.map((item) => PieChartSectionData(
      value: item.valor,
      color: item.color,
      radius: 30,
      showTitle: false,
    )).toList();
  }

  Widget _buildLegendRow(_PieItem item, NumberFormat fmt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(item.nome, style: const TextStyle(fontSize: 11, color: AppColors.mu)),
                ],
              ),
              Text(fmt.format(item.valor), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: item.color)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: item.pct,
              minHeight: 3,
              backgroundColor: AppColors.bord,
              color: item.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PieItem {
  final String nome, emoji;
  final double valor, pct;
  final Color color;
  const _PieItem({required this.nome, required this.emoji, required this.valor, required this.color, required this.pct});
}
