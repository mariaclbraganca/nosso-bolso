import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../utils/moeda.dart';

/// Card que exibe o resumo total planejado para o mês.
class AbastecerTotalCard extends StatelessWidget {
  final double total;

  const AbastecerTotalCard({super.key, required this.total});

  @override
  Widget build(BuildContext context) {
    final formatador = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.acc.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined, color: AppColors.acc, size: 20),
              const SizedBox(width: 8),
              Text(
                'Total planejado:',
                style: AppTextStyles.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.tx,
                ),
              ),
            ],
          ),
          Text(
            formatador.format(total),
            style: AppTextStyles.mono.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.acc,
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha para definir a meta de um envelope específico.
class AbastecerEnvelopeTile extends StatelessWidget {
  final String emoji;
  final String nome;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const AbastecerEnvelopeTile({
    super.key,
    required this.emoji,
    required this.nome,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final temValor = controller.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: const Border.fromBorderSide(
          BorderSide(color: AppColors.bord, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nome,
              style: AppTextStyles.bodySm,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 124,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: temValor ? AppColors.acc.withOpacity(0.6) : AppColors.bord,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [MoedaInputFormatter()],
              textAlign: TextAlign.right,
              style: AppTextStyles.mono.copyWith(
                fontSize: 16,
                color: AppColors.acc,
              ),
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '0,00',
                hintStyle: AppTextStyles.mono.copyWith(
                  fontSize: 16,
                  color: AppColors.mu,
                ),
                prefixText: 'R\$ ',
                prefixStyle: AppTextStyles.bodySm.copyWith(color: AppColors.acc),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
