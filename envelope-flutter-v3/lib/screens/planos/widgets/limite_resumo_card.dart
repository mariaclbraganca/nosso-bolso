import 'package:flutter/material.dart';
import '../../../core/plano/plano_mes.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../home/widgets/home_cartao_saldo.dart' show nomeMes, ultimoDiaUtil;

/// Linha rótulo → valor, opcionalmente expansível com o detalhamento.
class LinhaValorNB extends StatelessWidget {
  const LinhaValorNB(this.rotulo, this.valor, {super.key, this.forte = false, this.cor, this.detalhe = const [], this.vazio});
  final String rotulo;
  final double valor;
  final bool forte;
  final Color? cor;
  final List<(String, double)> detalhe;
  final String? vazio; // texto no lugar do valor quando zero (ex.: "não recebido")

  @override
  Widget build(BuildContext context) {
    final estilo = forte ? NBText.rotulo : NBText.corpo.copyWith(fontSize: 14);
    final valorTxt = valor == 0 && vazio != null
        ? Text(vazio!, style: NBText.legenda)
        : Text(brl(valor), style: estilo.copyWith(color: cor ?? (valor < 0 && forte ? NBColors.estouro : null)));
    final linha = Padding(
      padding: EdgeInsets.symmetric(vertical: forte ? 8 : 5),
      child: Row(children: [
        if (detalhe.isNotEmpty) const Icon(Icons.chevron_right_rounded, size: 18, color: NBColors.tintaSuave),
        Expanded(child: Text(rotulo, style: estilo)),
        valorTxt,
      ]),
    );
    if (detalhe.isEmpty) return linha;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        minTileHeight: 0,
        showTrailingIcon: false,
        title: linha,
        childrenPadding: const EdgeInsets.only(left: 18, bottom: 6),
        children: [
          for (final (n, v) in detalhe)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(child: Text(n, style: NBText.legenda)),
                Text(brl(v), style: NBText.legenda),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Orçamento do mês em Entradas (+) e Despesas (−), sem números negativos:
/// custo do mês × o que entra; a diferença é a tarja (falta ou ainda pode
/// distribuir).
class LimiteResumoCard extends StatelessWidget {
  const LimiteResumoCard({super.key, required this.limite, this.totalOrcado});
  final LimiteMes limite;

  /// Total planejado em edição (Orçamento mensal); se null, usa o salvo.
  final double? totalOrcado;

  @override
  Widget build(BuildContext context) {
    final l = limite;
    final planejado = totalOrcado ?? l.totalOrcado;
    final entradas = l.salario + l.eventuaisNoCiclo;
    final custo = l.comprometido + planejado;
    final diferenca = entradas - custo;
    final proximo = nomeMes(somarMeses(l.mes, 1));
    final cinza = NBText.legenda.copyWith(fontSize: 13);
    Widget secao(String t) => Padding(
          padding: const EdgeInsets.only(top: NBSpacing.s, bottom: 2),
          child: Text(t, style: NBText.eyebrow),
        );

    return CartaoNB(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ORÇAMENTO DE ${nomeMes(l.mes).toUpperCase()}', style: NBText.eyebrow),
          const SizedBox(height: 2),
          Text(
            'O salário de ${ultimoDiaUtil(l.mes)} paga as compras de ${nomeMes(l.mes)} '
            '(fatura de 7/${l.mesFatura.substring(5)}) e as contas de $proximo.',
            style: NBText.legenda,
          ),
          secao('ENTRADAS (+)'),
          LinhaValorNB(l.nomeSalario, l.salario),
          for (final r in l.receitas.where((r) => r['tipo'] == 'eventual' && r['recebido'] == true && r['destino'] != 'reserva'))
            LinhaValorNB(
              '${r['nome'] ?? 'Receita'} (recebida)',
              ((r['valor_recebido'] ?? r['valor']) as num).toDouble(),
            ),
          if (l.eventuaisNasContas > 0)
            Text('${brl(l.eventuaisNasContas)} das receitas recebidas foram para as contas de ${nomeMes(l.mes)}.', style: cinza),
          for (final r in l.eventuaisAReceber)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Expanded(child: Text('${r['nome'] ?? 'Receita'} (a receber · conta quando cair)', style: cinza)),
                Text(brl((r['valor'] as num?) ?? 0), style: cinza),
              ]),
            ),
          secao('DESPESAS (−)'),
          LinhaValorNB(
            'Gastos a serem pagos em $proximo',
            l.comprometido,
            detalhe: [
              ('Possíveis contas de $proximo', l.provisaoContas),
              ('Fatura Nubank 7/${l.mesFatura.substring(5)} — parcelas e assinaturas', l.lancamentosFuturos),
            ],
          ),
          LinhaValorNB('Total planejado dos envelopes', planejado),
          const Divider(height: 12),
          LinhaValorNB('Custo do mês', custo, forte: true),
          const SizedBox(height: NBSpacing.s),
          TarjaResultado(diferenca: diferenca),
        ],
      ),
    );
  }
}

/// Tarja do resultado: âmbar quando falta dinheiro, verde quando sobra.
class TarjaResultado extends StatelessWidget {
  const TarjaResultado({super.key, required this.diferenca});
  final double diferenca;

  @override
  Widget build(BuildContext context) {
    final falta = diferenca < 0;
    final cor = falta ? NBColors.ambarTexto : NBColors.verdeProfundo;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: falta ? NBColors.ambarClaro : NBColors.verdeClaro,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(
          child: Text(falta ? 'Falta dinheiro (sai da reserva)' : 'Ainda pode distribuir',
              style: NBText.rotulo.copyWith(color: cor)),
        ),
        Text(brl(diferenca.abs()), style: NBText.rotulo.copyWith(color: cor)),
      ]),
    );
  }
}
