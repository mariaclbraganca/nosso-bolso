import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../theme/app_theme.dart';
import '../../../providers/compras_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/nfce_scraper.dart';
import '../../../services/gemini_nfce_service.dart';
import '../qr_scanner_screen.dart';
import 'compras_ia_helpers.dart';

/// Executa o fluxo de vincular um cupom escaneado a uma compra existente
Future<void> escanearCupomParaCompra(
  BuildContext context,
  WidgetRef ref,
  String compraId,
  String familiaId,
) async {
  final url = await Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => const QrScannerScreen()),
  );
  if (url == null || url.isEmpty || !context.mounted) return;

  try {
    final textoLimpo = await NfceScraper.raspar(url);
    final extraido = await GeminiNfceService.extrairDaNota(textoLimpo);

    final uri = Uri.parse('${ApiService.baseUrl}/api/v1/compras/salvar_extraido');
    final resp = await http.post(
      uri,
      headers: ApiService.authHeaders(json: true),
      body: jsonEncode(montarBodyIngestao(
        familiaId: familiaId,
        qrUrl: url,
        extraido: extraido,
        compraIdVinculo: compraId,
      )),
    );

    if (!context.mounted) return;
    if (resp.statusCode == 201) {
      ref.invalidate(comprasPendentesProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cupom vinculado! Itens adicionados à compra.'),
        backgroundColor: AppColors.grn,
        duration: Duration(seconds: 4),
      ));
    } else {
      throw Exception('Backend: ${resp.statusCode} — ${resp.body}');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erro ao processar cupom: $e'),
        backgroundColor: AppColors.red,
        duration: const Duration(seconds: 6),
      ));
    }
  }
}

/// Diálogo de confirmação para rejeitar e excluir permanentemente uma compra
Future<void> rejeitarCompraDialog(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> compra,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
      title: Text('Rejeitar compra?', style: AppTextStyles.titleSm),
      content: Text(
        'A compra de "${compra['supermercado']}" será removida permanentemente.',
        style: AppTextStyles.body.copyWith(color: AppColors.mu),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: AppTextStyles.body.copyWith(color: AppColors.mu))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Rejeitar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  if (confirm != true) return;
  try {
    final uri = Uri.parse('${ApiService.baseUrl}/api/v1/compras/${compra['compra_id']}');
    final resp = await http.delete(uri, headers: ApiService.authHeaders());
    if (resp.statusCode == 200) ref.invalidate(comprasPendentesProvider);
  } catch (_) {}
}
