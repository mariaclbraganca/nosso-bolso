import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import 'form_conta_patrimonio_sheet.dart';

/// Card para exibição de uma conta ou investimento do patrimônio
class ContaCard extends StatelessWidget {
  final Map<String, dynamic> conta;
  const ContaCard({super.key, required this.conta});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final saldo = (conta['saldo_atual'] as num?)?.toDouble() ?? 0.0;
    final nome = conta['nome'] as String? ?? '';
    final banco = conta['banco'] as String? ?? '';
    final tipo = conta['tipo'] as String? ?? 'conta_corrente';
    final emoji = conta['emoji'] as String? ?? '🏦';
    final rendimento = (conta['rendimento_mensal'] as num?)?.toDouble();
    final meta = (conta['meta_saldo'] as num?)?.toDouble();

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FormContaPatrimonioSheet(conta: conta),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.surf,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nome, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (banco.isNotEmpty) ...[
                      Text(banco, style: AppTextStyles.caption),
                      const SizedBox(width: 6),
                      Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.mu, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                    ],
                    Text(_labelTipo(tipo), style: AppTextStyles.caption),
                    if (rendimento != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.grn.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${rendimento.toStringAsFixed(2)}% a.m.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.grn, fontSize: 9),
                        ),
                      ),
                    ],
                  ]),
                  if (meta != null && meta > 0) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (saldo / meta).clamp(0.0, 1.0),
                        backgroundColor: AppColors.bord,
                        color: AppColors.acc,
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Meta: ${fmt.format(meta)}',
                      style: AppTextStyles.caption.copyWith(fontSize: 9),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              fmt.format(saldo),
              style: AppTextStyles.mono.copyWith(
                color: saldo >= 0 ? AppColors.tx : AppColors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelTipo(String tipo) {
    switch (tipo) {
      case 'poupanca': return 'Poupança';
      case 'investimento': return 'Investimento';
      case 'caixinha': return 'Caixinha';
      case 'carteira': return 'Carteira';
      default: return 'Conta corrente';
    }
  }
}
