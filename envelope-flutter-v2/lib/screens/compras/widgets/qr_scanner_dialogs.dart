import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

Future<bool> confirmarEnvioGenerico(BuildContext context, String raw) async {
  final aceitar = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        side: const BorderSide(color: AppColors.bord),
      ),
      title: Text('Código não reconhecido como NFC-e', style: AppTextStyles.titleSm),
      content: Text(
        'O link lido pode não ser uma nota fiscal:\n\n"$raw"\n\nDeseja tentar processá-lo mesmo assim?',
        style: AppTextStyles.caption.copyWith(color: AppColors.mu),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: Text('Cancelar', style: AppTextStyles.body.copyWith(color: AppColors.mu)),
        ),
        TextButton(
          onPressed: () => Navigator.of(c).pop(true),
          child: Text('Tentar assim mesmo', style: AppTextStyles.body.copyWith(color: AppColors.acc)),
        ),
      ],
    ),
  );
  return aceitar == true;
}

Future<String?> abrirDialogDigitarManualmente(BuildContext context) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        side: const BorderSide(color: AppColors.bord),
      ),
      title: Text('Digitar Chave ou Link 📝', style: AppTextStyles.titleSm),
      content: TextField(
        controller: ctrl,
        style: AppTextStyles.body,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Cole o link do QR code ou digite a chave de acesso da nota...',
          hintStyle: AppTextStyles.caption.copyWith(color: AppColors.mu),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(null),
          child: Text('Cancelar', style: AppTextStyles.body.copyWith(color: AppColors.mu)),
        ),
        ElevatedButton(
          onPressed: () {
            final texto = ctrl.text.trim();
            if (texto.isNotEmpty) Navigator.of(c).pop(texto);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.acc),
          child: Text('Processar', style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
