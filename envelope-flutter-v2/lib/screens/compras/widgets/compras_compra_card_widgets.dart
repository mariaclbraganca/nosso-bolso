import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Seção com listagem detalhada de itens da nota fiscal agrupados por categoria
Widget buildItensExpandidosCompra(Map<String, List<Map<String, dynamic>>> porCategoria) {
  return Column(
    children: [
      const Divider(height: 1, thickness: 0.5, color: AppColors.bord),
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.pagePad, 12, AppSpacing.pagePad, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: porCategoria.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(entry.key, style: AppTextStyles.caption.copyWith(color: AppColors.acc, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ),
                ...entry.value.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_manual_record_rounded, size: 6, color: AppColors.mu),
                      const SizedBox(width: 6),
                      Expanded(child: Text(item['nome_padronizado'] as String? ?? '', style: AppTextStyles.caption.copyWith(color: AppColors.tx))),
                      Text('${item['quantidade']} ${item['unidade']}', style: AppTextStyles.caption),
                      const SizedBox(width: 8),
                      Text('R\$ ${(item['valor_total_item'] as num).toStringAsFixed(2)}', style: AppTextStyles.caption.copyWith(color: AppColors.acc)),
                    ],
                  ),
                )),
              ],
            );
          }).toList(),
        ),
      ),
    ],
  );
}
