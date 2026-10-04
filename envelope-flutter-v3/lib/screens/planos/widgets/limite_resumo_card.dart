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

/// Disponível para planejar: salário − provisão − lançamentos futuros (só o
/// garantido; receitas eventuais vão para o caixa das contas); depois o total
/// orçado e o resultado previsto.
class LimiteResumoCard extends StatelessWidget {
  const LimiteResumoCard({super.key, required this.limite, this.totalOrcado});
  final LimiteMes limite;

  /// Total orçado em edição (Orçamento mensal); se null, usa o salvo.
  final double? totalOrcado;

  @override
  Widget build(BuildContext context) {
    final l = limite;
    final orcado = totalOrcado ?? l.totalOrcado;
    final saldo = l.limite - orcado;
    final proximo = nomeMes(somarMeses(l.mes, 1));
    return CartaoNB(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ORÇAMENTO DE ${nomeMes(l.mes).toUpperCase()}', style: NBText.eyebrow),
          const SizedBox(height: 4),
          LinhaValorNB(l.nomeSalario, l.salario),
          LinhaValorNB(
            '(−) Possíveis contas de $proximo',
            -l.provisaoContas,
            detalhe: [for (final c in l.contasProximoMes) ((c['nome'] as String?) ?? '', (c['valor'] as num).toDouble())],
          ),
          LinhaValorNB(
            '(−) Parcelas e assinaturas da fatura de 7/${l.mesFatura.substring(5)}',
            -l.lancamentosFuturos,
            detalhe: [
              for (final i in itensDaFatura(l.compromissos, l.mesFatura))
                ('${i.descricao} · ${i.parcela == null ? 'assinatura' : '${i.parcela}/${i.total}'}', i.valor),
            ],
          ),
          const Divider(height: 8),
          LinhaValorNB('Valor disponível para planejar os envelopes', l.limite, forte: true),
          LinhaValorNB('(−) Total planejado dos envelopes', -orcado),
          const Divider(height: 8),
          LinhaValorNB(
            saldo >= 0 ? 'Ainda pode distribuir' : 'Falta no salário (sai da reserva)',
            saldo,
            forte: true,
            cor: saldo >= 0 ? NBColors.verde : NBColors.estouro,
          ),
          if (saldo < 0) ...[
            const SizedBox(height: NBSpacing.s),
            Container(
              padding: const EdgeInsets.all(NBSpacing.m),
              decoration: BoxDecoration(color: NBColors.ambarClaro, borderRadius: BorderRadius.circular(12)),
              child: Text(
                'Se gastarem exatamente o orçado, faltarão ${brl(-saldo)} no salário de ${ultimoDiaUtil(l.mes)}. '
                'Esse valor sai da reserva. Para fechar sem reserva, o total planejado precisa caber no valor disponível para os envelopes.',
                style: NBText.corpo.copyWith(fontSize: 13.5, color: NBColors.ambarTexto),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
