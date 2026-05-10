import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

const _tipoIcons = {
  'cafe_da_manha': Icons.coffee_rounded,
  'lanche_manha': Icons.local_cafe_rounded,
  'almoco': Icons.restaurant_rounded,
  'lanche_tarde': Icons.cookie_rounded,
  'jantar': Icons.nightlight_round,
  'ceia': Icons.bedtime_rounded,
};

const _tipoLabels = {
  'cafe_da_manha': 'Café da Manhã',
  'lanche_manha': 'Lanche da Manhã',
  'almoco': 'Almoço',
  'lanche_tarde': 'Lanche da Tarde',
  'jantar': 'Jantar',
  'ceia': 'Ceia',
};

class RefeicaoCard extends StatelessWidget {
  final Map<String, dynamic> refeicao;
  final VoidCallback? onDelete;

  const RefeicaoCard({super.key, required this.refeicao, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final tipo = refeicao['tipo_refeicao'] as String? ?? 'almoco';
    final isCheat = refeicao['is_cheat_meal'] == true;
    final isJejum = refeicao['is_jejum'] == true;
    final macros = refeicao['macros_totais'] as Map<String, dynamic>? ?? {};
    final kcal = (macros['calorias_kcal'] as num?)?.toInt() ?? 0;
    final prot = (macros['proteina_g'] as num?)?.toInt() ?? 0;
    final carb = (macros['carboidrato_g'] as num?)?.toInt() ?? 0;
    final gord = (macros['gordura_g'] as num?)?.toInt() ?? 0;
    final descricao = refeicao['descricao'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surf,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _tipoIcons[tipo] ?? Icons.restaurant_rounded,
              color: AppColors.acc,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _tipoLabels[tipo] ?? tipo,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.tx,
                      ),
                    ),
                    if (isCheat) ...[
                      const SizedBox(width: 6),
                      const Text('🎉', style: TextStyle(fontSize: 13)),
                    ],
                    if (isJejum) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.pur.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Jejum',
                          style: TextStyle(fontSize: 9, color: AppColors.pur),
                        ),
                      ),
                    ],
                  ],
                ),
                if (descricao.isNotEmpty)
                  Text(
                    descricao,
                    style: const TextStyle(fontSize: 11, color: AppColors.mu),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (!isJejum)
                  Text(
                    '${kcal}kcal  P${prot}g  C${carb}g  G${gord}g',
                    style: const TextStyle(fontSize: 11, color: AppColors.mu),
                  ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: AppColors.mu),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ],
      ),
    );
  }
}
