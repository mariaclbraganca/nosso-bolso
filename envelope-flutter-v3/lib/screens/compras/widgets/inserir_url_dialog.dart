import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/compras_provider.dart';
import '../../../core/providers/usuarios_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../sheets/comum.dart';

class InserirUrlDialog extends ConsumerStatefulWidget {
  const InserirUrlDialog({super.key});

  @override
  ConsumerState<InserirUrlDialog> createState() => _InserirUrlDialogState();
}

class _InserirUrlDialogState extends ConsumerState<InserirUrlDialog> {
  final _urlCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final url = _urlCtrl.text.trim();
    if (!url.startsWith('http')) {
      avisar('Informe uma URL válida (iniciando com http:// ou https://).', erro: true);
      return;
    }

    setState(() => _enviando = true);
    final perfil = ref.read(perfilUsuarioLogadoProvider).valueOrNull;
    final familiaId = perfil?['familia_id'] as String? ?? '';
    final usuarioId = perfil?['id'] as String? ?? '';

    try {
      await ApiService.post('/api/v1/compras/ingestao', {
        'qr_code_url': url,
        'familia_id': familiaId,
        'usuario_id': usuarioId,
      });

      ref.invalidate(comprasPendentesProvider);
      avisar('Nota enviada para processamento! Em instantes aparecerá aqui.');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NBColors.cartao,
      title: Text('Ingestão de Nota Fiscal', style: NBText.secao),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cole o link da consulta da NFC-e (geralmente obtido escaneando o QR Code da nota).',
            style: TextStyle(color: NBColors.tintaSuave, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlCtrl,
            style: NBText.corpo,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'https://www.sefaz.../nfce/qrcode?...',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _enviando ? null : _enviar,
          child: _enviando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Processar Nota'),
        ),
      ],
    );
  }
}
