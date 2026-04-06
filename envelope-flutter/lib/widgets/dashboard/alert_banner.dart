import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/envelopes_provider.dart';
import '../../theme/app_theme.dart';

/// Banner de alerta para envelopes negativos (igual ao protótipo)
class AlertBanner extends ConsumerWidget {
  const AlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envelopes = ref.watch(envelopesProvider).value ?? [];
    final negativos = envelopes.where((e) => (e['saldo_atual'] as num).toDouble() < 0).length;

    if (negativos == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dred.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dred.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('🚨', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Text(
            '$negativos envelope${negativos > 1 ? 's estão' : ' está'} negativo${negativos > 1 ? 's' : ''}.',
            style: const TextStyle(fontSize: 12, color: Color(0xFFFF6B6B), height: 1.4),
          ),
        ],
      ),
    );
  }
}
