import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../feedback_compras_screen.dart';
import '../lista_compras_screen.dart';
import 'compras_ia_header_cards.dart';

/// Cabeçalho superior de Compras IA com título, badges e botões de escaneamento
class ComprasIAHeader extends StatelessWidget {
  final int feedbackCount;
  final bool processando;
  final String statusMsg;
  final VoidCallback onAbrirCamera;
  final VoidCallback onMostrarDialogColarUrl;

  const ComprasIAHeader({
    super.key,
    required this.feedbackCount,
    required this.processando,
    required this.statusMsg,
    required this.onAbrirCamera,
    required this.onMostrarDialogColarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePad),
      child: Column(
        children: [
          Row(
            children: [
              Text('Compras IA', style: AppTextStyles.title),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                  border: Border.all(color: AppColors.gold.withOpacity(0.35)),
                ),
                child: Text('IA', style: AppTextStyles.caption.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              ComprasIconBtnBadge(
                icon: Icons.rate_review_outlined,
                badge: feedbackCount,
                tooltip: 'Feedback pendente',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackComprasScreen())),
              ),
              const SizedBox(width: 4),
              ComprasIconBtnBadge(
                icon: Icons.format_list_bulleted_rounded,
                tooltip: 'Lista Inteligente',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ListaComprasScreen())),
              ),
              const SizedBox(width: 4),
              ComprasIconBtnBadge(
                icon: Icons.close_rounded,
                tooltip: 'Fechar',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.black, size: 22),
                    label: const Text('Escanear NFC-e', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.acc,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                    ),
                    onPressed: processando ? null : onAbrirCamera,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.cardGap),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.link_rounded, color: AppColors.acc, size: 20),
                  label: const Text('URL', style: TextStyle(color: AppColors.acc, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.card,
                    side: const BorderSide(color: AppColors.acc, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: processando ? null : onMostrarDialogColarUrl,
                ),
              ),
            ],
          ),
          if (processando) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.acc.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                border: Border.all(color: AppColors.acc.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.acc, strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text(statusMsg, style: AppTextStyles.bodySm.copyWith(color: AppColors.acc)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
