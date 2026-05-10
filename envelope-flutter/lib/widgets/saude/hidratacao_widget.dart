import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class HidratacaoWidget extends StatelessWidget {
  final int totalMl;
  final int metaMl;
  final VoidCallback onRegistrar;

  const HidratacaoWidget({
    super.key,
    required this.totalMl,
    required this.metaMl,
    required this.onRegistrar,
  });

  @override
  Widget build(BuildContext context) {
    final copos = metaMl > 0 ? (metaMl / 250).ceil() : 8;
    final coposCompletos = metaMl > 0 ? (totalMl / 250).floor().clamp(0, copos) : 0;
    final pct = metaMl > 0 ? (totalMl / metaMl).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.water_drop_rounded, color: AppColors.blu, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Hidratação — ${totalMl}ml / ${metaMl}ml',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.tx,
                    ),
                  ),
                ],
              ),
              Text(
                '${(pct * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: pct >= 0.8 ? AppColors.grn : AppColors.mu,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(copos, (i) {
              final cheio = i < coposCompletos;
              return GestureDetector(
                onTap: onRegistrar,
                child: Icon(
                  cheio ? Icons.local_drink_rounded : Icons.local_drink_outlined,
                  color: cheio ? AppColors.blu : AppColors.bord,
                  size: 22,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onRegistrar,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_circle_outline, color: AppColors.acc, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Registrar copo (250ml)',
                  style: const TextStyle(fontSize: 12, color: AppColors.acc),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
