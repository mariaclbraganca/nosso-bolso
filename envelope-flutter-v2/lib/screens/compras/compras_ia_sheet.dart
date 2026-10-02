import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../providers/compras_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/api_service.dart';
import '../../services/nfce_scraper.dart';
import '../../services/gemini_nfce_service.dart';
import 'qr_scanner_screen.dart';
import 'widgets/compras_ia_helpers.dart';
import 'widgets/compras_url_dialog.dart';
import 'widgets/compras_ia_header.dart';
import 'widgets/compras_ia_header_cards.dart';
import 'widgets/compras_falhas_card.dart';
import 'widgets/compras_compra_card.dart';

/// Modal principal de Compras IA — 95% da tela.
class ComprasIASheet extends ConsumerStatefulWidget {
  const ComprasIASheet({super.key});

  @override
  ConsumerState<ComprasIASheet> createState() => _ComprasIASheetState();
}

class _ComprasIASheetState extends ConsumerState<ComprasIASheet> {
  bool _processando = false;
  String _statusMsg = '';
  bool _falhasColapsadas = true;

  Future<void> _abrirCamera() async {
    final url = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (url != null && url.isNotEmpty) {
      await _enviarIngestao(url);
    }
  }

  Future<void> _enviarIngestao(String qrUrl) async {
    final perfil = ref.read(perfilUsuarioLogadoProvider).asData?.value;
    if (perfil == null) return;
    final familiaId = perfil['familia_id'] as String? ?? '';

    setState(() { _processando = true; _statusMsg = 'Baixando dados da nota...'; });

    try {
      final textoLimpo = await NfceScraper.raspar(qrUrl);
      if (!mounted) return;
      setState(() => _statusMsg = 'Analisando nota com IA...');

      final extraido = await GeminiNfceService.extrairDaNota(textoLimpo);
      if (!mounted) return;
      setState(() => _statusMsg = 'Salvando compra...');

      final uri = Uri.parse('${ApiService.baseUrl}/api/v1/compras/salvar_extraido');
      final resp = await http.post(
        uri,
        headers: ApiService.authHeaders(json: true),
        body: jsonEncode(montarBodyIngestao(familiaId: familiaId, qrUrl: qrUrl, extraido: extraido)),
      );

      if (!mounted) return;
      if (resp.statusCode == 201) {
        ref.invalidate(comprasPendentesProvider);
        ref.invalidate(comprasFalhasProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Compra processada! Escolha o envelope abaixo.'),
          backgroundColor: AppColors.grn,
          duration: Duration(seconds: 4),
        ));
      } else {
        throw Exception('Backend: ${resp.statusCode} — ${resp.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.red,
          duration: const Duration(seconds: 6),
        ));
      }
    } finally {
      if (mounted) setState(() { _processando = false; _statusMsg = ''; });
    }
  }

  Future<void> _dispensarFalhas() async {
    final perfil = ref.read(perfilUsuarioLogadoProvider).asData?.value;
    final familiaId = perfil?['familia_id'] as String?;
    if (familiaId == null) return;
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/v1/compras/falhas').replace(queryParameters: {'familia_id': familiaId});
      await http.delete(uri, headers: ApiService.authHeaders()).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      ref.invalidate(comprasFalhasProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final comprasAsync = ref.watch(comprasPendentesProvider);
    final falhasAsync = ref.watch(comprasFalhasProvider);
    final feedbackAsync = ref.watch(feedbackPendenteProvider);
    final feedbackCount = feedbackAsync.asData?.value.length ?? 0;

    return Container(
      height: screenH * 0.95,
      decoration: const BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          ComprasIAHeader(
            feedbackCount: feedbackCount,
            processando: _processando,
            statusMsg: _statusMsg,
            onAbrirCamera: _abrirCamera,
            onMostrarDialogColarUrl: () => mostrarDialogColarUrl(context, onConfirmar: _enviarIngestao),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 0.5, color: AppColors.bord),
          const SizedBox(height: 4),
          Expanded(
            child: comprasAsync.when(
              data: (compras) => RefreshIndicator(
                color: AppColors.acc,
                backgroundColor: AppColors.card,
                onRefresh: () async {
                  ref.invalidate(comprasPendentesProvider);
                  ref.invalidate(comprasFalhasProvider);
                  ref.invalidate(feedbackPendenteProvider);
                },
                child: ListView(
                  padding: EdgeInsets.fromLTRB(AppSpacing.pagePad, AppSpacing.cardGap, AppSpacing.pagePad, MediaQuery.of(context).padding.bottom + 24),
                  children: [
                    falhasAsync.when(
                      data: (falhas) => falhas.isEmpty
                          ? const SizedBox.shrink()
                          : ComprasFalhasCard(
                              falhas: falhas,
                              colapsado: _falhasColapsadas,
                              onToggle: () => setState(() => _falhasColapsadas = !_falhasColapsadas),
                              onDispensar: _dispensarFalhas,
                            ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    if (compras.isEmpty)
                      const ComprasEmptyState()
                    else ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: AppSpacing.cardGap),
                        child: Row(
                          children: [
                            Container(width: 4, height: 14, decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 8),
                            Text('${compras.length} pendente${compras.length > 1 ? 's' : ''}', style: AppTextStyles.bodySm.copyWith(color: AppColors.mu, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      ...compras.map((c) => CompraCard(compra: c)),
                    ],
                  ],
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acc)),
              error: (e, _) => Center(child: Text('Erro: $e', style: AppTextStyles.body.copyWith(color: AppColors.red))),
            ),
          ),
        ],
      ),
    );
  }
}
