import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Card recolhível com resumo de notas fiscais que falharam
class ComprasFalhasCard extends StatelessWidget {
  final List<Map<String, dynamic>> falhas;
  final bool colapsado;
  final VoidCallback onToggle;
  final VoidCallback onDispensar;

  const ComprasFalhasCard({
    super.key,
    required this.falhas,
    required this.colapsado,
    required this.onToggle,
    required this.onDispensar,
  });

  @override
  Widget build(BuildContext context) {
    final primeira = falhas.first;
    final erro = (primeira['erro'] as String?) ?? 'Erro desconhecido';
    final categoria = (primeira['erro_categoria'] as String?) ?? 'outro';

    String dica;
    switch (categoria) {
      case 'sefaz':
        dica = 'O portal da SEFAZ está instável. Tente novamente em alguns minutos.';
        break;
      case 'ia':
        dica = 'Erro no Gemini (cota ou chave). Verifique em Configurações de IA.';
        break;
      default:
        dica = 'Tente novamente. Se persistir, verifique sua conexão.';
    }

    final erroResumo = erro.length > 120 ? '${erro.substring(0, 120)}…' : erro;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      decoration: BoxDecoration(
        color: AppColors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.red.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${falhas.length} nota${falhas.length > 1 ? 's' : ''} falharam no processamento',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.red),
                    ),
                  ),
                  Icon(
                    colapsado ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                    color: AppColors.red,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (!colapsado)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: AppColors.red, thickness: 0.2),
                  const SizedBox(height: 10),
                  Text(erroResumo, style: AppTextStyles.caption.copyWith(color: AppColors.mu)),
                  const SizedBox(height: 6),
                  Text(dica, style: AppTextStyles.caption.copyWith(color: AppColors.mu, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onDispensar,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        backgroundColor: AppColors.red.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                      ),
                      child: Text('Dispensar', style: AppTextStyles.caption.copyWith(color: AppColors.red, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
