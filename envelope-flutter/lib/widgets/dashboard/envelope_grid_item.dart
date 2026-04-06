import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class EnvelopeGridItem extends StatelessWidget {
  final Map<String, dynamic> envelope;
  final VoidCallback? onTap;
  final VoidCallback? onAbastecer;

  const EnvelopeGridItem({super.key, required this.envelope, this.onTap, this.onAbastecer});

  @override
  Widget build(BuildContext context) {
    final saldo = (envelope['saldo_atual'] as num).toDouble();
    final isReserva = envelope['is_reserva'] ?? false;
    final plan = (envelope['valor_planejado'] as num).toDouble();
    final objetivo = (envelope['valor_objetivo'] as num?)?.toDouble() ?? 0.0;
    final fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final fmtShort = NumberFormat.simpleCurrency(locale: 'pt_BR', decimalDigits: 0);

    // Percentual: quanto do planejado ainda resta
    final pct = isReserva
        ? (objetivo > 0 ? (saldo / objetivo) : 0.0)
        : (plan > 0 ? (saldo / plan) : 0.0);

    // Cor do termômetro baseada no percentual restante
    Color color = isReserva ? AppColors.acc : AppColors.grn;
    if (!isReserva) {
      if (pct <= 0) {
        color = AppColors.red;
      } else if (pct <= 0.2) {
        color = AppColors.org;
      } else if (pct <= 0.5) {
        color = AppColors.org;
      }
    }

    // Badge text
    String badge;
    if (isReserva) {
      badge = pct >= 1.0 ? 'META ATINGIDA' : '${(pct * 100).toInt()}% alcançado';
    } else if (saldo <= 0) {
      badge = 'SEM SALDO';
    } else {
      badge = '${(pct * 100).toInt()}% restante';
    }

    final totalValue = isReserva ? objetivo : plan;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(envelope['emoji'] ?? '📦', style: const TextStyle(fontSize: 22)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(50)),
                  child: Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              envelope['nome_envelope'],
              style: const TextStyle(fontSize: 12, color: AppColors.mu, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 2),
            Text(
              fmt.format(saldo),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: saldo <= 0 ? AppColors.red : color),
            ),
            const Spacer(),
            if (saldo <= 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 28,
                  child: ElevatedButton(
                    onPressed: onAbastecer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.acc.withOpacity(0.2),
                      foregroundColor: AppColors.acc,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Abastecer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Disponível', style: TextStyle(fontSize: 9, color: AppColors.mu)),
                  Text(
                    fmt.format(saldo),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: AppColors.bord,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text('de ${fmtShort.format(totalValue)}', style: const TextStyle(fontSize: 9, color: AppColors.mu)),
          ],
        ),
      ),
    );
  }
}
