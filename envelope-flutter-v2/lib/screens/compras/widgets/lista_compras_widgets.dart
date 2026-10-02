import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'lista_compras_item_card.dart';

export 'lista_compras_item_card.dart';

class ResumoListaCard extends StatelessWidget {
  final String total;
  final String saldo;
  final bool dentro;
  final int dias;
  final int marcados;
  final int totalItens;

  const ResumoListaCard({
    super.key,
    required this.total,
    required this.saldo,
    required this.dentro,
    required this.dias,
    required this.marcados,
    required this.totalItens,
  });

  @override
  Widget build(BuildContext context) {
    final corStatus = dentro ? AppColors.acc : AppColors.red;
    final iconStatus = dentro ? Icons.check_circle_rounded : Icons.warning_amber_rounded;

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.pagePad, AppSpacing.pagePad, AppSpacing.pagePad, 0),
      padding: const EdgeInsets.all(AppSpacing.pagePad),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: corStatus.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, color: corStatus.withOpacity(0.12)),
            child: Icon(iconStatus, color: corStatus, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lista para $dias dias', style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text('R\$ $total', style: AppTextStyles.mono.copyWith(color: corStatus, fontSize: 22)),
                const SizedBox(height: 2),
                Text('Saldo envelope: R\$ $saldo', style: AppTextStyles.caption),
              ],
            ),
          ),
          if (totalItens > 0) ...[
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: marcados / totalItens,
                        backgroundColor: AppColors.bord,
                        valueColor: const AlwaysStoppedAnimation(AppColors.acc),
                        strokeWidth: 3,
                      ),
                      Text(
                        '$marcados',
                        style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700, color: AppColors.acc),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('/$totalItens', style: AppTextStyles.caption),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class CategoriaListaSection extends StatelessWidget {
  final String categoria;
  final List<Map<String, dynamic>> itens;
  final Set<String> checked;
  final ValueChanged<String> onToggle;

  const CategoriaListaSection({
    super.key,
    required this.categoria,
    required this.itens,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(color: AppColors.acc, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text(
                categoria,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.mu,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bord,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                ),
                child: Text('${itens.length}', style: AppTextStyles.caption),
              ),
            ],
          ),
        ),
        ...itens.map((item) {
          final nome = item['nome'] as String? ?? '';
          final key = '${categoria}_$nome';
          return ItemListaCard(
            item: item,
            isChecked: checked.contains(key),
            onToggle: () => onToggle(key),
          );
        }),
      ],
    );
  }
}
