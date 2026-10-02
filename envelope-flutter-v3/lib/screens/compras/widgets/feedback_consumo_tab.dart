import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/compras_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';
import '../../sheets/comum.dart';

class FeedbackConsumoTab extends ConsumerWidget {
  const FeedbackConsumoTab({super.key});

  /// status: 'acabou' | 'em_consumo' (ainda tem) | 'estragou'
  Future<void> _enviarFeedback(WidgetRef ref, Map<String, dynamic> item, String status) async {
    try {
      await ApiService.patch('/api/v1/compras/feedback', {
        'compra_id': item['compra_id'],
        'nome_padronizado': item['nome_padronizado'],
        'status': status,
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
                      item['nome_padronizado'] as String? ?? 'Produto',
                      style: NBText.secao,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _compradoHa(item['data_compra'] as String?),
                      style: NBText.legenda,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _enviarFeedback(ref, item, 'acabou'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: NBColors.verde,
                              side: const BorderSide(color: NBColors.verde),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Acabou'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _enviarFeedback(ref, item, 'em_consumo'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: NBColors.tinta,
                              side: const BorderSide(color: NBColors.linha),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Ainda tem'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _enviarFeedback(ref, item, 'estragou'),
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

  static String _compradoHa(String? data) {
    final d = DateTime.tryParse(data ?? '');
    if (d == null) return 'Compra anterior';
    final dias = DateTime.now().difference(d).inDays;
    return dias <= 1 ? 'Comprado ontem' : 'Comprado há $dias dias';
  }
}
