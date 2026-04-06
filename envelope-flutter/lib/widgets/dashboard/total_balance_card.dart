import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../screens/abastecer_sheet.dart';
import '../../providers/envelopes_provider.dart';
import '../../providers/fixos_provider.dart';

class TotalBalanceCard extends ConsumerWidget {
  final double saldo;
  const TotalBalanceCard({super.key, required this.saldo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(totalStatsProvider);
    final totalPlanejado = stats['planned'] ?? 0.0;
    final totalGasto = stats['spent'] ?? 0.0;
    final totalDisponivel = stats['available'] ?? 0.0;
    final reservado = ref.watch(totalReservadoProvider);
    final livre = saldo - reservado;

    final pctRestante = totalPlanejado > 0 ? (totalDisponivel / totalPlanejado).clamp(0.0, 1.0) : 0.0;
    final pgC = pctRestante > 0.5 ? AppColors.grn : pctRestante > 0.2 ? AppColors.org : AppColors.red;
    final fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C2517), Color(0xFF202B19)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A4830)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SALDO GERAL', style: TextStyle(fontSize: 11, color: AppColors.mu, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(fmt.format(saldo), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.acc, letterSpacing: -1)),

          // Reservado + Livre
          if (reservado > 0) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Text('🔒 ', style: TextStyle(fontSize: 12)),
                  Text('Reservado fixos: ', style: TextStyle(fontSize: 11, color: AppColors.org.withOpacity(0.8))),
                  Text(fmt.format(reservado), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.org)),
                ]),
              ],
            ),
            const SizedBox(height: 4),
            Row(children: [
              const Text('⚡ ', style: TextStyle(fontSize: 12)),
              const Text('Livre p/ envelopes: ', style: TextStyle(fontSize: 11, color: AppColors.acc)),
              Text(fmt.format(livre > 0 ? livre : 0), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.acc)),
            ]),
          ],

          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: pctRestante, minHeight: 6, backgroundColor: AppColors.bord, color: pgC),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(TextSpan(text: 'Gasto: ', style: const TextStyle(fontSize: 11, color: AppColors.mu), children: [TextSpan(text: fmt.format(totalGasto > 0 ? totalGasto : 0), style: const TextStyle(color: AppColors.tx, fontWeight: FontWeight.bold))])),
              Text.rich(TextSpan(text: 'Planejado: ', style: const TextStyle(fontSize: 11, color: AppColors.mu), children: [TextSpan(text: fmt.format(totalPlanejado), style: const TextStyle(color: AppColors.tx, fontWeight: FontWeight.bold))])),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const AbastecerSheet()),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF8DC65B)),
                backgroundColor: AppColors.acc.withOpacity(0.12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('⚡ Distribuir nos envelopes', style: TextStyle(color: AppColors.acc, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
