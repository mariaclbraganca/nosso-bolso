import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/compras_provider.dart';
import '../../../core/providers/envelopes_provider.dart';
import '../../../core/providers/transacoes_provider.dart';
import '../../../core/providers/usuarios_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../sheets/comum.dart';

class ConfirmarCompraDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> compra;

  const ConfirmarCompraDialog({super.key, required this.compra});

  @override
  ConsumerState<ConfirmarCompraDialog> createState() => _ConfirmarCompraDialogState();
}

class _ConfirmarCompraDialogState extends ConsumerState<ConfirmarCompraDialog> {
  String? _envelopeId;
  bool _confirmando = false;

  @override
  void initState() {
    super.initState();
    // Sugestão de envelope pelo backend se houver
    _envelopeId = widget.compra['envelope_id'] as String?;
  }

  Future<void> _confirmar() async {
    if (_envelopeId == null || _envelopeId!.isEmpty) {
      avisar('Selecione um envelope para alocar esta despesa.', erro: true);
      return;
    }

    setState(() => _confirmando = true);
    final perfil = ref.read(perfilUsuarioLogadoProvider).value;
    final familiaId = perfil?['familia_id'] as String? ?? '';
    final usuarioId = perfil?['id'] as String? ?? '';
    final compraId = widget.compra['compra_id'] as String? ?? '';

    try {
      await ApiService.post('/api/v1/compras/confirmar', {
        'compra_id': compraId,
        'envelope_id': _envelopeId,
        'familia_id': familiaId,
        'usuario_id': usuarioId,
      });

      ref.invalidate(comprasPendentesProvider);
      ref.invalidate(transacoesStreamProvider);
      avisar('Compra confirmada e lançada no envelope! ✅');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final envelopes = ref.watch(envelopesViseisProvider);
    final valorTotal = (widget.compra['valor_total'] as num?)?.toDouble() ?? 0.0;
    final estabelecimento = widget.compra['supermercado'] as String? ?? 'Compra';

    return AlertDialog(
      backgroundColor: NBColors.cartao,
      title: Text('Confirmar Despesa', style: NBText.secao),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(estabelecimento, style: NBText.corpo.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Valor total da nota: ${brl(valorTotal)}',
              style: NBText.valorCartao.copyWith(color: NBColors.tinta, fontSize: 18),
            ),
            const SizedBox(height: 16),
            Text('SELECIONE O ENVELOPE:', style: NBText.eyebrow),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in envelopes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ChipNB(
                        rotulo: e['nome_envelope'] as String? ?? '',
                        icone: Text(e['emoji'] as String? ?? '📦', style: const TextStyle(fontSize: 13)),
                        selecionado: _envelopeId == e['id'],
                        onTap: () => setState(() => _envelopeId = e['id'] as String),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirmando ? null : _confirmar,
          child: _confirmando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirmar'),
        ),
      ],
    );
  }
}
