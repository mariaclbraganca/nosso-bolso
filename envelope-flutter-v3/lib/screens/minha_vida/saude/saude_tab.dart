import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nosso_bolso_v3/core/providers/saude_provider.dart';
import 'package:nosso_bolso_v3/ui/components/nb_components.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';
import 'package:nosso_bolso_v3/core/plano/falas.dart';
import 'package:nosso_bolso_v3/screens/home/widgets/home_fala_time.dart';
import 'historico_saude_screen.dart';
import 'perfil_metabolico_screen.dart';
import 'sugestao_jantar_screen.dart';
import 'widgets/macros_peso_cards.dart';
import 'widgets/hidratacao_card.dart';
import 'widgets/refeicoes_card.dart';

class SaudeTab extends ConsumerWidget {
  final String membroId;
  final String familiaId;

  /// false = as refeições ficam numa aba própria (módulo Alimentação).
  final bool comRefeicoes;

  const SaudeTab({
    super.key,
    required this.membroId,
    required this.familiaId,
    this.comRefeicoes = true,
  });

  String get _hoje {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoje = _hoje;
    final args = (membroId: membroId, data: hoje);
    final extratoAsync = ref.watch(extratoDiarioProvider(args));
    final streakAsync = ref.watch(streakProvider(membroId));

    final calIngeridas = extratoAsync.asData?.value['calorias_consumidas_kcal'] as num? ?? 0;
    final calMeta = extratoAsync.asData?.value['meta_calorica_kcal'] as num? ?? 2000;
    final streak = streakAsync.asData?.value ?? 1;
    final temPlano = ref.watch(perfilMetabolicoProvider(membroId)).valueOrNull != null;
    void abrirPlano() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PerfilMetabolicoScreen(membroId: membroId)),
        );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(extratoDiarioProvider);
        ref.invalidate(hidratacaoDiaProvider);
        ref.invalidate(refeicoesDiaProvider);
        ref.invalidate(streakProvider);
        ref.invalidate(historicoPesoProvider);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Resumo de Calorias & Streak ──
          CartaoNB(
            onTap: abrirPlano,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Meta Diária', style: NBText.legenda),
                    const Spacer(),
                    if (streak > 0)
                      SeloNB(
                        '🔥 $streak ${streak == 1 ? "dia" : "dias"}',
                        cor: NBColors.ambarTexto,
                        fundo: NBColors.afundado,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${calIngeridas.toInt()} / ${calMeta.toInt()} kcal',
                  style: NBText.valorCartao,
                ),
                const SizedBox(height: 4),
                Text(
                  calIngeridas <= calMeta
                      ? '${(calMeta - calIngeridas).toInt()} kcal restantes'
                      : '${(calIngeridas - calMeta).toInt()} kcal além da meta',
                  style: NBText.legenda.copyWith(
                    color: calIngeridas <= calMeta ? NBColors.verde : NBColors.ambarTexto,
                  ),
                ),
                const SizedBox(height: 12),
                FalaCurta(
                  fala: falaDaAlimentacao(
                    kcal: calIngeridas.toDouble(),
                    metaKcal: calMeta.toDouble(),
                    proteina: (extratoAsync.asData?.value['proteina_consumida_g'] as num?)?.toDouble() ?? 0,
                    metaProteina: (extratoAsync.asData?.value['proteina_meta_g'] as num?)?.toDouble() ?? 0,
                  ),
                ),
              ],
            ),
          ),
          if (!temPlano) ...[
            const SizedBox(height: 12),
            PainelIA(
              titulo: 'Sua meta ainda é genérica',
              texto: 'Monte seu plano (idade, peso, altura e rotina) para eu calcular calorias e proteínas certas para você.',
              onTap: abrirPlano,
            ),
          ],
          const SizedBox(height: 12),
          MacrosCard(extrato: extratoAsync.valueOrNull),
          const SizedBox(height: 12),
          PesoCard(
            membroId: membroId,
            onHistorico: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => HistoricoSaudeScreen(membroId: membroId)),
            ),
          ),
          const SizedBox(height: 12),

          // ── Hidratação ──
          HidratacaoCard(
            membroId: membroId,
            familiaId: familiaId,
            data: hoje,
          ),
          const SizedBox(height: 12),

          CartaoNB(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SugestaoJantarScreen(membroId: membroId, familiaId: familiaId),
            )),
            child: Row(
              children: [
                const Text('🍽️', style: TextStyle(fontSize: 26)),
                const SizedBox(width: NBSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Jantar com o que tem em casa', style: NBText.rotulo.copyWith(fontSize: 15)),
                      Text('Sugestões a partir do estoque e do que falta de proteína hoje', style: NBText.legenda),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: NBColors.tintaSuave),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Refeições ──
          if (comRefeicoes) RefeicoesCard(membroId: membroId, familiaId: familiaId, data: hoje),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
