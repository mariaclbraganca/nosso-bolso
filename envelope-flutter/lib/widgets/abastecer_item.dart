import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class AbastecerItem extends StatelessWidget {
  final Map<String, dynamic> envelope;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const AbastecerItem({
    super.key,
    required this.envelope,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final saldo = (envelope['saldo_atual'] as num).toDouble();
    final plan = (envelope['valor_planejado'] as num).toDouble();
    final diff = plan - saldo;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text(envelope['emoji'] ?? '📦', style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(envelope['nome_envelope'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  diff > 0 
                    ? 'Falta ${NumberFormat.simpleCurrency(locale: "pt_BR").format(diff)}' 
                    : '✓ Meta atingida', 
                  style: TextStyle(
                    fontSize: 11, 
                    color: diff > 0 ? AppColors.org : AppColors.grn, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            height: 40,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.acc),
              decoration: InputDecoration(
                hintText: '0,00',
                hintStyle: const TextStyle(color: AppColors.mu, fontWeight: FontWeight.normal),
                filled: true,
                fillColor: AppColors.surf,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), 
                  borderSide: const BorderSide(color: AppColors.bord)
                ),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}
