import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/moeda.dart';

class GastoValorInput extends StatelessWidget {
  final TextEditingController controller;

  const GastoValorInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.red.withOpacity(0.3), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'R\$',
            style: AppTextStyles.titleSm.copyWith(color: AppColors.red.withOpacity(0.7)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              key: const Key('campo_valor'),
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [MoedaInputFormatter()],
              textAlign: TextAlign.center,
              style: AppTextStyles.mono.copyWith(
                fontSize: 44,
                color: AppColors.red,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                filled: false,
                border: InputBorder.none,
                hintText: '0,00',
                hintStyle: AppTextStyles.mono.copyWith(
                  fontSize: 44,
                  color: AppColors.red.withOpacity(0.3),
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

class GastoEnvelopeGrid extends StatelessWidget {
  final List<Map<String, dynamic>> envelopes;
  final String? envelopeSelecionadoId;
  final ValueChanged<String> onSelect;

  const GastoEnvelopeGrid({
    super.key,
    required this.envelopes,
    required this.envelopeSelecionadoId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (envelopes.isEmpty) {
      return Center(
        child: Text('Nenhum envelope encontrado', style: AppTextStyles.caption),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.2,
        crossAxisSpacing: AppSpacing.cardGap,
        mainAxisSpacing: AppSpacing.cardGap,
      ),
      itemCount: envelopes.length,
      itemBuilder: (context, index) {
        final env = envelopes[index];
        final id = env['id'] as String;
        final selecionado = envelopeSelecionadoId == id;
        final emoji = env['emoji'] as String? ?? '📦';
        final nome = env['nome_envelope'] as String? ?? '—';

        return GestureDetector(
          onTap: () => onSelect(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: selecionado ? AppColors.acc.withOpacity(0.12) : AppColors.surf,
              borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
              border: Border.all(
                color: selecionado ? AppColors.acc : AppColors.bord,
                width: selecionado ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    nome,
                    style: AppTextStyles.bodySm.copyWith(
                      color: selecionado ? AppColors.acc : AppColors.tx,
                      fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FormaPagamentoChips extends StatelessWidget {
  final String formaPagamento;
  final ValueChanged<String> onSelect;

  static const formas = [
    {'valor': 'credito', 'label': 'Crédito', 'emoji': '💳'},
    {'valor': 'pix', 'label': 'PIX', 'emoji': '⚡'},
    {'valor': 'debito', 'label': 'Débito', 'emoji': '🏦'},
    {'valor': 'dinheiro', 'label': 'Dinheiro', 'emoji': '💵'},
    {'valor': 'va', 'label': 'VA', 'emoji': '🍽️'},
  ];

  const FormaPagamentoChips({
    super.key,
    required this.formaPagamento,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: formas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final f = formas[i];
          final isSel = formaPagamento == f['valor'];
          return GestureDetector(
            onTap: () => onSelect(f['valor']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSel ? AppColors.acc.withOpacity(0.12) : AppColors.surf,
                borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                border: Border.all(
                  color: isSel ? AppColors.acc : AppColors.bord,
                  width: isSel ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(f['emoji']!, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    f['label']!,
                    style: AppTextStyles.bodySm.copyWith(
                      color: isSel ? AppColors.acc : AppColors.tx,
                      fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
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
