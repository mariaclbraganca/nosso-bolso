import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../providers/compras_provider.dart';
import '../../providers/envelopes_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/api_service.dart';
import '../../services/nfce_scraper.dart';
import '../../services/gemini_nfce_service.dart';
import 'qr_scanner_screen.dart';
import 'feedback_compras_screen.dart';
import 'lista_compras_screen.dart';

/// Modal principal de Compras IA.
/// Aberto via showModalBottomSheet(isScrollControlled: true) — 95% da tela.
class ComprasIASheet extends ConsumerStatefulWidget {
  const ComprasIASheet({super.key});

  @override
  ConsumerState<ComprasIASheet> createState() => _ComprasIASheetState();
}

class _ComprasIASheetState extends ConsumerState<ComprasIASheet> {
  bool _processando = false;
  String _statusMsg = '';
  bool _falhasColapsadas = true;

  // ─── Categorias ──────────────────────────────────────────────────────────────
  String _mapearCategoria(String cat) {
    const mapa = {
      'ALIMENTACAO': 'Outros',
      'LIMPEZA': 'Limpeza',
      'HIGIENE': 'Higiene Pessoal',
      'BEBIDAS': 'Bebidas',
      'OUTROS': 'Outros',
      'Proteínas': 'Proteínas',
      'Carboidratos': 'Carboidratos',
      'Hortifrúti': 'Hortifrúti',
      'Laticínios': 'Laticínios',
      'Padaria': 'Padaria',
      'Bebidas': 'Bebidas',
      'Lanches': 'Lanches',
      'Temperos e Condimentos': 'Temperos e Condimentos',
      'Limpeza': 'Limpeza',
      'Higiene Pessoal': 'Higiene Pessoal',
      'Congelados': 'Congelados',
      'Grãos e Cereais': 'Grãos e Cereais',
      'Outros': 'Outros',
    };
    return mapa[cat] ?? 'Outros';
  }

  // ─── Fluxo principal ──────────────────────────────────────────────────────────

  Future<void> _abrirCamera() async {
    final url = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (url != null && url.isNotEmpty) {
      await _enviarIngestao(url);
    }
  }

  Future<void> _mostrarDialogColarUrl() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
        title: Row(
          children: [
            const Icon(Icons.link_rounded, color: AppColors.acc, size: 20),
            const SizedBox(width: 10),
            Text('Colar URL da NFC-e',
                style: AppTextStyles.titleSm),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cole o link da nota fiscal eletrônica (NFC-e / SEFAZ):',
              style: AppTextStyles.caption,
            ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                  borderSide: const BorderSide(color: AppColors.acc),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: AppTextStyles.body.copyWith(color: AppColors.mu)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.acc,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusBtn)),
            ),
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isEmpty) return;
              Navigator.pop(ctx);
              await _enviarIngestao(url);
            },
            child: Text('Processar',
                style: AppTextStyles.body
                    .copyWith(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _enviarIngestao(String qrUrl) async {
    final perfil = ref.read(perfilUsuarioLogadoProvider).asData?.value;
    if (perfil == null) return;
    final familiaId = perfil['familia_id'] as String? ?? '';

    setState(() {
      _processando = true;
      _statusMsg = 'Baixando dados da nota...';
    });

    try {
      // Passo 1: Scraping da nota
      String textoLimpo;
      try {
        textoLimpo = await NfceScraper.raspar(qrUrl);
      } catch (e) {
        throw Exception('Erro ao baixar nota: $e');
      }

      if (!mounted) return;
      setState(() => _statusMsg = 'Analisando nota com IA...');

      // Passo 2: Extração com Gemini
      Map<String, dynamic> extraido;
      try {
        extraido = await GeminiNfceService.extrairDaNota(textoLimpo);
      } on GeminiNfceException catch (e) {
        throw Exception(e.message);
      }

      if (!mounted) return;
      setState(() => _statusMsg = 'Salvando compra...');

      // Passo 3: Envio ao backend
      final uri =
          Uri.parse('${ApiService.baseUrl}/api/v1/compras/salvar_extraido');
      final resp = await http.post(
        uri,
        headers: ApiService.authHeaders(json: true),
        body: jsonEncode({
          'familia_id': familiaId,
          'qr_code_url': qrUrl,
          'supermercado': extraido['supermercado'] ?? 'Desconhecido',
          'data_compra': extraido['data_compra'] ??
              DateTime.now().toIso8601String().substring(0, 10),
          'valor_total':
              (extraido['valor_total'] ?? 0.0).toDouble(),
          'itens': (extraido['itens'] as List? ?? [])
              .map((item) => {
                    'nome_original': item['nome_original'] ??
                        item['nome_padronizado'] ??
                        '',
                    'nome_padronizado': item['nome_padronizado'] ??
                        item['nome_original'] ??
                        '',
                    'categoria': _mapearCategoria(
                        item['categoria'] as String? ?? ''),
                    'quantidade':
                        (item['quantidade'] ?? 1).toDouble(),
                    'unidade': item['unidade'] ?? 'un',
                    'valor_unitario':
                        (item['valor_unitario'] ?? 0.0).toDouble(),
                    'valor_total_item':
                        (item['valor_total_item'] ?? 0.0).toDouble(),
                  })
              .toList(),
        }),
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
      if (mounted) {
        setState(() {
          _processando = false;
          _statusMsg = '';
        });
      }
    }
  }

  Future<void> _dispensarFalhas() async {
    final perfil = ref.read(perfilUsuarioLogadoProvider).asData?.value;
    final familiaId = perfil?['familia_id'] as String?;
    if (familiaId == null) return;
    try {
      final uri =
          Uri.parse('${ApiService.baseUrl}/api/v1/compras/falhas')
              .replace(queryParameters: {'familia_id': familiaId});
      await http.delete(uri, headers: ApiService.authHeaders())
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      ref.invalidate(comprasFalhasProvider);
    } catch (_) {}
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final comprasAsync = ref.watch(comprasPendentesProvider);
    final falhasAsync = ref.watch(comprasFalhasProvider);
    final feedbackAsync = ref.watch(feedbackPendenteProvider);

    final feedbackCount =
        feedbackAsync.asData?.value.length ?? 0;

    return Container(
      height: screenH * 0.95,
      decoration: const BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Handle ───────────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.bord,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // ── Header fixo ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePad),
            child: Column(
              children: [
                // Linha: título + ações
                Row(
                  children: [
                    Text('Compras IA', style: AppTextStyles.title),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(
                            AppSpacing.radiusChip),
                        border: Border.all(
                            color: AppColors.gold.withOpacity(0.35)),
                      ),
                      child: Text(
                        'IA',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),

                    // Feedback (com badge)
                    _IconBtnBadge(
                      icon: Icons.rate_review_outlined,
                      badge: feedbackCount,
                      tooltip: 'Feedback pendente',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FeedbackComprasScreen()),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Lista inteligente
                    _IconBtnBadge(
                      icon: Icons.format_list_bulleted_rounded,
                      tooltip: 'Lista Inteligente',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ListaComprasScreen()),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Fechar
                    _IconBtnBadge(
                      icon: Icons.close_rounded,
                      tooltip: 'Fechar',
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Botões de scan ─────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.qr_code_scanner_rounded,
                              color: Colors.black, size: 22),
                          label: const Text(
                            'Escanear NFC-e',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.acc,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusBtn),
                            ),
                          ),
                          onPressed: _processando ? null : _abrirCamera,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.cardGap),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.link_rounded,
                            color: AppColors.acc, size: 20),
                        label: const Text(
                          'URL',
                          style: TextStyle(
                              color: AppColors.acc,
                              fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.card,
                          side: const BorderSide(
                              color: AppColors.acc, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusBtn),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                        ),
                        onPressed:
                            _processando ? null : _mostrarDialogColarUrl,
                      ),
                    ),
                  ],
                ),

                // ── Loading overlay ────────────────────────────────────────────
                if (_processando) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.acc.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(
                          AppSpacing.radiusBtn),
                      border: Border.all(
                          color: AppColors.acc.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: AppColors.acc,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _statusMsg,
                          style: AppTextStyles.bodySm
                              .copyWith(color: AppColors.acc),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 0.5, color: AppColors.bord),
          const SizedBox(height: 4),

          // ── Conteúdo rolável ──────────────────────────────────────────────────
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
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.pagePad,
                    AppSpacing.cardGap,
                    AppSpacing.pagePad,
                    MediaQuery.of(context).padding.bottom + 24,
                  ),
                  children: [
                    // Seção de falhas
                    falhasAsync.when(
                      data: (falhas) => falhas.isEmpty
                          ? const SizedBox.shrink()
                          : _FalhasCard(
                              falhas: falhas,
                              colapsado: _falhasColapsadas,
                              onToggle: () => setState(() =>
                                  _falhasColapsadas = !_falhasColapsadas),
                              onDispensar: _dispensarFalhas,
                            ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    // Estado vazio
                    if (compras.isEmpty)
                      _EmptyState()
                    else ...[
                      // Header da seção pendentes
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 8, bottom: AppSpacing.cardGap),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${compras.length} pendente${compras.length > 1 ? 's' : ''}',
                              style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.mu,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),

                      // Cards de compra
                      ...compras.map((c) => _CompraCard(compra: c)),
                    ],
                  ],
                ),
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.acc),
              ),
              error: (e, _) => Center(
                child: Text('Erro: $e',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.red)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bord,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 38, color: AppColors.mu),
          ),
          const SizedBox(height: 16),
          Text('Nenhuma compra pendente',
              style: AppTextStyles.body.copyWith(color: AppColors.mu)),
          const SizedBox(height: 6),
          Text(
            'Escaneie ou cole a URL de uma NFC-e para começar',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Card de falhas ───────────────────────────────────────────────────────────

class _FalhasCard extends StatelessWidget {
  final List<Map<String, dynamic>> falhas;
  final bool colapsado;
  final VoidCallback onToggle;
  final VoidCallback onDispensar;

  const _FalhasCard({
    required this.falhas,
    required this.colapsado,
    required this.onToggle,
    required this.onDispensar,
  });

  @override
  Widget build(BuildContext context) {
    final primeira = falhas.first;
    final erro = (primeira['erro'] as String?) ?? 'Erro desconhecido';
    final categoria =
        (primeira['erro_categoria'] as String?) ?? 'outro';

    String dica;
    switch (categoria) {
      case 'sefaz':
        dica =
            'O portal da SEFAZ está instável. Tente novamente em alguns minutos.';
        break;
      case 'ia':
        dica = 'Erro no Gemini (cota ou chave). Verifique em Configurações de IA.';
        break;
      default:
        dica = 'Tente novamente. Se persistir, verifique sua conexão.';
    }

    final erroResumo =
        erro.length > 120 ? '${erro.substring(0, 120)}…' : erro;

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
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${falhas.length} nota${falhas.length > 1 ? 's' : ''} falharam no processamento',
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.red),
                    ),
                  ),
                  Icon(
                    colapsado
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: AppColors.red,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (!colapsado)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(
                      height: 1,
                      color: AppColors.red,
                      thickness: 0.2),
                  const SizedBox(height: 10),
                  Text(erroResumo,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.mu)),
                  const SizedBox(height: 6),
                  Text(dica,
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.mu,
                          fontStyle: FontStyle.italic)),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onDispensar,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        backgroundColor: AppColors.red.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusBtn),
                        ),
                      ),
                      child: Text('Dispensar',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.red,
                              fontWeight: FontWeight.w600)),
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

// ─── Card de compra ───────────────────────────────────────────────────────────

class _CompraCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> compra;
  const _CompraCard({required this.compra});

  @override
  ConsumerState<_CompraCard> createState() => _CompraCardState();
}

class _CompraCardState extends ConsumerState<_CompraCard> {
  bool _expandido = false;

  String _formatDate(String raw) {
    if (raw.length < 10) return raw;
    final p = raw.substring(0, 10).split('-');
    if (p.length < 3) return raw;
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final compra = widget.compra;
    final itens = (compra['itens'] as List?) ?? [];
    final supermercado =
        compra['supermercado'] as String? ?? 'Supermercado';
    final valorTotal = (compra['valor_total'] as num?)?.toDouble() ?? 0.0;
    final dataCompra =
        _formatDate(compra['data_compra'] as String? ?? '');

    // Agrupar itens por categoria
    final Map<String, List<Map<String, dynamic>>> porCategoria = {};
    for (final item in itens) {
      final cat = item['categoria'] as String? ?? 'Outros';
      porCategoria.putIfAbsent(cat, () => []).add(
          Map<String, dynamic>.from(item as Map));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord),
      ),
      child: Column(
        children: [
          // Header do card (toque para expandir)
          InkWell(
            onTap: () => setState(() => _expandido = !_expandido),
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.pagePad),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Ícone de loja
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: (compra['fonte'] == 'ifood'
                                  ? AppColors.red
                                  : AppColors.gold)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm + 4),
                        ),
                        child: compra['fonte'] == 'ifood'
                            ? const Text('🍔',
                                style: TextStyle(fontSize: 22),
                                textAlign: TextAlign.center)
                            : const Icon(Icons.storefront_rounded,
                                color: AppColors.gold, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supermercado,
                              style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              compra['fonte'] == 'ifood'
                                  ? '$dataCompra · iFood Benefícios'
                                  : '$dataCompra · ${itens.length} item${itens.length != 1 ? 's' : ''}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Valor + badge pendente
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'R\$ ${valorTotal.toStringAsFixed(2)}',
                            style: AppTextStyles.monoSm.copyWith(
                                color: AppColors.acc),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.org.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusChip),
                            ),
                            child: Text(
                              'Pendente',
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.org),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _expandido ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.mu,
                            size: 22),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Itens expandidos (agrupados por categoria) — só para NFC-e
          if (_expandido && compra['fonte'] != 'ifood') ...[
            const Divider(
                height: 1, thickness: 0.5, color: AppColors.bord),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePad, 12, AppSpacing.pagePad, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: porCategoria.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          entry.key,
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.acc,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5),
                        ),
                      ),
                      ...entry.value.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(
                                    Icons.fiber_manual_record_rounded,
                                    size: 6,
                                    color: AppColors.mu),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item['nome_padronizado'] as String? ?? '',
                                    style: AppTextStyles.caption
                                        .copyWith(color: AppColors.tx),
                                  ),
                                ),
                                Text(
                                  '${item['quantidade']} ${item['unidade']}',
                                  style: AppTextStyles.caption,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'R\$ ${(item['valor_total_item'] as num).toStringAsFixed(2)}',
                                  style: AppTextStyles.caption
                                      .copyWith(color: AppColors.acc),
                                ),
                              ],
                            ),
                          )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],

          // Ações
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePad, 0, AppSpacing.pagePad, AppSpacing.pagePad),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.red),
                    label: const Text('Rejeitar',
                        style: TextStyle(
                            color: AppColors.red, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusBtn),
                      ),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _rejeitar(context, ref),
                  ),
                ),
                const SizedBox(width: AppSpacing.cardGap),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded,
                        size: 16, color: Colors.black),
                    label: const Text(
                      'CONFIRMAR COMPRA',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.acc,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusBtn),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _mostrarConfirmacao(context, ref),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rejeitar(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
        title: Text('Rejeitar compra?', style: AppTextStyles.titleSm),
        content: Text(
          'A compra de "${widget.compra['supermercado']}" será removida permanentemente.',
          style: AppTextStyles.body.copyWith(color: AppColors.mu),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: AppTextStyles.body.copyWith(color: AppColors.mu)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusBtn)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rejeitar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final perfil = ref.read(perfilUsuarioLogadoProvider).asData?.value;
      if (perfil == null) return;
      final uri =
          Uri.parse('${ApiService.baseUrl}/api/v1/compras/${widget.compra['compra_id']}')
              .replace(queryParameters: {
        'familia_id': perfil['familia_id'] as String,
      });
      await http.delete(uri, headers: ApiService.authHeaders());
      ref.invalidate(comprasPendentesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro: $e'),
              backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _mostrarConfirmacao(
      BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmarSheet(compra: widget.compra),
    );
    ref.invalidate(comprasPendentesProvider);
  }
}

// ─── Sheet de confirmação ─────────────────────────────────────────────────────

class _ConfirmarSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> compra;
  const _ConfirmarSheet({required this.compra});

  @override
  ConsumerState<_ConfirmarSheet> createState() => _ConfirmarSheetState();
}

class _ConfirmarSheetState extends ConsumerState<_ConfirmarSheet> {
  String? _envelopeId;
  bool _confirmando = false;

  String _formatDate(String raw) {
    if (raw.length < 10) return raw;
    final p = raw.substring(0, 10).split('-');
    if (p.length < 3) return raw;
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
    final envelopesAsync = ref.watch(envelopesProvider);
    final itens = (widget.compra['itens'] as List?) ?? [];
    final valorTotal =
        (widget.compra['valor_total'] as num?)?.toDouble() ?? 0.0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            24,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePad, 20, AppSpacing.pagePad, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.bord,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Título
            Text('Confirmar Compra', style: AppTextStyles.title),
            const SizedBox(height: 4),
            Text(
              '${widget.compra['supermercado'] ?? 'Supermercado'}  ·  ${_formatDate(widget.compra['data_compra'] as String? ?? '')}',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
            ),
            const SizedBox(height: 16),

            // Resumo do valor
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surf,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 4),
                border: Border.all(color: AppColors.bord),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total da compra',
                          style: AppTextStyles.caption),
                      Text(
                        'R\$ ${valorTotal.toStringAsFixed(2)}',
                        style: AppTextStyles.mono
                            .copyWith(color: AppColors.acc, fontSize: 22),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${itens.length} itens',
                          style: AppTextStyles.caption),
                      Text(
                        'Média: R\$ ${itens.isNotEmpty ? (valorTotal / itens.length).toStringAsFixed(2) : '0.00'}',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.mu),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Seletor de envelope
            Text('Debitar de qual envelope?',
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            envelopesAsync.when(
              data: (envelopes) {
                if (envelopes.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surf,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusInput),
                      border: Border.all(color: AppColors.bord),
                    ),
                    child: Text(
                      'Nenhum envelope encontrado. Crie um envelope primeiro.',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.mu),
                    ),
                  );
                }
                return DropdownButtonFormField<String>(
                  dropdownColor: AppColors.card,
                  value: _envelopeId,
                  hint: Text('Selecionar envelope',
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.mu)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surf,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusInput),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusInput),
                      borderSide:
                          const BorderSide(color: AppColors.acc),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  items: envelopes
                      .map((e) => DropdownMenuItem<String>(
                            value: e['id'] as String,
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    e['nome_envelope'] as String,
                                    style: AppTextStyles.body,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'R\$ ${(e['saldo_atual'] as num).toStringAsFixed(2)}',
                                  style: AppTextStyles.monoSm.copyWith(
                                    color: (e['saldo_atual'] as num) >= valorTotal
                                        ? AppColors.grn
                                        : AppColors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _envelopeId = v),
                );
              },
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.acc)),
              error: (e, _) => Text('Erro: $e',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.red)),
            ),

            const SizedBox(height: 24),

            // Botão confirmar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.acc,
                  disabledBackgroundColor: AppColors.bord,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusBtn),
                  ),
                ),
                onPressed: (_envelopeId == null || _confirmando)
                    ? null
                    : () => _confirmar(perfil),
                child: _confirmando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2),
                      )
                    : const Text(
                        'Confirmar e Debitar',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmar(Map<String, dynamic>? perfil) async {
    if (perfil == null || _envelopeId == null) return;
    setState(() => _confirmando = true);
    try {
      final uri =
          Uri.parse('${ApiService.baseUrl}/api/v1/compras/confirmar');
      final resp = await http.post(
        uri,
        headers: ApiService.authHeaders(json: true),
        body: jsonEncode({
          'compra_id': widget.compra['compra_id'],
          'familia_id': perfil['familia_id'],
          'usuario_id': perfil['id'],
          'envelope_id': _envelopeId,
        }),
      );
      if (resp.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Compra confirmada e debitada do envelope!'),
            backgroundColor: AppColors.grn,
            duration: Duration(seconds: 3),
          ));
        }
      } else {
        final body = jsonDecode(resp.body);
        throw Exception(body['detail'] ?? resp.body);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro: $e'),
              backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }
}

// ─── Ícone com badge ──────────────────────────────────────────────────────────

class _IconBtnBadge extends StatelessWidget {
  final IconData icon;
  final int? badge;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtnBadge({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusSm + 2),
                border: Border.all(color: AppColors.bord),
              ),
              child: Icon(icon, color: AppColors.mu, size: 20),
            ),
            if (badge != null && badge! > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
