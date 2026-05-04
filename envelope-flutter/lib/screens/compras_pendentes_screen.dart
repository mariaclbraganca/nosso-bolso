import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../providers/compras_provider.dart';
import '../providers/usuarios_provider.dart';
import '../providers/envelopes_provider.dart';
import '../services/api_service.dart';
import 'feedback_compras_screen.dart';
import 'lista_compras_screen.dart';
import 'configuracao_ia_screen.dart';
import 'qr_scanner_screen.dart';

class ComprasPendentesScreen extends ConsumerStatefulWidget {
  const ComprasPendentesScreen({super.key});

  @override
  ConsumerState<ComprasPendentesScreen> createState() =>
      _ComprasPendentesScreenState();
}

class _ComprasPendentesScreenState
    extends ConsumerState<ComprasPendentesScreen> {
  @override
  Widget build(BuildContext context) {
    final comprasAsync = ref.watch(comprasPendentesProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Compras IA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.feedback_outlined),
            tooltip: 'Feedback pendente',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbackComprasScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'Lista Inteligente',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ListaComprasScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configurar chaves de API',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConfiguracaoIAScreen()),
            ),
          ),
        ],
      ),
      body: Column(children: [
        _ScanCta(
          onScan: () => _abrirCamera(context),
          onPaste: () => _mostrarDialogColarUrl(context),
        ),
        Expanded(
          child: comprasAsync.when(
            data: (compras) => compras.isEmpty
                ? _emptyState()
                : RefreshIndicator(
                    color: AppColors.acc,
                    onRefresh: () =>
                        ref.refresh(comprasPendentesProvider.future),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
                      itemCount: compras.length,
                      itemBuilder: (ctx, i) => _CompraCard(compra: compras[i]),
                    ),
                  ),
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.acc)),
            error: (e, _) => Center(
              child: Text('Erro: $e',
                  style: const TextStyle(color: AppColors.red)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.mu),
        const SizedBox(height: 12),
        const Text('Nenhuma compra pendente',
            style: TextStyle(color: AppColors.mu, fontSize: 16)),
        const SizedBox(height: 6),
        const Text('Toque em "Escanear NFC-e" acima para começar',
            style: TextStyle(color: AppColors.mu, fontSize: 12)),
      ]),
    );
  }

  Future<void> _abrirCamera(BuildContext context) async {
    final perfil = ref.read(perfilUsuarioLogadoProvider).asData?.value;
    if (perfil == null) return;
    final familiaId = perfil['familia_id'] as String? ?? '';
    final url = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (url != null && url.isNotEmpty) {
      await _enviarIngestao(familiaId, url);
    }
  }

  Future<void> _mostrarDialogColarUrl(BuildContext context) async {
    final controller = TextEditingController();
    final perfil = ref.read(perfilUsuarioLogadoProvider).asData?.value;
    if (perfil == null) return;
    final familiaId = perfil['familia_id'] as String? ?? '';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Colar URL da NFC-e',
            style: TextStyle(color: AppColors.tx)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.tx),
          decoration: const InputDecoration(
            hintText: 'https://nfce...',
            hintStyle: TextStyle(color: AppColors.mu),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.bord)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.acc)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancelar', style: TextStyle(color: AppColors.mu)),
          ),
          TextButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isEmpty) return;
              Navigator.pop(ctx);
              await _enviarIngestao(familiaId, url);
            },
            child: const Text('Enviar', style: TextStyle(color: AppColors.acc)),
          ),
        ],
      ),
    );
  }

  Future<void> _enviarIngestao(String familiaId, String qrUrl) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/v1/compras/ingestao');
      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'familia_id': familiaId, 'qr_code_url': qrUrl}));
      if (resp.statusCode == 202) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('NFC-e enviada! Aguarde o processamento.'),
            backgroundColor: AppColors.grn,
          ));
          await Future.delayed(const Duration(seconds: 3));
          ref.refresh(comprasPendentesProvider);
        }
      } else {
        throw Exception(resp.body);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }
}

class _ScanCta extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onPaste;
  const _ScanCta({required this.onScan, required this.onPaste});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.black),
              label: const Text(
                'Escanear NFC-e',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.acc,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onScan,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          width: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: const BorderSide(color: AppColors.bord),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onPaste,
            child: const Icon(Icons.link, color: AppColors.mu, size: 20),
          ),
        ),
      ]),
    );
  }
}

class _CompraCard extends ConsumerWidget {
  final Map<String, dynamic> compra;
  const _CompraCard({required this.compra});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itens = (compra['itens'] as List?) ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Text(
                compra['supermercado'] ?? 'Supermercado',
                style: const TextStyle(
                    color: AppColors.tx,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              'R\$ ${(compra['valor_total'] as num).toStringAsFixed(2)}',
              style: const TextStyle(
                  color: AppColors.acc,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            '${itens.length} itens · ${(compra['data_compra'] as String).substring(0, 10)}',
            style: const TextStyle(color: AppColors.mu, fontSize: 12),
          ),
          const SizedBox(height: 10),
          ...itens.take(3).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• ${item['nome_padronizado']}  '
                  '${item['quantidade']}${item['unidade']}  '
                  'R\$ ${(item['valor_total_item'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.mu, fontSize: 11),
                ),
              )),
          if (itens.length > 3)
            Text('+ ${itens.length - 3} itens…',
                style: const TextStyle(color: AppColors.mu, fontSize: 11)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.close, size: 16, color: AppColors.red),
                label: const Text('Cancelar',
                    style: TextStyle(color: AppColors.red)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.red)),
                onPressed: () => _cancelar(context, ref),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16, color: Colors.black),
                label: const Text('Confirmar',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.acc),
                onPressed: () => _mostrarConfirmacao(context, ref),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _cancelar(BuildContext context, WidgetRef ref) async {
    final perfil = ref.read(perfilUsuarioLogadoProvider).asData?.value;
    if (perfil == null) return;
    try {
      final uri =
          Uri.parse('${ApiService.baseUrl}/api/v1/compras/${compra['compra_id']}')
              .replace(
                  queryParameters: {'familia_id': perfil['familia_id'] as String});
      await http.delete(uri);
      ref.refresh(comprasPendentesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _mostrarConfirmacao(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmarSheet(compra: compra),
    );
    ref.refresh(comprasPendentesProvider);
  }
}

class _ConfirmarSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> compra;
  const _ConfirmarSheet({required this.compra});

  @override
  ConsumerState<_ConfirmarSheet> createState() => _ConfirmarSheetState();
}

class _ConfirmarSheetState extends ConsumerState<_ConfirmarSheet> {
  String? _envelopeId;

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
    final envelopesAsync = ref.watch(envelopesProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Confirmar Compra',
                style: TextStyle(
                    color: AppColors.tx,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              '${widget.compra['supermercado']} · R\$ ${(widget.compra['valor_total'] as num).toStringAsFixed(2)}',
              style: const TextStyle(color: AppColors.mu, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text('Debitará de qual envelope?',
                style: TextStyle(color: AppColors.tx, fontSize: 14)),
            const SizedBox(height: 8),
            envelopesAsync.when(
              data: (envelopes) => DropdownButtonFormField<String>(
                dropdownColor: AppColors.surf,
                value: _envelopeId,
                hint: const Text('Selecionar envelope',
                    style: TextStyle(color: AppColors.mu)),
                items: envelopes
                    .map((e) => DropdownMenuItem<String>(
                          value: e['id'] as String,
                          child: Text(
                            '${e['nome_envelope']}  (R\$ ${(e['saldo_atual'] as num).toStringAsFixed(2)})',
                            style: const TextStyle(color: AppColors.tx),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _envelopeId = v),
                decoration: const InputDecoration(
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.bord)),
                ),
              ),
              loading: () =>
                  const CircularProgressIndicator(color: AppColors.acc),
              error: (e, _) =>
                  Text('Erro: $e', style: const TextStyle(color: AppColors.red)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.acc,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed:
                    _envelopeId == null ? null : () => _confirmar(perfil),
                child: const Text('Confirmar e Debitar',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
    );
  }

  Future<void> _confirmar(Map<String, dynamic>? perfil) async {
    if (perfil == null || _envelopeId == null) return;
    try {
      final uri =
          Uri.parse('${ApiService.baseUrl}/api/v1/compras/confirmar');
      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'compra_id': widget.compra['compra_id'],
            'familia_id': perfil['familia_id'],
            'usuario_id': perfil['id'],
            'envelope_id': _envelopeId,
          }));
      if (resp.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Compra confirmada!'),
            backgroundColor: AppColors.grn,
          ));
        }
      } else {
        final body = jsonDecode(resp.body);
        throw Exception(body['detail'] ?? resp.body);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }
}
