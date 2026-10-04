import 'package:flutter/material.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';

/// Card individual para cada gasto fixo
class FixosCard extends StatelessWidget {
  final Map<String, dynamic> fixo;
  final bool selecionado;
  final bool modoSelecao;
  final ValueChanged<bool?> onTogglePago;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  final VoidCallback? onPagarParte;

  const FixosCard({
    super.key,
    required this.fixo,
    required this.selecionado,
    required this.modoSelecao,
    required this.onTogglePago,
    required this.onTap,
    required this.onLongPress,
    required this.onEditar,
    required this.onExcluir,
    this.onPagarParte,
  });

  @override
  Widget build(BuildContext context) {
    final nome = fixo['nome'] as String? ?? 'Gasto Fixo';
    final valor = (fixo['valor'] as num?)?.toDouble() ?? 0.0;
    final pago = fixo['pago'] == true;
    final diaVenc = fixo['dia_vencimento'] as int?;
    final valorPago = (fixo['valor_pago'] as num?)?.toDouble() ?? 0.0;
    final parcial = !pago && valorPago > 0;

    // Status de vencimento
    final hoje = DateTime.now();
    bool atrasado = false;
    bool venceHoje = false;
    if (diaVenc != null && !pago) {
      if (hoje.day > diaVenc) {
        atrasado = true;
      } else if (hoje.day == diaVenc) {
        venceHoje = true;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CartaoNB(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(NBRadius.cartao),
          child: Row(
            children: [
              if (modoSelecao)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Checkbox(
                    value: selecionado,
                    activeColor: NBColors.verde,
                    onChanged: (v) => onTap(),
                  ),
                )
              else
                IconButton(
                  icon: Icon(
                    pago ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: pago ? NBColors.verde : NBColors.tintaSuave,
                    size: 24,
                  ),
                  onPressed: () => onTogglePago(!pago),
                ),
              const SizedBox(width: 4),
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
                        if (diaVenc != null)
                          Text('Vence dia $diaVenc', style: NBText.legenda),
                        if (atrasado) ...[
                          const SizedBox(width: 6),
                          const SeloNB('ATRASADO', cor: NBColors.estouro, fundo: NBColors.estouroClaro),
                        ] else if (venceHoje) ...[
                          const SizedBox(width: 6),
                          const SeloNB('VENCE HOJE', cor: NBColors.ambarTexto, fundo: NBColors.ambarClaro),
                        ] else if (pago) ...[
                          const SizedBox(width: 6),
                          const SeloNB('PAGO', cor: NBColors.verde, fundo: NBColors.verdeClaro),
                        ],
                      ],
                    ),
                    if (parcial)
                      Text('Pago ${brl(valorPago)} · falta ${brl(valor - valorPago)}',
                          style: NBText.legenda.copyWith(color: NBColors.ambarTexto)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                brl(valor),
                style: NBText.valorCartao.copyWith(
                  fontSize: 16,
                  color: pago ? NBColors.tintaSuave : NBColors.tinta,
                  decoration: pago ? TextDecoration.lineThrough : null,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: NBColors.tintaSuave),
                color: NBColors.cartao,
                onSelected: (val) {
                  if (val == 'editar') onEditar();
                  if (val == 'excluir') onExcluir();
                  if (val == 'parte') onPagarParte?.call();
                },
                itemBuilder: (ctx) => [
                  if (!pago && onPagarParte != null) const PopupMenuItem(value: 'parte', child: Text('Pagar parte')),
                  const PopupMenuItem(value: 'editar', child: Text('Editar')),
                  const PopupMenuItem(
                    value: 'excluir',
                    child: Text('Excluir', style: TextStyle(color: NBColors.estouro)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
