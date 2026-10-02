import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Estado vazio quando não há compras pendentes
class ComprasEmptyState extends StatelessWidget {
  const ComprasEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bord,
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 38, color: AppColors.mu),
          ),
          const SizedBox(height: 16),
          Text('Nenhuma compra pendente', style: AppTextStyles.body.copyWith(color: AppColors.mu)),
          const SizedBox(height: 6),
          Text(
            'Escaneie ou cole a URL de uma NFC-e para começar',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Botão de ícone no cabeçalho com badge numérico opcional
class ComprasIconBtnBadge extends StatelessWidget {
  final IconData icon;
  final int? badge;
  final String tooltip;
  final VoidCallback onTap;

  const ComprasIconBtnBadge({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
                border: Border.all(color: AppColors.bord),
              ),
              child: Icon(icon, color: AppColors.mu, size: 20),
            ),
            if (badge != null && badge! > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
