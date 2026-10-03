import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/plano/plano_mes.dart';
import '../../core/providers/mes_provider.dart';
import '../../core/providers/plano_provider.dart';
import '../../core/services/api_service.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';
import '../sheets/comum.dart';
import 'widgets/plano_sheets.dart';

/// Plano do mês: planejado × realizado de entradas, contas, cartão e dia a dia,
/// e quanto precisa sair da reserva.
class PlanoMesTab extends ConsumerWidget {
  const PlanoMesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesAtualProvider);
    return ref.watch(planoMesProvider).when(
          loading: () => const UnicornCarregando(texto: 'Montando o plano do mês…'),
          error: (e, _) => UnicornErro(
            mensagem: 'Não consegui carregar o plano do mês.',
            onTentar: () {
              ref.invalidate(entradasMesProvider(mes));
              ref.invalidate(compromissosCartaoProvider);
            },
          ),
          data: (p) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(entradasMesProvider(mes));
              ref.invalidate(compromissosCartaoProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 4, NBSpacing.margemTela, 120),
              children: [
                ResumoPlano(plano: p),
                const SizedBox(height: NBSpacing.xl),
                _BlocoEntradas(plano: p),
                const SizedBox(height: NBSpacing.xl),
                _BlocoContas(plano: p),
                const SizedBox(height: NBSpacing.xl),
                _BlocoCartao(plano: p),
                const SizedBox(height: NBSpacing.xl),
                _BlocoDiaADia(plano: p),
                const SizedBox(height: NBSpacing.xl),
                ProjecaoPlano(plano: p),
              ],
            ),
          ),
        );
  }
}

Color _corResultado(double v) => v >= 0 ? NBColors.verde : NBColors.estouro;

/// Topo: como o mês fecha (previsto e com o que já aconteceu) e a reserva.
class ResumoPlano extends StatelessWidget {
  const ResumoPlano({super.key, required this.plano});
  final PlanoMes plano;

  @override
  Widget build(BuildContext context) {
    final proj = plano.resultadoProjetado;
    return CartaoNB(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COMO O MÊS FECHA', style: NBText.eyebrow),
          const SizedBox(height: NBSpacing.s),
          Row(
            children: [
              Expanded(child: _Numero('Planejado', plano.resultadoPrevisto)),
              Expanded(child: _Numero('Com o que já aconteceu', proj)),
            ],
          ),
          const Divider(height: NBSpacing.xl),
          Row(
            children: [
              UnicornWidget(
                type: proj >= 0 ? UnicornType.astrix : UnicornType.geronimo,
                size: 40,
                mood: proj >= 0 ? UnicornMood.celebrate : UnicornMood.focus,
              ),
              const SizedBox(width: NBSpacing.m),
              Expanded(
                child: Text(
                  proj >= 0
                      ? 'O mês fecha sem mexer na reserva. Sobram ${brl(proj)}.'
                      : plano.faltaDaReserva > 0
                          ? 'Precisa sair ${brl(plano.faltaDaReserva)} da reserva'
                              '${plano.resgatesReserva > 0 ? ' (além dos ${brl(plano.resgatesReserva)} já resgatados)' : ''}.'
                          : 'A reserva já cobriu o mês: ${brl(plano.resgatesReserva)} resgatados.',
                  style: NBText.rotulo.copyWith(color: proj >= 0 ? NBColors.verde : NBColors.tinta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero(this.rotulo, this.valor);
  final String rotulo;
  final double valor;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: NBText.legenda),
          Text(brl(valor, sinal: true), style: NBText.valorCartao.copyWith(color: _corResultado(valor))),
        ],
      );
}

/// Cabeçalho de bloco: título, previsto × realizado e ação opcional.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho(this.titulo, this.linha, {this.rotuloRealizado = 'realizado', this.acao});
  final String titulo;
  final Linha linha;
  final String rotuloRealizado;
  final Widget? acao;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: NBSpacing.s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: NBText.secao),
                  Text('${brl(linha.previsto)} previsto · ${brl(linha.realizado)} $rotuloRealizado', style: NBText.legenda),
                ],
              ),
            ),
            if (acao != null) acao!,
          ],
        ),
      );
}

class _BlocoEntradas extends ConsumerWidget {
  const _BlocoEntradas({required this.plano});
  final PlanoMes plano;

  Future<void> _marcar(WidgetRef ref, Map<String, dynamic> e, bool recebido) async {
    try {
      await ApiService.patch('/plano/entradas/${e['id']}', {'recebido': recebido});
      ref.invalidate(entradasMesProvider(plano.mes));
    } catch (err) {
      avisar(mensagemErro(err), erro: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Cabecalho(
          'Entradas',
          plano.totalEntradas,
          rotuloRealizado: 'recebido',
          acao: IconButton(
            tooltip: 'Nova entrada',
            onPressed: () => abrirSheet(context, SheetEntrada(mes: plano.mes)),
            icon: const Icon(Icons.add_circle_outline, color: NBColors.verde),
          ),
        ),
        if (plano.entradas.isEmpty)
          Text('Cadastre salário, aluguel recebido, vale… para o app saber quanto entra.', style: NBText.legenda),
        for (final e in plano.entradas)
          CartaoNB(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            onTap: () => abrirSheet(context, SheetEntrada(mes: plano.mes, entrada: e)),
            child: CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              controlAffinity: ListTileControlAffinity.leading,
              value: e['recebido'] == true,
              onChanged: (v) => _marcar(ref, e, v ?? false),
              title: Text(e['nome'] as String? ?? '', style: NBText.corpo),
              subtitle: Text(
                [
                  if (e['dia'] != null) 'dia ${e['dia']}',
                  if (e['tipo'] == 'vale') 'vale',
                  if (e['recebido'] == true && e['valor_recebido'] != null) 'recebeu ${brl(e['valor_recebido'] as num)}',
                ].join(' · '),
                style: NBText.legenda,
              ),
              secondary: Text(brl((e['valor'] as num?) ?? 0), style: NBText.rotulo),
            ),
          ),
      ],
    );
  }
}

class _BlocoContas extends StatelessWidget {
  const _BlocoContas({required this.plano});
  final PlanoMes plano;

  @override
  Widget build(BuildContext context) {
    final contas = [...plano.contas]..sort((a, b) => (a['pago'] == true ? 1 : 0) - (b['pago'] == true ? 1 : 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Cabecalho('Contas do mês', plano.totalContas, rotuloRealizado: 'pago'),
        if (contas.isEmpty) Text('Nenhuma conta neste mês (aba Contas).', style: NBText.legenda),
        for (final c in contas)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(c['pago'] == true ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    size: 18, color: c['pago'] == true ? NBColors.verde : NBColors.tintaSuave),
                const SizedBox(width: NBSpacing.s),
                Expanded(child: Text(c['nome'] as String? ?? '', style: NBText.corpo.copyWith(fontSize: 14))),
                Text(brl((c['valor'] as num?) ?? 0),
                    style: NBText.rotulo.copyWith(
                      color: c['pago'] == true ? NBColors.tintaSuave : NBColors.tinta,
                      decoration: c['pago'] == true ? TextDecoration.lineThrough : null,
                    )),
              ],
            ),
          ),
        Text('Marque como pago na aba Contas.', style: NBText.legenda),
      ],
    );
  }
}

class _BlocoCartao extends ConsumerWidget {
  const _BlocoCartao({required this.plano});
  final PlanoMes plano;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesFatura = plano.mesProximaFatura;
    final itens = itensDaFatura(plano.compromissos, mesFatura);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cartão · fatura de ${mesLabelLongo(mesFatura).toLowerCase()}', style: NBText.secao),
                  Text('vence dia 7 e paga o que for gasto neste mês', style: NBText.legenda),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Nova parcela ou assinatura',
              onPressed: () => abrirSheet(context, SheetCompromisso(mesFatura: mesFatura)),
              icon: const Icon(Icons.add_circle_outline, color: NBColors.verde),
            ),
          ],
        ),
        const SizedBox(height: NBSpacing.s),
        CartaoNB(
          child: Column(
            children: [
              _LinhaValor('Já comprometido (parcelas e assinaturas)', plano.cartaoComprometido),
              _LinhaValor('Compras no crédito neste mês', plano.gastoNoCartao),
              const Divider(),
              _LinhaValor('Fatura projetada', plano.proximaFaturaProjetada, destaque: true),
            ],
          ),
        ),
        const SizedBox(height: NBSpacing.s),
        for (final i in itens)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(i.descricao, style: NBText.corpo.copyWith(fontSize: 14))),
                Text(i.parcela == null ? 'todo mês' : '${i.parcela}/${i.total}', style: NBText.legenda),
                const SizedBox(width: NBSpacing.m),
                SizedBox(width: 92, child: Text(brl(i.valor), style: NBText.rotulo, textAlign: TextAlign.right)),
              ],
            ),
          ),
        if (itens.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompromissosScreen())),
            child: const Text('Gerenciar parcelas e assinaturas'),
          ),
      ],
    );
  }
}

class _LinhaValor extends StatelessWidget {
  const _LinhaValor(this.rotulo, this.valor, {this.destaque = false});
  final String rotulo;
  final double valor;
  final bool destaque;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(rotulo, style: destaque ? NBText.rotulo : NBText.corpo.copyWith(fontSize: 14))),
            Text(brl(valor), style: destaque ? NBText.valorCartao : NBText.rotulo),
          ],
        ),
      );
}

class _BlocoDiaADia extends StatelessWidget {
  const _BlocoDiaADia({required this.plano});
  final PlanoMes plano;

  @override
  Widget build(BuildContext context) {
    final envs = [...plano.envelopes]..sort((a, b) => plano.tetoDe(b).compareTo(plano.tetoDe(a)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Cabecalho('Dia a dia (envelopes)', plano.totalDiaADia, rotuloRealizado: 'gasto'),
        for (final e in envs)
          if (plano.tetoDe(e) > 0 || plano.gastoDe(e) > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('${e['emoji'] ?? '✉️'} ', style: const TextStyle(fontSize: 14)),
                      Expanded(child: Text(e['nome_envelope'] as String? ?? '', style: NBText.corpo.copyWith(fontSize: 14))),
                      Text('${brl(plano.gastoDe(e))} de ${brl(plano.tetoDe(e))}',
                          style: NBText.legenda.copyWith(
                              color: plano.gastoDe(e) > plano.tetoDe(e) ? NBColors.estouro : NBColors.tintaSuave)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  BarraProgresso(
                    fracao: plano.tetoDe(e) > 0 ? plano.gastoDe(e) / plano.tetoDe(e) : 1,
                    cor: plano.gastoDe(e) > plano.tetoDe(e) ? NBColors.estouro : NBColors.verde,
                  ),
                ],
              ),
            ),
        Text('O teto de cada envelope é o valor planejado (botão Planejar, na Home).', style: NBText.legenda),
      ],
    );
  }
}

/// Próximos meses: quando o mês volta a fechar sozinho.
class ProjecaoPlano extends StatelessWidget {
  const ProjecaoPlano({super.key, required this.plano});
  final PlanoMes plano;

  @override
  Widget build(BuildContext context) {
    final meses = plano.projecao(6);
    final virada = meses.where((m) => m.resultado >= 0).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Próximos meses', style: NBText.secao),
        Text('Repetindo entradas e contas fixas, os mesmos tetos e as parcelas que ainda faltam.', style: NBText.legenda),
        const SizedBox(height: NBSpacing.s),
        CartaoNB(
          child: Column(
            children: [
              for (final m in meses)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 96, child: Text(mesLabelLongo(m.mes), style: NBText.corpo.copyWith(fontSize: 14))),
                      Expanded(child: Text('cartão ${brl(m.cartao)}', style: NBText.legenda)),
                      Text(brl(m.resultado, sinal: true), style: NBText.rotulo.copyWith(color: _corResultado(m.resultado))),
                    ],
                  ),
                ),
              if (meses.isNotEmpty) ...[
                const Divider(),
                Text(
                  virada == null
                      ? 'Nos próximos 6 meses ainda falta todo mês. Vale rever os tetos ou as contas.'
                      : virada == meses.first
                          ? 'A partir de ${mesLabelLongo(virada.mes).toLowerCase()} o mês já fecha sozinho.'
                          : 'O mês volta a fechar sozinho em ${mesLabelLongo(virada.mes).toLowerCase()}.',
                  style: NBText.rotulo.copyWith(color: virada == null ? NBColors.estouro : NBColors.verde),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
