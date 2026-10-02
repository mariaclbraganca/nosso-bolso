import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/contas_provider.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';

class ContasCard extends StatelessWidget {
  final Map<String, dynamic> conta;
  final ValueChanged<bool> onTogglePago;
  final VoidCallback onExcluir;

  const ContasCard({
    super.key,
    required this.conta,
    required this.onTogglePago,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final nome = conta['nome'] as String? ?? 'Conta';
    final valor = (conta['valor'] as num?)?.toDouble() ?? 0.0;
    final pago = conta['pago'] == true;
    final cat = conta['categoria'] as String? ?? 'outro';
    final emoji = emojiCategoria(cat);
    final vencStr = conta['data_vencimento'] as String?;
    final codigo = conta['codigo_barras'] as String? ?? conta['pix_copia_cola'] as String?;

    DateTime? venc;
    if (vencStr != null) venc = DateTime.tryParse(vencStr);

    final hoje = DateTime.now();
    bool atrasada = false;
    bool venceHoje = false;
    String vencLabel = 'Sem vencimento';

    if (venc != null) {
      final dVenc = DateTime(venc.year, venc.month, venc.day);
      final dHoje = DateTime(hoje.year, hoje.month, hoje.day);
      if (!pago) {
        if (dVenc.isBefore(dHoje)) {
          atrasada = true;
        } else if (dVenc.isAtSameMomentAs(dHoje)) {
          venceHoje = true;
        }
      }
      vencLabel = 'Vence ${DateFormat('dd/MM').format(venc)}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CartaoNB(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                pago ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: pago ? NBColors.verde : NBColors.tintaSuave,
                size: 24,
              ),
              onPressed: () => onTogglePago(!pago),
            ),
            const SizedBox(width: 4),
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: NBColors.afundado,
                shape: BoxShape.circle,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    style: NBText.corpo.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: pago ? TextDecoration.lineThrough : null,
                      color: pago ? NBColors.tintaSuave : NBColors.tinta,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(vencLabel, style: NBText.legenda),
                      if (atrasada) ...[
                        const SizedBox(width: 6),
                        const SeloNB('ATRASADA', cor: NBColors.estouro, fundo: NBColors.estouroClaro),
                      ] else if (venceHoje) ...[
                        const SizedBox(width: 6),
                        const SeloNB('HOJE', cor: NBColors.ambarTexto, fundo: NBColors.ambarClaro),
                      ] else if (pago) ...[
                        const SizedBox(width: 6),
                        const SeloNB('PAGA', cor: NBColors.verde, fundo: NBColors.verdeClaro),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  brl(valor),
                  style: NBText.valorCartao.copyWith(
                    fontSize: 16,
                    color: pago ? NBColors.tintaSuave : NBColors.tinta,
                    decoration: pago ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (codigo != null && codigo.isNotEmpty && !pago) ...[
                  const SizedBox(height: 2),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: codigo));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Código copiado para a área de transferência!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.copy_rounded, size: 12, color: NBColors.verde),
                        const SizedBox(width: 2),
                        Text('Copiar código', style: NBText.legenda.copyWith(color: NBColors.verde)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 20, color: NBColors.tintaSuave),
              color: NBColors.cartao,
              onSelected: (val) {
                if (val == 'excluir') onExcluir();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'excluir',
                  child: Text('Excluir', style: TextStyle(color: NBColors.estouro)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
