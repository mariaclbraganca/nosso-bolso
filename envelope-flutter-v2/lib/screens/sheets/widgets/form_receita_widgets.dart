import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/moeda.dart';

const receitaOrigensList = [
  ('Salário', Icons.work_outline),
  ('Vale Alim.', Icons.restaurant_outlined),
  ('Freelance', Icons.laptop_outlined),
  ('Aluguel', Icons.home_outlined),
  ('Aporte', Icons.savings_outlined),
  ('Outros', Icons.more_horiz),
];

class ReceitaValorInput extends StatelessWidget {
  final TextEditingController controller;

  const ReceitaValorInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.grn.withOpacity(0.3), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'R\$',
            style: AppTextStyles.titleSm.copyWith(color: AppColors.grn.withOpacity(0.7)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [MoedaInputFormatter()],
              textAlign: TextAlign.center,
              style: AppTextStyles.mono.copyWith(
                fontSize: 44,
                color: AppColors.grn,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                filled: false,
                border: InputBorder.none,
                hintText: '0,00',
                hintStyle: AppTextStyles.mono.copyWith(
                  fontSize: 44,
                  color: AppColors.grn.withOpacity(0.3),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Informe o valor';
                final n = parseMoeda(v);
                if (n <= 0) return 'Valor inválido';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ReceitaOrigemChips extends StatelessWidget {
  final String origemSelecionada;
  final ValueChanged<String> onSelect;

  const ReceitaOrigemChips({
    super.key,
    required this.origemSelecionada,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: receitaOrigensList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, icon) = receitaOrigensList[i];
          final sel = origemSelecionada == label;
          return GestureDetector(
            onTap: () => onSelect(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: sel ? AppColors.grn.withOpacity(0.15) : AppColors.surf,
                borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                border: Border.all(
                  color: sel ? AppColors.grn : AppColors.bord,
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: sel ? AppColors.grn : AppColors.mu),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTextStyles.bodySm.copyWith(
                      color: sel ? AppColors.grn : AppColors.tx,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<void> perguntarDistribuirReceita(BuildContext context, Widget abastecerSheet) async {
  final resposta = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        side: const BorderSide(color: AppColors.bord, width: 0.5),
      ),
      title: Text('Distribuir nos envelopes?', style: AppTextStyles.titleSm),
      content: Text(
        'Deseja distribuir essa receita ou definir metas dos seus envelopes agora?',
        style: AppTextStyles.body.copyWith(color: AppColors.mu),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: Text('Depois', style: AppTextStyles.body.copyWith(color: AppColors.mu)),
        ),
        TextButton(
          onPressed: () => Navigator.of(c).pop(true),
          child: Text('Sim, agora', style: AppTextStyles.body.copyWith(color: AppColors.acc)),
        ),
      ],
    ),
  );

  if (resposta == true && context.mounted) {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => abastecerSheet,
    );
  }
}
