import 'package:flutter/material.dart';
import '../../../core/plano/plano_mes.dart';
import '../../../ui/theme/nb_theme.dart';
import 'home_cartao_saldo.dart' show nomeMes;
import 'home_fatura_linha.dart';

/// Aviso do mês corrente: quanto ainda vai sair da reserva para terminar de
/// pagar as contas (e quanto cai se a receita prevista entrar). Só este mês:
/// a falta do mês seguinte fica no Orçamento.
class AvisoReservaDoMes extends StatelessWidget {
  const AvisoReservaDoMes({super.key, required this.limite});
  final LimiteMes limite;

  @override
  Widget build(BuildContext context) {
    final l = limite;
    final sai = l.caixa.aindaSaiNoMes;
    if (sai <= 0) return const SizedBox.shrink();
    final mes = nomeMes(l.mes);
    final aReceber = l.eventuaisAReceber;
    final valorAReceber = aReceber.fold(0.0, (s, r) => s + ((r['valor'] as num?) ?? 0));
    final nomes = aReceber.map((r) => ((r['nome'] as String?) ?? 'a receita').toLowerCase()).join(' e ');
    final cor = NBColors.ambarTexto;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(NBSpacing.l),
      decoration: BoxDecoration(color: NBColors.ambarClaro, borderRadius: BorderRadius.circular(NBRadius.cartao)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(mes.toUpperCase(), style: NBText.eyebrow.copyWith(color: cor)),
        const SizedBox(height: 2),
        Text('Vai sair da reserva: ${brl(sai)}', style: NBText.rotulo.copyWith(color: cor)),
        Text(
          'para terminar de pagar as contas de $mes'
          '${aReceber.isEmpty ? '' : ' · se $nomes cair: ${brl((sai - valorAReceber).clamp(0, double.infinity))}'}',
          style: NBText.corpo.copyWith(color: cor, fontSize: 13),
        ),
      ]),
    );
  }
}

/// Contas que vencem no mês (total, pago, falta) e a fatura em formação.
class ContasDoMesCard extends StatelessWidget {
  const ContasDoMesCard({super.key, required this.limite});
  final LimiteMes limite;

  @override
  Widget build(BuildContext context) {
    final l = limite;
    Widget linha(String r, double v, {bool forte = false, Color? cor}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(r, style: forte ? NBText.rotulo : NBText.corpo.copyWith(fontSize: 14))),
            const SizedBox(width: 8),
            Text(brl(v), style: (forte ? NBText.rotulo : NBText.corpo.copyWith(fontSize: 14)).copyWith(color: cor)),
          ]),
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(NBSpacing.l),
      decoration: BoxDecoration(
        color: NBColors.cartao,
        borderRadius: BorderRadius.circular(NBRadius.cartao),
        border: Border.all(color: NBColors.linha),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CONTAS QUE VENCEM EM ${nomeMes(l.mes).toUpperCase()}', style: NBText.eyebrow),
        const SizedBox(height: 6),
        linha('Total', l.caixa.totalContas),
        linha('Pago', l.caixa.totalPago, cor: NBColors.verde),
        linha('Falta pagar', l.caixa.faltaPagar, forte: true, cor: l.caixa.faltaPagar > 0 ? NBColors.estouro : NBColors.verde),
        const SizedBox(height: NBSpacing.s),
        LinhaFaturaEmFormacao(limite: l),
      ]),
    );
  }
}
