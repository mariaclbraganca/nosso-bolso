import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/compras_provider.dart';
import '../../core/providers/usuarios_provider.dart';
import '../../core/services/api_service.dart';
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

  void _abrirScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QrScannerSheet(
        onCodeScanned: (url) async {
          final perfil = ref.read(perfilUsuarioLogadoProvider).value;
          final familiaId = perfil?['familia_id'] as String? ?? '';
          final usuarioId = perfil?['id'] as String? ?? '';

          try {
            await ApiService.post('/api/v1/compras/ingestao', {
              'qr_code_url': url,
              'familia_id': familiaId,
              'usuario_id': usuarioId,
            });
            ref.invalidate(comprasPendentesProvider);
            avisar('Nota enviada para leitura! Em instantes estará processada.');
          } catch (e) {
            avisar(mensagemErro(e), erro: true);
          }
        },
      ),
    );
  }

  void _abrirInserirUrl() {
    showDialog(
      context: context,
      builder: (_) => const InserirUrlDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendentes = ref.watch(comprasPendentesProvider).value ?? [];
    final feedbackPendente = ref.watch(feedbackPendenteProvider).value ?? [];

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
