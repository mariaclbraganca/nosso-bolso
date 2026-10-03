import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/patrimonio_provider.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';

class PatrimonioIaCard extends ConsumerWidget {
  const PatrimonioIaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analiseAsync = ref.watch(patrimonioAnaliseProvider);

    return analiseAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(color: NBColors.verde, backgroundColor: NBColors.afundado),
      ),
      error: (_, __) => const _FallbackCard(),
      data: (analise) {
        if (analise.resumo.isEmpty) return const _FallbackCard();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: CartaoNB(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const UnicornWidget(type: UnicornType.astrix, size: 28, animate: false),
                    const SizedBox(width: 8),
                    Text('ANÁLISE DO ASTRIX', style: NBText.eyebrow),
                    const Spacer(),
                    SeloNB(
                      'NOTA ${analise.notaGeral.toStringAsFixed(1)}',
                      cor: NBColors.verde,
                      fundo: NBColors.verdeClaro,
                    ),
                    IconButton(
                      tooltip: 'Analisar de novo',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref.invalidate(patrimonioAnaliseProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: NBColors.tintaSuave),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(analise.resumo, style: NBText.corpo),
                for (final p in analise.pontosPositivos)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('✓ $p', style: NBText.legenda.copyWith(color: NBColors.verde)),
                  ),
                for (final a in analise.alertas)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('⚠ $a', style: NBText.legenda.copyWith(color: NBColors.ambarTexto)),
                  ),
                if (analise.sugestoes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Text('SUGESTÕES', style: NBText.eyebrow),
                  for (final sug in analise.sugestoes)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(sug.titulo, style: NBText.rotulo.copyWith(fontSize: 14))),
                              SeloNB(rotuloUrgencia(sug.urgencia),
                                  cor: sug.urgencia == 'agora' ? NBColors.ambarTexto : NBColors.tintaSuave,
                                  fundo: sug.urgencia == 'agora' ? NBColors.ambarClaro : NBColors.afundado),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(sug.descricao, style: NBText.legenda),
                        ],
                      ),
                    ),
                ],
                if (analise.distribuicaoIdeal.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Distribuição sugerida: ${analise.distribuicaoIdeal}', style: NBText.legenda),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

String rotuloUrgencia(String u) => switch (u) {
      'agora' => 'Agora',
      'proximo_mes' => 'Próximo mês',
      _ => 'Sem pressa',
    };

class _FallbackCard extends StatelessWidget {
  const _FallbackCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CartaoNB(
        child: Row(
          children: [
            const UnicornWidget(type: UnicornType.astrix, size: 28, animate: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ANÁLISE PATRIMONIAL', style: NBText.eyebrow),
                  const SizedBox(height: 4),
                  Text(
                    'Cadastre seus investimentos e contas para obter insights de diversificação.',
                    style: NBText.legenda,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
