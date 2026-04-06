import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/envelopes_provider.dart';
import '../../theme/app_theme.dart';

/// Sumário de saúde dos envelopes: ✅ OK | ⚠️ Atenção | 🔴 Crítico
class EnvelopeHealthSummary extends ConsumerWidget {
  const EnvelopeHealthSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envelopes = ref.watch(envelopesProvider).value ?? [];

    int ok = 0, atencao = 0, critico = 0;
    for (var e in envelopes) {
      final saldo = (e['saldo_atual'] as num).toDouble();
      final plan = (e['valor_planejado'] as num).toDouble();
      if (plan <= 0) continue;
      final pct = saldo / plan;
      if (pct < 0 || pct <= 0.2) {
        critico++;
      } else if (pct <= 0.5) {
        atencao++;
      } else {
        ok++;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Row(
        children: [
          _buildMiniCard('$ok', '✅ OK', AppColors.grn),
          const SizedBox(width: 8),
          _buildMiniCard('$atencao', '⚠️ Atenção', AppColors.org),
          const SizedBox(width: 8),
          _buildMiniCard('$critico', '🔴 Crítico', AppColors.red),
        ],
      ),
    );
  }

  Widget _buildMiniCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}
