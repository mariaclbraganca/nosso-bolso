import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/fechamento_provider.dart';
import '../../core/providers/mes_provider.dart';
import '../../core/services/api_service.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';

/// Retrospectiva de um mês fechado: o que entrou, o que saiu, o resultado e,
/// se o mês fechou no negativo, quanto foi coberto por fora.
class RetrospectivaScreen extends ConsumerStatefulWidget {
  const RetrospectivaScreen({super.key, this.mes});

  /// 'YYYY-MM'. Sem valor, abre o mês anterior (o último normalmente fechado).
  final String? mes;

  @override
  ConsumerState<RetrospectivaScreen> createState() => _RetrospectivaScreenState();
}

class _RetrospectivaScreenState extends ConsumerState<RetrospectivaScreen> {
  late String _mes = widget.mes ?? mesAnterior(ref.read(mesAtualProvider));

  double _n(Map d, String k) => (d[k] as num?)?.toDouble() ?? 0;

  bool _naoFechado(Object e) => e is ApiException && e.statusCode == 404;

  @override
  Widget build(BuildContext context) {
    final retro = ref.watch(retrospectivaProvider(_mes));
    final visao = ref.watch(visaoMesProvider(_mes)).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text('Retrospectiva · ${mesLabelLongo(_mes)}'),
        actions: [
          IconButton(
            tooltip: 'Mês anterior',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => setState(() => _mes = mesAnterior(_mes)),
          ),
          IconButton(
            tooltip: 'Próximo mês',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => setState(() => _mes = mesProximo(_mes)),
          ),
        ],
      ),
      body: retro.when(
        loading: () => const UnicornCarregando(texto: 'Lembrando como foi o mês…'),
        error: (e, _) => UnicornVazio(
          titulo: _naoFechado(e) ? 'Este mês ainda não foi fechado' : 'Não consegui carregar',
          texto: _naoFechado(e)
              ? 'A retrospectiva aparece depois de "Fechar mês" em Planos.'
              : 'Verifique a internet e tente de novo.',
          acao: () => setState(() => _mes = mesAnterior(_mes)),
          rotuloAcao: 'Ver o mês anterior',
        ),
        data: (d) {
          final receita = _n(d, 'receita_total');
          final consumo = _n(d, 'total_consumo');
          final compromisso = _n(d, 'total_compromisso');
          final resultado = _n(d, 'resultado_mes');
          final coberto = _n(d, 'coberto_por_fora');
          final parcelasRestantes = _n(d, 'parcelas_restantes_valor');
          final azul = resultado >= 0;
          final envelopes = ((visao?['envelopes'] as List?) ?? const [])
              .cast<Map<String, dynamic>>()
              .where((e) => (e['natureza'] ?? 'consumo') == 'consumo' && _n(e, 'valor_planejado') > 0)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
            children: [
              Container(
                padding: const EdgeInsets.all(NBSpacing.xl),
                decoration: BoxDecoration(
                  color: azul ? NBColors.verde : NBColors.estouro,
                  borderRadius: BorderRadius.circular(NBRadius.destaque),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mesLabelLongo(_mes).split(' ').first + (azul ? ' fechou no azul' : ' fechou no vermelho'),
                        style: NBText.rotulo.copyWith(color: Colors.white70)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(brl(resultado, sinal: true), style: NBText.saldo.copyWith(color: Colors.white)),
                    ),
                    if (!azul && coberto > 0)
                      Text('${brl(coberto)} foram cobertos por fora para honrar as contas.',
                          style: NBText.corpo.copyWith(color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(height: NBSpacing.l),
              CartaoNB(
                child: Column(
                  children: [
                    LinhaPrevia(rotulo: 'Receitas', valor: receita, corValor: NBColors.verde),
                    LinhaPrevia(rotulo: 'Despesas por envelope', valor: -consumo),
                    LinhaPrevia(rotulo: 'Contas fixas e parcelas', valor: -compromisso),
                    const Divider(height: 16),
                    LinhaPrevia(rotulo: 'Resultado do mês', valor: resultado, corValor: NBColors.verde),
                    if (parcelasRestantes > 0)
                      LinhaPrevia(rotulo: 'Parcelas que ainda faltam', valor: -parcelasRestantes),
                  ],
                ),
              ),
              if (envelopes.isNotEmpty) ...[
                const SizedBox(height: NBSpacing.xl),
                Text('Orçado × realizado', style: NBText.secao),
                const SizedBox(height: NBSpacing.s),
                for (final e in envelopes) _LinhaEnvelope(e: e),
              ],
              if (!azul) ...[
                const SizedBox(height: NBSpacing.l),
                const PainelIA(
                  texto: 'Para o próximo mês fechar no azul, olhe os envelopes que mais passaram do '
                      'planejado e ajuste o plano. Cada real que sobra vira reserva.',
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LinhaEnvelope extends StatelessWidget {
  const _LinhaEnvelope({required this.e});
  final Map<String, dynamic> e;

  @override
  Widget build(BuildContext context) {
    final plan = (e['valor_planejado'] as num?)?.toDouble() ?? 0;
    final gasto = (e['total_gasto'] as num?)?.toDouble() ?? 0;
    final passou = gasto - plan;
    return Padding(
      padding: const EdgeInsets.only(bottom: NBSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(e['nome_envelope'] as String? ?? 'Envelope', style: NBText.rotulo)),
              Text('${brl(gasto, curto: true)} / ${brl(plan, curto: true)}', style: NBText.legenda),
            ],
          ),
          const SizedBox(height: 4),
          BarraProgresso(
            fracao: plan > 0 ? gasto / plan : 0,
            cor: passou > 0 ? NBColors.estouro : (gasto > plan * 0.85 ? NBColors.ambarBarra : NBColors.verde),
          ),
          if (passou > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Passou ${brl(passou)}', style: NBText.legenda.copyWith(color: NBColors.estouro)),
            ),
        ],
      ),
    );
  }
}
