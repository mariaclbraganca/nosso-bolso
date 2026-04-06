import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class StatCardRow extends StatelessWidget {
  final double totRec;
  final double totGasto;
  final double? pctRec;
  final double? pctGasto;

  const StatCardRow({
    super.key, 
    required this.totRec, 
    required this.totGasto,
    this.pctRec,
    this.pctGasto,
  });

  @override
  Widget build(BuildContext context) {
    final saldo = totRec - totGasto;
    return Row(
      children: [
        _buildStatCard('RECEITAS', totRec, AppColors.grn, pctRec),
        const SizedBox(width: 8),
        _buildStatCard('GASTOS', totGasto, AppColors.red, pctGasto, invertColor: true),
        const SizedBox(width: 8),
        _buildStatCard('SALDO', saldo, saldo >= 0 ? AppColors.grn : AppColors.red, null),
      ],
    );
  }

  Widget _buildStatCard(String label, double val, Color color, double? pct, {bool invertColor = false}) {
    Color pctColor = AppColors.mu;
    String sign = '';
    if (pct != null && pct != 0) {
      if (pct > 0) {
        sign = '↑';
        pctColor = invertColor ? AppColors.red : AppColors.grn;
      } else {
        sign = '↓';
        pctColor = invertColor ? AppColors.grn : AppColors.red;
      }
    }

    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 9, color: AppColors.mu, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                NumberFormat.simpleCurrency(locale: 'pt_BR', decimalDigits: 0).format(val),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
              if (pct != null && pct != 0) ...[
                const SizedBox(height: 2),
                Text(
                  '$sign ${pct.abs().toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pctColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
