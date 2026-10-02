import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class FeedbackItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final double offsetX;

  const FeedbackItemCard({super.key, required this.item, required this.offsetX});

  @override
  Widget build(BuildContext context) {
    final swipeGreen = offsetX > 40 ? (AppColors.acc.withOpacity(0.18)) : Colors.transparent;
    final swipeRed = offsetX < -40 ? (AppColors.red.withOpacity(0.18)) : Colors.transparent;
    final swipeColor = offsetX > 40 ? swipeGreen : swipeRed;

    final labelSwipe = offsetX > 40 ? 'ACABOU' : (offsetX < -40 ? 'ESTRAGOU' : null);
    final labelColor = offsetX > 40 ? AppColors.acc : AppColors.red;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Stack(
        children: [
          if (swipeColor != Colors.transparent)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: swipeColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                ),
              ),
            ),
          if (labelSwipe != null)
            Positioned(
              top: 24,
              left: offsetX > 40 ? null : 24,
              right: offsetX > 40 ? 24 : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: labelColor, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  labelSwipe,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.acc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                  ),
                  child: Text(
                    item['categoria'] ?? 'Outros',
                    style: AppTextStyles.caption.copyWith(color: AppColors.acc),
                  ),
                ),
                const SizedBox(height: 24),
                Text(item['nome_padronizado'] ?? '', style: AppTextStyles.display),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Comprado em',
                  value: _formatDate(item['data_compra'] as String? ?? ''),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.event_available_outlined,
                  label: 'Prazo estimado',
                  value: _formatDate(item['data_feedback_estimada'] as String? ?? ''),
                  valueColor: AppColors.org,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: AppColors.red),
                        const SizedBox(width: 4),
                        Text('Estragou', style: AppTextStyles.caption.copyWith(color: AppColors.red)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Acabou', style: AppTextStyles.caption.copyWith(color: AppColors.acc)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.acc),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    if (raw.length < 10) return raw;
    final parts = raw.substring(0, 10).split('-');
    if (parts.length < 3) return raw;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.mu),
        const SizedBox(width: 6),
        Text('$label: ', style: AppTextStyles.caption),
        Text(value, style: AppTextStyles.bodySm.copyWith(color: valueColor ?? AppColors.tx)),
      ],
    );
  }
}

class FeedbackActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const FeedbackActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
                color: color.withOpacity(0.08),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
