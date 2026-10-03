import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/compras_provider.dart';
import '../../core/services/api_service.dart';
import 'nfce_fluxo.dart';
import 'widgets/compras_falhas_card.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';
import '../sheets/comum.dart';
import 'widgets/compras_header.dart';
import 'widgets/compras_pendente_card.dart';
import 'widgets/feedback_consumo_tab.dart';
import 'widgets/inserir_url_dialog.dart';
import 'widgets/lista_compras_tab.dart';
import 'widgets/qr_scanner_sheet.dart';

enum AbaCompras { pendentes, lista, feedback }

class ComprasScreen extends ConsumerStatefulWidget {
  const ComprasScreen({super.key});

  @override
  ConsumerState<ComprasScreen> createState() => _ComprasScreenState();
}

class _ComprasScreenState extends ConsumerState<ComprasScreen> {
  AbaCompras _aba = AbaCompras.pendentes;
  String _etapa = '';

  Future<void> _processar(String url) async {
    if (_etapa.isNotEmpty) return;
    await processarNota(ref, url, onEtapa: (e) {
      if (mounted) setState(() => _etapa = e);
    });
  }

  void _abrirScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QrScannerSheet(onCodeScanned: _processar),
    );
  }

  Future<void> _abrirInserirUrl() async {
    final url = await showDialog<String>(context: context, builder: (_) => const InserirUrlDialog());
    if (url != null) await _processar(url);
  }

  Future<void> _dispensarFalhas() async {
    try {
      await ApiService.delete('/api/v1/compras/falhas', familiaId: perfilOuErro(ref)['familia_id'] as String);
      ref.invalidate(comprasFalhasProvider);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendentes = ref.watch(comprasPendentesProvider).valueOrNull ?? [];
    final falhas = ref.watch(comprasFalhasProvider).valueOrNull ?? [];
    final feedbackPendente = ref.watch(feedbackPendenteProvider).valueOrNull ?? [];

    final abasMap = <AbaCompras, String>{
      AbaCompras.pendentes: pendentes.isNotEmpty ? '🛒 Pendentes (${pendentes.length})' : '🛒 Pendentes',
      AbaCompras.lista: '📝 Lista IA',
      AbaCompras.feedback: feedbackPendente.isNotEmpty ? '🔄 Feedback (${feedbackPendente.length})' : '🔄 Feedback',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('Compras IA', style: NBText.secao),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar',
            onPressed: () {
              ref.invalidate(comprasPendentesProvider);
              ref.invalidate(feedbackPendenteProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: NBSpacing.margemTela, vertical: 8),
              child: Segmentado<AbaCompras>(
                opcoes: abasMap,
                valor: _aba,
                onChanged: (a) => setState(() => _aba = a),
              ),
            ),
            Expanded(
              child: switch (_aba) {
                AbaCompras.pendentes => ListView(
                    padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 8, NBSpacing.margemTela, 120),
                    children: [
                      ComprasHeader(
                        pendentesCount: pendentes.length,
                        onEscanear: _abrirScanner,
                        onColarUrl: _abrirInserirUrl,
                      ),
                      if (_etapa.isNotEmpty) ...[
                        const SizedBox(height: NBSpacing.m),
                        CartaoNB(
                          child: Row(
                            children: [
                              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
                              const SizedBox(width: NBSpacing.m),
                              Expanded(child: Text(_etapa, style: NBText.corpo)),
                            ],
                          ),
                        ),
                      ],
                      if (falhas.isNotEmpty) ...[
                        const SizedBox(height: NBSpacing.m),
                        ComprasFalhasCard(falhas: falhas, onTentarDeNovo: _processar, onDispensar: _dispensarFalhas),
                      ],
                      const SizedBox(height: NBSpacing.l),
                      const CabecalhoSecao(titulo: 'Notas a Confirmar'),
                      const SizedBox(height: NBSpacing.s),
                      if (pendentes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 36),
                          child: UnicornVazio(
                            type: UnicornType.geronimo,
                            titulo: 'Nenhuma nota pendente',
                            texto: 'Escaneie o QR Code do cupom fiscal após fazer as compras para a IA extrair todos os itens.',
                          ),
                        )
                      else
                        for (final c in pendentes)
                          ComprasPendenteCard(compra: c),
                    ],
                  ),
                AbaCompras.lista => const ListaComprasTab(),
                AbaCompras.feedback => const FeedbackConsumoTab(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
