import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class MacroBar extends StatelessWidget {
  final String label;
  final double consumido;
  final double meta;
  final Color color;

  const MacroBar({
    super.key,
    required this.label,
    required this.consumido,
    required this.meta,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = meta > 0 ? (consumido / meta).clamp(0.0, 1.0) : 0.0;
    final isOver = consumido > meta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.mu)),
            Text(
              '${consumido.toInt()}g / ${meta.toInt()}g',
              style: TextStyle(
                fontSize: 11,
                color: isOver ? AppColors.red : AppColors.mu,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: AppColors.bord,
            valueColor: AlwaysStoppedAnimation<Color>(
              isOver ? AppColors.red : color,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
