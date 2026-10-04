import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/plano/plano_mes.dart';
import '../../core/providers/mes_provider.dart';
import '../../core/providers/plano_provider.dart';
import '../../core/services/api_service.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';
import '../home/widgets/home_cartao_saldo.dart' show nomeMes, ultimoDiaUtil;
import '../sheets/comum.dart';
import 'widgets/limite_resumo_card.dart';
import 'widgets/plano_sheets.dart';

/// Resumo do mês: resultado do ciclo do salário, receitas, de onde vem e para
/// onde vai o dinheiro, orçamento por envelope e os próximos meses.
class PlanoMesTab extends ConsumerWidget {
  const PlanoMesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesAtualProvider);
    void recarregar() {
      ref.invalidate(entradasMesProvider(mes));
      ref.invalidate(compromissosCartaoProvider);
    }

    return ref.watch(limiteMesProvider).when(
          loading: () => const UnicornCarregando(texto: 'Montando o resumo do mês…'),
          error: (e, _) => UnicornErro(mensagem: 'Não consegui carregar o resumo do mês.', onTentar: recarregar),
          data: (l) => RefreshIndicator(
            onRefresh: () async => recarregar(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 4, NBSpacing.margemTela, 120),
              children: [
                ResultadoCiclo(limite: l),
                const SizedBox(height: NBSpacing.l),
                _Receitas(limite: l),
                const SizedBox(height: NBSpacing.l),
                _DeOndeVem(limite: l),
                const SizedBox(height: NBSpacing.l),
                _OrcamentoPorEnvelope(limite: l),
                if (l.mes == '2026-10') ...[
                  const SizedBox(height: NBSpacing.l),
                  _Transicao(limite: l),
                ],
              ],
            ),
          ),
        );
  }
}

Color _cor(double v) => v < 0 ? NBColors.estouro : NBColors.verde;

/// Previsto (gastando o orçado), projetado (com o que já aconteceu) e o
/// déficit coberto pela reserva.
class ResultadoCiclo extends StatelessWidget {
  const ResultadoCiclo({super.key, required this.limite});
  final LimiteMes limite;

  @override
  Widget build(BuildContext context) {
    final l = limite;
    final proj = l.resultadoProjetado;
    return CartaoNB(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('RESULTADO DO CICLO · SALÁRIO DE ${ultimoDiaUtil(l.mes)}', style: NBText.eyebrow),
        const SizedBox(height: 4),
        LinhaValorNB('Previsto (gastando o orçado)', l.resultadoPrevisto, cor: _cor(l.resultadoPrevisto)),
        LinhaValorNB('Projetado (com o que já aconteceu)', proj, cor: _cor(proj)),
        const Divider(height: 8),
        LinhaValorNB(
          proj < 0 ? 'Déficit coberto pela reserva' : 'Superávit (sem uso da reserva)',
          proj.abs(),
          forte: true,
          cor: _cor(proj),
        ),
      ]),
    );
  }
}

class _Receitas extends ConsumerWidget {
  const _Receitas({required this.limite});
  final LimiteMes limite;

  Future<void> _marcar(WidgetRef ref, Map<String, dynamic> e, bool recebido) async {
    try {
      await ApiService.patch('/plano/entradas/${e['id']}', {'recebido': recebido});
      ref.invalidate(entradasMesProvider(limite.mes));
    } catch (err) {
      avisar(mensagemErro(err), erro: true);
    }
  }

  static String _tipo(Map<String, dynamic> e) => switch (e['tipo']) {
        'vale' => 'vale-alimentação',
        'eventual' => e['destino'] == 'reserva' ? 'eventual · para a reserva' : 'eventual',
        _ => 'garantida',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receitas = limite.receitas;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('Receitas do mês', style: NBText.secao)),
        IconButton(
          tooltip: 'Nova receita prevista',
          onPressed: () => abrirSheet(context, SheetEntrada(mes: limite.mes)),
          icon: const Icon(Icons.add_circle_outline, color: NBColors.verde),
        ),
      ]),
      if (receitas.isEmpty) Text('Cadastre as receitas previstas: salário e vale-alimentação.', style: NBText.legenda),
      for (final e in receitas)
        CartaoNB(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          onTap: () => abrirSheet(context, SheetEntrada(mes: limite.mes, entrada: e)),
          child: CheckboxListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            controlAffinity: ListTileControlAffinity.leading,
            value: e['recebido'] == true,
            onChanged: (v) => _marcar(ref, e, v ?? false),
            title: Text(e['nome'] as String? ?? '', style: NBText.corpo),
            subtitle: Text(
              [
                _tipo(e),
                if (e['quem'] != null) e['quem'] as String,
                if (e['dia'] != null) 'dia ${e['dia']}',
              ].join(' · '),
              style: NBText.legenda,
            ),
            secondary: Text(brl((e['valor'] as num?) ?? 0), style: NBText.rotulo),
          ),
        ),
    ]);
  }
}

class _DeOndeVem extends StatelessWidget {
  const _DeOndeVem({required this.limite});
  final LimiteMes limite;

  @override
  Widget build(BuildContext context) {
    final l = limite;
    final pix = l.comprasDoMes + l.pendenteDeEnvelope - l.comprasNoCredito;
    return CartaoNB(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('DE ONDE VEM E PARA ONDE VAI', style: NBText.eyebrow),
        const SizedBox(height: 4),
        LinhaValorNB(l.nomeSalario, l.salario, cor: NBColors.verde),
        LinhaValorNB(
          '(−) Fatura Nubank · vence 7/${l.mesFatura.substring(5)}',
          -l.faturaEmFormacao,
          detalhe: [('Lançamentos futuros', l.lancamentosFuturos), ('Compras no crédito do mês', l.comprasNoCredito)],
        ),
        LinhaValorNB('(−) Compras no Pix/Débito do mês', -(pix > 0 ? pix : 0.0)),
        LinhaValorNB('(−) Contas de ${nomeMes(somarMeses(l.mes, 1))}', -l.provisaoContas),
        const Divider(height: 8),
        LinhaValorNB('Resultado até agora', l.disponivel, forte: true, cor: _cor(l.disponivel)),
        Text(
          'O "até agora" considera só as compras já feitas. O projetado também conta o que ainda falta gastar do orçado.',
          style: NBText.legenda,
        ),
      ]),
    );
  }
}

class _OrcamentoPorEnvelope extends StatelessWidget {
  const _OrcamentoPorEnvelope({required this.limite});
  final LimiteMes limite;

  @override
  Widget build(BuildContext context) {
    final l = limite;
    final envs = [...l.envelopes]..sort((a, b) => l.orcadoDe(b).compareTo(l.orcadoDe(a)));
    return CartaoNB(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ORÇAMENTO POR ENVELOPE', style: NBText.eyebrow),
        const SizedBox(height: 6),
        for (final e in envs)
          if (l.orcadoDe(e) > 0 || l.realizadoDe(e) > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Text(e['nome_envelope'] as String? ?? '', style: NBText.corpo.copyWith(fontSize: 14))),
                  Text(
                    '${brl(l.realizadoDe(e))} de ${brl(l.orcadoDe(e))}',
                    style: NBText.legenda.copyWith(color: l.disponivelDe(e) < 0 ? NBColors.estouro : NBColors.tintaSuave),
                  ),
                ]),
                const SizedBox(height: 4),
                BarraProgresso(
                  fracao: l.orcadoDe(e) > 0 ? l.realizadoDe(e) / l.orcadoDe(e) : 1,
                  cor: l.disponivelDe(e) < 0 ? NBColors.estouro : NBColors.verde,
                ),
              ]),
            ),
        const Divider(height: 16),
        LinhaValorNB('Economia em envelopes (se o mês fechasse hoje)', l.economiaEmEnvelopes, forte: true, cor: NBColors.verde),
      ]),
    );
  }
}

/// Outubro/2026: as contas que vencem no mês não têm salário de setembro.
class _Transicao extends StatelessWidget {
  const _Transicao({required this.limite});
  final LimiteMes limite;

  @override
  Widget build(BuildContext context) {
    final total = limite.contasDoMes.fold(0.0, (s, c) => s + ((c['valor'] as num?) ?? 0));
    return Container(
      padding: const EdgeInsets.all(NBSpacing.m),
      decoration: BoxDecoration(color: NBColors.ambarClaro, borderRadius: BorderRadius.circular(12)),
      child: Text(
        'Transição de outubro: as contas que vencem em outubro (${brl(total)}) não têm salário de setembro para pagar. '
        'Elas saem da reserva agora, fora deste ciclo.',
        style: NBText.corpo.copyWith(fontSize: 13.5, color: NBColors.ambarTexto),
      ),
    );
  }
}

/// Disponível para planejar nos próximos meses (sem receitas eventuais).
class ProximosMeses extends StatelessWidget {
  const ProximosMeses({super.key, required this.limite});
  final LimiteMes limite;

  @override
  Widget build(BuildContext context) {
    final meses = limite.proximosMeses(5);
    final virada = meses.where((m) => m.limite >= 0).firstOrNull;
    return CartaoNB(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('VALOR DISPONÍVEL PARA OS ENVELOPES NOS PRÓXIMOS MESES', style: NBText.eyebrow),
        Text('Salário − contas do mês seguinte − parcelas que ainda faltam (sem receitas eventuais)', style: NBText.legenda),
        const SizedBox(height: 6),
        for (final m in meses)
          LinhaValorNB('${nomeMes(m.mes)[0].toUpperCase()}${nomeMes(m.mes).substring(1)}', m.limite, cor: _cor(m.limite)),
        const Divider(height: 12),
        Text(
          virada == null
              ? 'Nos próximos 5 meses continua negativo. Vale rever as contas fixas.'
              : 'Volta a ficar positivo em ${nomeMes(virada.mes)}.',
          style: NBText.rotulo.copyWith(color: virada == null ? NBColors.estouro : NBColors.verde),
        ),
      ]),
    );
  }
}
