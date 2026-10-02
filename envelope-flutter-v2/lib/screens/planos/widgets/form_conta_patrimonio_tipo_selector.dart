import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/moeda.dart';

const List<(String, String, String)> tiposDeConta = [
  ('conta_corrente', 'Conta corrente', '🏦'),
  ('poupanca', 'Poupança', '🐷'),
  ('investimento', 'Investimento', '📈'),
  ('caixinha', 'Caixinha', '📦'),
  ('carteira', 'Carteira física', '👛'),
];

/// Seletor horizontal com ícones para o tipo de conta bancária ou investimento
class ContaTipoSelector extends StatelessWidget {
  final String tipoSelecionado;
  final void Function(String tipo, String emoji) onSelect;

  const ContaTipoSelector({
    super.key,
    required this.tipoSelecionado,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: tiposDeConta.map((t) {
          final sel = t.$1 == tipoSelecionado;
          return GestureDetector(
            onTap: () => onSelect(t.$1, t.$3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? AppColors.acc.withOpacity(0.15) : AppColors.surf,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel ? AppColors.acc : AppColors.bord,
                  width: sel ? 1.5 : 0.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(t.$3, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(
                    t.$2,
                    style: AppTextStyles.caption.copyWith(
                      color: sel ? AppColors.acc : AppColors.mu,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Campo de texto com estilização padrão do formulário de patrimônio
class ContaCampoInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final TextInputType keyboard;
  final bool isMoeda;

  const ContaCampoInput({
    super.key,
    required this.ctrl,
    required this.label,
    required this.hint,
    this.keyboard = TextInputType.text,
    this.isMoeda = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      inputFormatters: isMoeda ? [MoedaInputFormatter()] : null,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.mu),
        labelStyle: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
        filled: true,
        fillColor: AppColors.surf,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
