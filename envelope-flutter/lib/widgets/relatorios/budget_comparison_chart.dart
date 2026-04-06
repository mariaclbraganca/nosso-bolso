import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

/// Gráfico de barras horizontais: Planejado vs Gasto por envelope
class BudgetComparisonChart extends StatelessWidget {
  final List<Map<String, dynamic>> envelopes;

  const BudgetComparisonChart({super.key, required this.envelopes});

  @override
  Widget build(BuildContext context) {
    // Filtrar e ordenar por gasto
    final items = <_BudgetItem>[];
    for (var e in envelopes) {
      final plan = (e['valor_planejado'] as num).toDouble();
      final saldo = (e['saldo_atual'] as num).toDouble();
      final gasto = plan - saldo;
      if (plan <= 0) continue;
      items.add(_BudgetItem(
        nome: (e['nome_envelope'] ?? '?').toString().split(' ')[0],
        emoji: e['emoji'] ?? '📦',
        planejado: plan,
        gasto: gasto > 0 ? gasto : 0,
        pct: (gasto / plan * 100).clamp(0, 999),
      ));
    }
    items.sort((a, b) => b.pct.compareTo(a.pct));
    final topItems = items.take(6).toList();

    if (topItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final fmtS = NumberFormat.simpleCurrency(locale: 'pt_BR', decimalDigits: 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Planejado vs Gasto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Row(
              children: [
                _LegendDot(color: AppColors.bord, label: 'Planejado'),
                SizedBox(width: 16),
                _LegendDot(color: AppColors.acc, label: 'Gasto'),
              ],
            ),
            const SizedBox(height: 14),
            ...topItems.map((item) => _buildRow(item, fmtS)),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(_BudgetItem item, NumberFormat fmt) {
    final pct = (item.gasto / item.planejado).clamp(0.0, 1.0);
    final overBudget = item.gasto > item.planejado;
    final barColor = overBudget ? AppColors.red : (pct > 0.7 ? AppColors.org : AppColors.acc);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${item.emoji} ${item.nome}', style: const TextStyle(fontSize: 12, color: AppColors.tx)),
              Row(
                children: [
                  Text(fmt.format(item.gasto), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: barColor)),
                  Text(' / ${fmt.format(item.planejado)}', style: const TextStyle(fontSize: 11, color: AppColors.mu)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              // Barra planejado (fundo inteiro)
              Container(
                height: 8,
                decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(4)),
              ),
              // Barra gasto
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.mu)),
      ],
    );
  }
}

class _BudgetItem {
  final String nome, emoji;
  final double planejado, gasto, pct;
  const _BudgetItem({required this.nome, required this.emoji, required this.planejado, required this.gasto, required this.pct});
}
