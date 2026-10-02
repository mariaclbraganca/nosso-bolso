import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/envelopes_provider.dart';
import '../../../core/providers/insights_provider.dart';
import '../../../core/providers/mes_provider.dart';
import '../../../core/services/app_navigator.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';

class HomeFalaDoTime extends ConsumerWidget {
  const HomeFalaDoTime({super.key, required this.envelopes});
  final List<Map<String, dynamic>> envelopes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (envelopes.isEmpty) return const SizedBox.shrink();
    final saldo = ref.watch(saldoGeralProvider).value ?? 0;
    final estados = envelopes.map(EstadoEnvelope.new).toList();
    final estourados = estados
        .where((e) => e.estourado && e.natureza == NaturezaEnvelope.consumo)
        .toList();
    final noLimite = estados.where((e) => e.noLimite).toList();

    final (UnicornType tipo, UnicornMood humor, String fala) = switch (()) {
      _ when estourados.length == 1 => (
          UnicornType.geronimo,
          UnicornMood.chaos,
          '${estourados.first.nome} estourou. Toque nele para cobrir com outro envelope.'
        ),
      _ when estourados.length > 1 => (
          UnicornType.geronimo,
          UnicornMood.chaos,
          '${estourados.length} envelopes estouraram. Bora remanejar antes que cresça.'
        ),
      _ when noLimite.isNotEmpty => (
          UnicornType.astrix,
          UnicornMood.thinking,
          '${noLimite.first.nome} está no limite. Segura até o fim do mês.'
        ),
      _ when saldo > 0 => (
          UnicornType.astrix,
          UnicornMood.wave,
          'Tem ${brl(saldo)} no saldo geral esperando um envelope.'
        ),
      _ => (
          UnicornType.astrix,
          UnicornMood.idle,
          'Tudo nos trilhos. Os envelopes estão saudáveis.'
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: NBSpacing.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          UnicornWidget(key: ValueKey(tipo), type: tipo, mood: humor, size: 80),
          const SizedBox(width: NBSpacing.s),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 34),
              child: UnicornFala(type: tipo, texto: fala, maxWidth: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeAlertaIA extends ConsumerWidget {
  const HomeAlertaIA({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesAtualProvider);
    final insights = ref.watch(insightsProvider(mes)).value ?? const [];
    final alerta = insights
        .cast<Map>()
        .where((i) => (i['titulo'] as String? ?? '').startsWith('Alerta'))
        .firstOrNull;
    if (alerta == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: NBSpacing.s),
      child: PainelIA(
        titulo: alerta['titulo'] as String?,
        texto: alerta['texto'] as String? ?? '',
        onTap: () => navegarParaAba(navPlanos),
      ),
    );
  }
}
