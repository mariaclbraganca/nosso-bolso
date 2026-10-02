import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Card para um item individual da lista de compras inteligente
class ItemListaCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isChecked;
  final VoidCallback onToggle;

  const ItemListaCard({
    super.key,
    required this.item,
    required this.isChecked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final corte = item['corte_sugerido'] as bool? ?? false;
    final nome = item['nome'] as String? ?? '';
    final qtd = item['quantidade_sugerida'];
    final unidade = item['unidade'] as String? ?? 'un';
    final preco = item['preco_estimado'] as num? ?? 0;
    final motivo = item['motivo'] as String? ?? '';

    return Opacity(
      opacity: corte ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.itemGap),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isChecked ? AppColors.acc.withOpacity(0.06) : AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 4),
            border: Border.all(
              color: isChecked
                  ? AppColors.acc.withOpacity(0.3)
                  : corte
                      ? AppColors.red.withOpacity(0.2)
                      : AppColors.bord,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isChecked ? AppColors.acc : Colors.transparent,
                  border: Border.all(
                    color: isChecked ? AppColors.acc : AppColors.bord,
                    width: 1.5,
                  ),
                ),
                child: isChecked
                    ? const Icon(Icons.check_rounded, color: Colors.black, size: 14)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      style: AppTextStyles.body.copyWith(
                        decoration: corte || isChecked ? TextDecoration.lineThrough : null,
                        color: isChecked
                            ? AppColors.mu
                            : corte
                                ? AppColors.mu
                                : AppColors.tx,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$qtd $unidade${motivo.isNotEmpty ? ' · $motivo' : ''}',
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R\$ ${preco.toStringAsFixed(2)}',
                    style: AppTextStyles.monoSm.copyWith(
                      color: isChecked
                          ? AppColors.mu
                          : corte
                              ? AppColors.red
                              : AppColors.acc,
                      fontSize: 13,
                    ),
                  ),
                  if (corte)
                    Text('Corte sugerido',
                        style: AppTextStyles.caption.copyWith(color: AppColors.red)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
