import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Exibe o diálogo para o usuário colar manualmente a URL da NFC-e
Future<void> mostrarDialogColarUrl(
  BuildContext context, {
  required Future<void> Function(String url) onConfirmar,
}) async {
  final controller = TextEditingController();
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
      title: Row(
        children: [
          const Icon(Icons.link_rounded, color: AppColors.acc, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('Colar URL da NFC-e', style: AppTextStyles.titleSm, overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cole o link da nota fiscal eletrônica (NFC-e / SEFAZ):', style: AppTextStyles.caption),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: 'https://nfce.sefaz...',
              hintStyle: AppTextStyles.body.copyWith(color: AppColors.mu),
              filled: true,
              fillColor: AppColors.surf,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusInput), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusInput), borderSide: const BorderSide(color: AppColors.acc)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: AppTextStyles.body.copyWith(color: AppColors.mu))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.acc,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
          ),
          onPressed: () async {
            final url = controller.text.trim();
            if (url.isEmpty) return;
            Navigator.pop(ctx);
            await onConfirmar(url);
          },
          child: Text('Processar', style: AppTextStyles.body.copyWith(color: Colors.black, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}
