import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/moeda.dart';

class RemanejarOrigemCard extends StatelessWidget {
  final String emoji;
  final String nome;
  final double saldo;

  const RemanejarOrigemCard({
    super.key,
    required this.emoji,
    required this.nome,
    required this.saldo,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('R\$ #,##0.00', 'pt_BR');
    final semSaldo = saldo <= 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: semSaldo ? AppColors.dred.withOpacity(0.12) : AppColors.gold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(
          color: semSaldo ? AppColors.red.withOpacity(0.3) : AppColors.gold.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Origem: $nome',
                  style: AppTextStyles.bodySm.copyWith(
                    color: semSaldo ? AppColors.red : AppColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Saldo disponível: ${fmt.format(saldo)}',
                  style: AppTextStyles.monoSm.copyWith(
                    color: semSaldo ? AppColors.red : AppColors.mu,
                    fontSize: 13,
                  ),
                ),
                if (semSaldo) ...[
                  const SizedBox(height: 4),
                  Text(
                    '⚠️ Não há saldo positivo neste envelope para transferir.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.red),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RemanejarDestinoSelector extends StatelessWidget {
  final List<Map<String, dynamic>> destinos;
  final String? destinoId;
  final ValueChanged<String?> onChanged;

  const RemanejarDestinoSelector({
    super.key,
    required this.destinos,
    required this.destinoId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
        border: const Border.fromBorderSide(BorderSide(color: AppColors.bord)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: destinoId,
          isExpanded: true,
          dropdownColor: AppColors.surf,
          hint: Text(
            'Selecione o envelope destino',
            style: AppTextStyles.body.copyWith(color: AppColors.mu),
          ),
          style: AppTextStyles.body,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mu),
          items: destinos.map((env) {
            final id = env['id'] as String;
            final emoji = env['emoji'] as String? ?? '📦';
            final nome = env['nome_envelope'] as String? ?? '—';
            return DropdownMenuItem(
              value: id,
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(nome, style: AppTextStyles.body),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class RemanejarValorInput extends StatelessWidget {
  final TextEditingController controller;
  final double saldoOrigem;

  const RemanejarValorInput({
    super.key,
    required this.controller,
    required this.saldoOrigem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.gold.withOpacity(0.3), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Text(
            'R\$',
            style: AppTextStyles.titleSm.copyWith(color: AppColors.gold.withOpacity(0.7)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [MoedaInputFormatter()],
              textAlign: TextAlign.center,
              style: AppTextStyles.mono.copyWith(
                fontSize: 44,
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                filled: false,
                border: InputBorder.none,
                hintText: '0,00',
                hintStyle: AppTextStyles.mono.copyWith(
                  fontSize: 44,
                  color: AppColors.gold.withOpacity(0.3),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Informe o valor';
                final n = parseMoeda(v);
                if (n <= 0) return 'Valor inválido';
                if (n > saldoOrigem) return 'Excede o saldo disponível';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}
