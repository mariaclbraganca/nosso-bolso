import 'package:flutter/material.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../sheets/comum.dart';

/// Pede o link da NFC-e e devolve a URL; quem abriu processa a nota.
class InserirUrlDialog extends StatefulWidget {
  const InserirUrlDialog({super.key});

  @override
  State<InserirUrlDialog> createState() => _InserirUrlDialogState();
}

class _InserirUrlDialogState extends State<InserirUrlDialog> {
  final _urlCtrl = TextEditingController();

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _enviar() {
    final url = _urlCtrl.text.trim();
    if (!url.startsWith('http')) {
      return avisar('Cole o link completo da nota (começa com http).', erro: true);
    }
    Navigator.pop(context, url);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NBColors.cartao,
      title: Text('Informar link da NFC-e', style: NBText.secao),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'É o link do QR Code da NFC-e, aberto no navegador do celular.',
            style: NBText.corpo.copyWith(fontSize: 14, color: NBColors.tintaSuave),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlCtrl,
            autofocus: true,
            keyboardType: TextInputType.url,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'https://…sefaz….gov.br/…'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _enviar,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: const Text('Ler nota'),
        ),
      ],
    );
  }
}
