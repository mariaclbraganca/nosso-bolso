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

String _nomeReceita(Map<String, dynamic> r) => (r['nome'] as String?)?.trim().isNotEmpty == true ? r['nome'] as String : 'Receita';

/// Resposta no topo do orçamento: falta (âmbar) ou sobra (verde) para o mês
/// seguinte, o que entra × o que sai e o atalho para ver a conta.
class TopoOrcamento extends StatelessWidget {
  const TopoOrcamento({super.key, required this.limite, required this.totalOrcado});
  final LimiteMes limite;
  final double totalOrcado;

  @override
  Widget build(BuildContext context) {
    final l = limite;
    final entra = l.salario + l.eventuaisNoCiclo;
    final sai = l.comprometido + totalOrcado;
    final diferenca = entra - sai;
    final falta = diferenca < 0;
    final cor = falta ? NBColors.ambarTexto : NBColors.verdeProfundo;
    final proximo = nomeMes(somarMeses(l.mes, 1));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(NBSpacing.l),
      decoration: BoxDecoration(
        color: falta ? NBColors.ambarClaro : NBColors.verdeClaro,
        borderRadius: BorderRadius.circular(NBRadius.cartao),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(falta ? 'FALTA DINHEIRO PARA ${proximo.toUpperCase()}' : 'AINDA PODE DISTRIBUIR',
            style: NBText.eyebrow.copyWith(color: cor)),
        const SizedBox(height: 2),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(brl(diferenca.abs()), style: NBText.saldo.copyWith(color: cor, fontSize: 32)),
            ),
          ),
          if (falta) ...[const SizedBox(width: 8), Text('sai da reserva', style: NBText.legenda.copyWith(color: cor))],
        ]),
        const SizedBox(height: 4),
        Text('Entra ${brl(entra)}  ·  Sai ${brl(sai)}', style: NBText.corpo.copyWith(color: cor, fontSize: 14)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: cor),
            onPressed: () => abrirSheet(context, FolhaContaOrcamento(limite: l, totalOrcado: totalOrcado)),
            child: const Text('Ver a conta ›'),
          ),
        ),
      ]),
    );
  }
}

/// A conta do orçamento: só o que entra na soma; o que está fora fica à parte.
class FolhaContaOrcamento extends StatelessWidget {
  const FolhaContaOrcamento({super.key, required this.limite, required this.totalOrcado});
  final LimiteMes limite;
  final double totalOrcado;

  @override
  Widget build(BuildContext context) {
    final l = limite;
    final mes = nomeMes(l.mes), proximo = nomeMes(somarMeses(l.mes, 1));
    final diferenca = l.salario + l.eventuaisNoCiclo - l.comprometido - totalOrcado;
    final recebidas = [
      for (final r in l.receitas)
        if (r['tipo'] == 'eventual' && r['recebido'] == true && r['destino'] != 'reserva') r,
    ];
    final cinza = NBText.legenda;
    Widget secao(String t) => Padding(
          padding: const EdgeInsets.only(top: NBSpacing.l, bottom: 2),
          child: Text(t, style: NBText.eyebrow),
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.l, NBSpacing.margemTela, NBSpacing.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TopoSheet(
            titulo: 'A conta de $proximo',
            subtitulo: 'O salário de ${ultimoDiaUtil(l.mes)} paga as compras de $mes (fatura de 7/${l.mesFatura.substring(5)}) '
                'e as contas de $proximo.',
          ),
          secao('ENTRADAS CONFIRMADAS (+)'),
          LinhaValorNB(l.nomeSalario, l.salario),
          if (l.eventuaisNoCiclo > 0) LinhaValorNB('Receitas que sobraram depois das contas de $mes', l.eventuaisNoCiclo),
          secao('DESPESAS (−)'),
          LinhaValorNB('Possíveis contas de $proximo', l.provisaoContas,
              detalhe: [for (final c in l.contasProximoMes) ((c['nome'] as String?) ?? '', (c['valor'] as num).toDouble())]),
          LinhaValorNB('Fatura Nubank 7/${l.mesFatura.substring(5)} — parcelas e assinaturas', l.lancamentosFuturos, detalhe: [
            for (final i in itensDaFatura(l.compromissos, l.mesFatura))
              ('${i.descricao} · ${i.parcela == null ? 'assinatura' : '${i.parcela}/${i.total}'}', i.valor),
          ]),
          LinhaValorNB('Envelopes planejados', totalOrcado),
          const Divider(height: 16),
          LinhaValorNB(diferenca < 0 ? 'Falta dinheiro (sai da reserva)' : 'Ainda pode distribuir', diferenca.abs(),
              forte: true, cor: diferenca < 0 ? NBColors.ambarTexto : NBColors.verde),
          if (l.eventuaisAReceber.isNotEmpty || recebidas.isNotEmpty || l.limiteVa > 0) ...[
            secao('FORA DA CONTA'),
            for (final r in l.eventuaisAReceber)
              _ForaDaConta(
                titulo: '${_nomeReceita(r)} · a receber',
                valor: ((r['valor'] as num?) ?? 0).toDouble(),
                texto: 'Quando cair, paga primeiro as contas de $mes (reduz o que sai da reserva em $mes).',
              ),
            if (l.eventuaisNasContas > 0)
              _ForaDaConta(
                titulo: '${recebidas.map(_nomeReceita).join(', ')} · recebido',
                valor: l.eventuaisNasContas,
                texto: 'Usado nas contas de $mes.',
              ),
            if (l.limiteVa > 0)
              _ForaDaConta(
                titulo: 'Vale-alimentação',
                valor: l.limiteVa,
                texto: 'Tem conta própria: só paga compras no VA.',
              ),
          ],
          const SizedBox(height: NBSpacing.s),
          Text('Para mudar algum valor: envelopes nesta tela; contas em Contas; parcelas em Mais › Futuro; salário em Resumo.',
              style: cinza),
        ]),
      ),
    );
  }
}

class _ForaDaConta extends StatelessWidget {
  const _ForaDaConta({required this.titulo, required this.valor, required this.texto});
  final String titulo;
  final double valor;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 2, right: 8),
            child: Icon(Icons.lock_outline_rounded, size: 16, color: NBColors.tintaSuave),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: NBText.corpo.copyWith(fontSize: 14, color: NBColors.tintaSuave)),
              Text(texto, style: NBText.legenda),
            ]),
          ),
          const SizedBox(width: 8),
          Text(brl(valor), style: NBText.corpo.copyWith(fontSize: 14, color: NBColors.tintaSuave)),
        ]),
      );
}
