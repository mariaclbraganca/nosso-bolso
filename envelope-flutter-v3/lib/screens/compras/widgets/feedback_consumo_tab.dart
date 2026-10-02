import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/compras_provider.dart';
import '../../../core/providers/usuarios_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';
import '../../sheets/comum.dart';

class FeedbackConsumoTab extends ConsumerWidget {
  const FeedbackConsumoTab({super.key});

  Future<void> _enviarFeedback(
    WidgetRef ref,
    String itemId,
    double pctConsumido,
  ) async {
    final perfil = ref.read(perfilUsuarioLogadoProvider).value;
    final familiaId = perfil?['familia_id'] as String? ?? '';

    try {
      await ApiService.patch('/api/v1/compras/feedback', {
        'familia_id': familiaId,
        'item_id': itemId,
        'pct_consumido': pctConsumido,
      });

      ref.invalidate(feedbackPendenteProvider);
      avisar('Feedback registrado! Isso refina sua lista inteligente.');
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendentesAsync = ref.watch(feedbackPendenteProvider);

    return pendentesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: NBColors.verde)),
      error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: NBColors.estouro))),
      data: (itens) {
        if (itens.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: UnicornVazio(
              type: UnicornType.happy,
              titulo: 'Nenhum feedback pendente',
              texto: 'A IA avisa quando produtos de compras anteriores atingem o tempo estimado de consumo.',
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 12, NBSpacing.margemTela, 120),
          children: [
            CartaoNB(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CALIBRAÇÃO DE DESPENSA', style: NBText.eyebrow),
                  const SizedBox(height: 6),
                  Text(
                    'Ajude a IA a entender o ritmo de consumo da sua casa para evitar desperdícios.',
                    style: NBText.legenda,
                  ),
                ],
              ),
            ),
            const SizedBox(height: NBSpacing.l),
            const CabecalhoSecao(titulo: 'Como foi o consumo?'),
            const SizedBox(height: NBSpacing.s),
            for (final item in itens) ...[
              CartaoNB(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['nome_produto'] as String? ?? item['nome'] as String? ?? 'Produto',
                      style: NBText.secao,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Comprado há cerca de ${item['dias_passados'] ?? 7} dias',
                      style: NBText.legenda,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _enviarFeedback(ref, item['id'] as String? ?? item['_id'] as String, 1.0),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: NBColors.verde,
                              side: const BorderSide(color: NBColors.verde),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Consumiu tudo'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _enviarFeedback(ref, item['id'] as String? ?? item['_id'] as String, 0.5),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: NBColors.tinta,
                              side: const BorderSide(color: NBColors.linha),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Sobrou parte'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _enviarFeedback(ref, item['id'] as String? ?? item['_id'] as String, 0.0),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: NBColors.estouro,
                              side: const BorderSide(color: NBColors.estouroClaro),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Estragou'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}
