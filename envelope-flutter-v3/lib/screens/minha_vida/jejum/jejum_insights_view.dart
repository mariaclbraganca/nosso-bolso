import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/jejum_provider.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';

/// Leitura da semana feita pela IA. No jejum só falam Sweet e Happy.
class JejumInsightsView extends ConsumerWidget {
  const JejumInsightsView({super.key, required this.membroId});
  final String membroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(jejumInsightsProvider(membroId)).when(
          loading: () => const UnicornCarregando(type: UnicornType.happy, texto: 'Pensando na sua semana…'),
          error: (e, _) => UnicornErro(
            mensagem: 'Não consegui gerar os insights agora.',
            onTentar: () => ref.invalidate(jejumInsightsProvider(membroId)),
          ),
          data: (d) {
            final principal = d['insight_principal'] as String?;
            final insights = ((d['insights'] as List?) ?? const []).cast<Map<String, dynamic>>();
            final sugestao = d['sugestao'] as String?;
            final msg = (d['mensagem_unicornio'] as Map?) ?? const {};
            final quem = msg['unicornio'] == 'sweet' ? UnicornType.sweet : UnicornType.happy;

            return ListView(
              padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
              children: [
                if (msg['texto'] != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      UnicornWidget(type: quem, size: 72, mood: quem == UnicornType.sweet ? UnicornMood.love : UnicornMood.focus),
                      const SizedBox(width: NBSpacing.s),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 28),
                          child: UnicornFala(type: quem, texto: msg['texto'] as String, maxWidth: double.infinity),
                        ),
                      ),
                    ],
                  ),
                if (principal != null) ...[
                  const SizedBox(height: NBSpacing.l),
                  PainelIA(titulo: 'Seu padrão', texto: principal),
                ],
                for (final i in insights) ...[
                  const SizedBox(height: NBSpacing.m),
                  CartaoNB(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i['icone'] as String? ?? '✨', style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: NBSpacing.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(i['titulo'] as String? ?? '', style: NBText.rotulo.copyWith(fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(i['texto'] as String? ?? '', style: NBText.corpo.copyWith(fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (sugestao != null) ...[
                  const SizedBox(height: NBSpacing.l),
                  Container(
                    padding: const EdgeInsets.all(NBSpacing.l),
                    decoration: BoxDecoration(color: NBColors.lavandaClara, borderRadius: BorderRadius.circular(NBRadius.cartao)),
                    child: Text('Sugestão: $sugestao', style: NBText.corpo.copyWith(fontSize: 14)),
                  ),
                ],
              ],
            );
          },
        );
  }
}
