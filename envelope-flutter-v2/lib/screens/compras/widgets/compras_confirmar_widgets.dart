import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';

/// Card com resumo do total da compra e contagem de itens
Widget buildResumoValorCompra(double valorTotal, List itens) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surf,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      border: Border.all(color: AppColors.bord, width: 0.5),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total da compra', style: AppTextStyles.caption),
            Text('R\$ ${valorTotal.toStringAsFixed(2)}',
                style: AppTextStyles.mono.copyWith(color: AppColors.acc, fontSize: 20)),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${itens.length} itens', style: AppTextStyles.caption),
            Text(
              'Média: R\$ ${itens.isNotEmpty ? (valorTotal / itens.length).toStringAsFixed(2) : '0.00'}',
              style: AppTextStyles.caption.copyWith(color: AppColors.mu),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Alerta visual caso a compra estoure o saldo disponível do envelope
Widget buildAlertaEstouroCompra(double diferenca) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.dred.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.dred.withOpacity(0.4)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.red, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'O envelope ficará negativo em R\$ ${diferenca.abs().toStringAsFixed(2)}. (NEGATIVE_OK)',
            style: const TextStyle(fontSize: 12, color: AppColors.tx),
          ),
        ),
      ],
    ),
  );
}

/// Dropdown de seleção de envelope para confirmação da despesa
Widget buildSeletorEnvelopeCompra({
  required AsyncValue<List<Map<String, dynamic>>> envelopesAsync,
  required String? envelopeIdSelecionado,
  required double valorTotal,
  required ValueChanged<String?> onChanged,
}) {
  return envelopesAsync.when(
    data: (envelopes) {
      if (envelopes.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surf,
            borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
            border: Border.all(color: AppColors.bord),
          ),
          child: Text('Nenhum envelope encontrado. Crie um envelope primeiro.', style: AppTextStyles.caption.copyWith(color: AppColors.mu)),
        );
      }
      return DropdownButtonFormField<String>(
        isExpanded: true,
        dropdownColor: AppColors.card,
        value: envelopeIdSelecionado,
        hint: Text('Selecionar envelope', style: AppTextStyles.body.copyWith(color: AppColors.mu)),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.surf,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusInput), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: envelopes.map((e) => DropdownMenuItem<String>(
          value: e['id'] as String,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(e['nome_envelope'] as String, style: AppTextStyles.body, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Text(
                'R\$ ${(e['saldo_atual'] as num).toStringAsFixed(2)}',
                style: AppTextStyles.monoSm.copyWith(
                  color: (e['saldo_atual'] as num) >= valorTotal ? AppColors.grn : AppColors.red,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        )).toList(),
        onChanged: onChanged,
      );
    },
    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acc)),
    error: (e, _) => Text('Erro: $e', style: AppTextStyles.body.copyWith(color: AppColors.red)),
  );
}
