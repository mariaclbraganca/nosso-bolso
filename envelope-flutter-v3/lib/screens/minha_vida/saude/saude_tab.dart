import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nosso_bolso_v3/core/providers/saude_provider.dart';
import 'package:nosso_bolso_v3/ui/components/nb_components.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';
import 'package:nosso_bolso_v3/ui/unicorn/unicorn.dart';
import 'widgets/hidratacao_card.dart';
import 'widgets/refeicoes_card.dart';

class SaudeTab extends ConsumerWidget {
  final String membroId;
  final String familiaId;

  const SaudeTab({
    super.key,
    required this.membroId,
    required this.familiaId,
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

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(extratoDiarioProvider);
        ref.invalidate(hidratacaoDiaProvider);
        ref.invalidate(refeicoesDiaProvider);
        ref.invalidate(streakProvider);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Resumo de Calorias & Streak ──
          CartaoNB(
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
                const Row(
                  children: [
                    UnicornWidget(type: UnicornType.happy, size: 40, mood: UnicornMood.focus),
                    SizedBox(width: 8),
                    Expanded(
                      child: UnicornFala(
                        type: UnicornType.happy,
                        texto: 'Comida boa alimenta o corpo e a mente!',
                      ),
                    ),
                  ],
                ),
              ],
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

          // ── Refeições ──
          RefeicoesCard(
            membroId: membroId,
            familiaId: familiaId,
            data: hoje,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
