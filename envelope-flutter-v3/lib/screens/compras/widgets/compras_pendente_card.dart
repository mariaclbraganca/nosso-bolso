import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/compras_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../sheets/comum.dart';
import 'confirmar_compra_dialog.dart';

class ComprasPendenteCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> compra;

  const ComprasPendenteCard({super.key, required this.compra});

  @override
  ConsumerState<ComprasPendenteCard> createState() => _ComprasPendenteCardState();
}

class _ComprasPendenteCardState extends ConsumerState<ComprasPendenteCard> {
  bool _expandido = false;

  Future<void> _descartar() async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NBColors.cartao,
        title: const Text('Descartar Compra', style: TextStyle(color: NBColors.tinta)),
        content: const Text('Deseja realmente descartar esta nota sem lançá-la?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar', style: TextStyle(color: NBColors.estouro)),
          ),
        ],
      ),
    );

    if (conf == true) {
      final id = widget.compra['id'] as String? ?? widget.compra['_id'] as String? ?? '';
      try {
        await ApiService.delete('/api/v1/compras/$id');
        ref.invalidate(comprasPendentesProvider);
        avisar('Compra descartada.');
      } catch (e) {
        avisar(mensagemErro(e), erro: true);
      }
    }
  }

  void _confirmar() {
    showDialog(
      context: context,
      builder: (_) => ConfirmarCompraDialog(compra: widget.compra),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estab = widget.compra['estabelecimento'] as String? ?? 'Mercado / Estabelecimento';
    final valorTotal = (widget.compra['valor_total'] as num?)?.toDouble() ?? 0.0;
    final dataStr = widget.compra['data_compra'] as String? ?? widget.compra['data'] as String?;
    final itens = (widget.compra['itens'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    DateTime? data;
    if (dataStr != null) data = DateTime.tryParse(dataStr);
    final dataFmt = data != null ? DateFormat('dd/MM/yyyy HH:mm').format(data) : 'Data não informada';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CartaoNB(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(estab, style: NBText.secao, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('$dataFmt  ·  ${itens.length} itens', style: NBText.legenda),
                    ],
                  ),
                ),
                Text(brl(valorTotal), style: NBText.valorCartao.copyWith(color: NBColors.tinta)),
              ],
            ),
            const SizedBox(height: 12),
            if (itens.isNotEmpty) ...[
              InkWell(
                onTap: () => setState(() => _expandido = !_expandido),
                child: Row(
                  children: [
                    Text(
                      _expandido ? 'Ocultar itens' : 'Ver ${itens.length} itens da nota',
                      style: NBText.legenda.copyWith(color: NBColors.verde, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expandido ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: NBColors.verde,
                    ),
                  ],
                ),
              ),
              if (_expandido) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                for (final item in itens)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['nome'] as String? ?? 'Item',
                            style: NBText.legenda.copyWith(color: NBColors.tinta),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${item['quantidade'] ?? 1}x ${brl((item['valor_total'] as num?)?.toDouble() ?? 0.0)}',
                          style: NBText.legenda,
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: BotaoPrincipal(
                    rotulo: 'Confirmar despesa',
                    onPressed: _confirmar,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: NBColors.estouro),
                  tooltip: 'Descartar nota',
                  onPressed: _descartar,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
