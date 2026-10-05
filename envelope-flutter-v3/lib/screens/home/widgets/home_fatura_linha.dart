import 'package:flutter/material.dart';
import '../../../core/plano/plano_mes.dart';
import '../../../core/services/app_navigator.dart';
import '../../../ui/theme/nb_theme.dart';

/// Uma linha no Início: a fatura do cartão que está se formando (parcelas e
/// assinaturas + compras no crédito do mês). Toque leva para Contas.
class LinhaFaturaEmFormacao extends StatelessWidget {
  const LinhaFaturaEmFormacao({super.key, required this.limite});
  final LimiteMes limite;

  @override
  Widget build(BuildContext context) {
    final l = limite;
    return Material(
      color: NBColors.reservaClaro,
      borderRadius: BorderRadius.circular(NBRadius.cartao),
      child: InkWell(
        borderRadius: BorderRadius.circular(NBRadius.cartao),
        onTap: () => navegarParaAba(navContas),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: NBSpacing.l, vertical: NBSpacing.m),
          child: Row(children: [
            const Icon(Icons.credit_card_rounded, color: NBColors.reserva, size: 20),
            const SizedBox(width: NBSpacing.s),
            Expanded(
              child: Text('Fatura Nubank 7/${l.mesFatura.substring(5)} em formação',
                  style: NBText.corpo.copyWith(fontSize: 14, color: NBColors.reserva)),
            ),
            Text(brl(l.faturaEmFormacao), style: NBText.rotulo.copyWith(color: NBColors.reserva)),
            const Icon(Icons.chevron_right_rounded, color: NBColors.reserva),
          ]),
        ),
      ),
    );
  }
}
