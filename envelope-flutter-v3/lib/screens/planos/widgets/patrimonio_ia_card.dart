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
                  ],
                ),
                const SizedBox(height: 12),
                Text(analise.resumo, style: NBText.corpo),
                if (analise.sugestoes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Text('RECOMENDAÇÕES:', style: NBText.eyebrow),
                  const SizedBox(height: 6),
                  for (final sug in analise.sugestoes.take(2))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: NBColors.verde, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              '${sug.titulo}: ${sug.descricao}',
                              style: NBText.legenda,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

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
