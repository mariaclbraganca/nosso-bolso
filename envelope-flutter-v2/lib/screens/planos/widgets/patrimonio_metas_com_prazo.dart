import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/fixos_provider.dart';
import 'patrimonio_meta_card.dart';

/// Seção com metas de poupança vinculadas a contas de patrimônio
class MetasComPrazo extends ConsumerWidget {
  final AsyncValue<List<Map<String, dynamic>>> contasAsync;
  const MetasComPrazo({super.key, required this.contasAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contas = contasAsync.value ?? [];
    final comMeta = contas.where((c) => (c['meta_saldo'] as num?) != null && (c['meta_saldo'] as num).toDouble() > 0).toList();
    if (comMeta.isEmpty) return const SizedBox.shrink();

    final saldoLivre = ref.watch(saldoLivreProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(children: [
            Text('Metas de poupança', style: AppTextStyles.titleSm),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Text('${comMeta.length}', style: AppTextStyles.caption.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 12),
          ...comMeta.map((c) => MetaCard(conta: c, saldoLivreDisponivel: saldoLivre)),
        ],
      ),
    );
  }
}
