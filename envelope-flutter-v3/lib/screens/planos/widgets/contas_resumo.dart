import 'package:flutter/material.dart';
import '../../../core/plano/plano_mes.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../home/widgets/home_cartao_saldo.dart' show nomeMes;

/// Resumo da aba Contas: tudo o que vence no mês (fatura do cartão + contas),
/// quanto já foi pago, o saldo disponível e quanto falta cobrir.
class ResumoAPagar extends StatelessWidget {
  const ResumoAPagar({
    super.key,
    required this.mes,
    required this.total,
    required this.pago,
    required this.saldo,
  });
  final String mes;
  final double total;
  final double pago;
  final double saldo;

  @override
  Widget build(BuildContext context) {
    final falta = total - pago;
    final faltaCobrir = falta > saldo ? falta - saldo : 0.0;
    Widget linha(String r, double v, {Color? cor, bool forte = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(r, style: forte ? NBText.rotulo : NBText.corpo.copyWith(fontSize: 14))),
            Text(brl(v), style: (forte ? NBText.rotulo : NBText.corpo.copyWith(fontSize: 14)).copyWith(color: cor)),
          ]),
        );
    return CartaoNB(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('A PAGAR EM ${nomeMes(mes).toUpperCase()}', style: NBText.eyebrow),
        const SizedBox(height: 4),
        Text(brl(total), style: NBText.valorCartao),
        const SizedBox(height: 6),
        linha('Já pago', pago, cor: NBColors.verde),
        linha('Falta pagar', falta, cor: falta > 0 ? NBColors.estouro : NBColors.verde, forte: true),
        const Divider(height: 16),
        linha('Saldo disponível', saldo),
        linha('Falta cobrir com a receita do mês', faltaCobrir,
            cor: faltaCobrir > 0 ? NBColors.estouro : NBColors.verde, forte: true),
      ]),
    );
  }
}

/// A fatura do cartão que vence no mês, com o valor calculado dos lançamentos.
class CartaoFaturaDoMes extends StatelessWidget {
  const CartaoFaturaDoMes({super.key, required this.mes, required this.valor, this.onPagar});
  final String mes;
  final double valor;
  final VoidCallback? onPagar;

  @override
  Widget build(BuildContext context) {
    final ciclo = cicloDaFatura(somarMeses(mes, -1));
    String d(String iso) => '${iso.substring(8)}/${iso.substring(5, 7)}';
    return Container(
      padding: const EdgeInsets.all(NBSpacing.l),
      decoration: BoxDecoration(color: NBColors.reservaClaro, borderRadius: BorderRadius.circular(NBRadius.cartao)),
      child: Row(children: [
        const Icon(Icons.credit_card_rounded, color: NBColors.reserva),
        const SizedBox(width: NBSpacing.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Fatura do cartão · vence 7/${mes.substring(5)}', style: NBText.rotulo.copyWith(color: NBColors.reserva)),
            Text('Compras de ${d(ciclo.ini)} a ${d(ciclo.fim)} + parcelas e assinaturas',
                style: NBText.legenda.copyWith(color: NBColors.reserva)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(brl(valor), style: NBText.valorCartao.copyWith(fontSize: 18, color: NBColors.reserva)),
          if (onPagar != null) TextButton(onPressed: onPagar, child: const Text('Pagar fatura')),
        ]),
      ]),
    );
  }
}
