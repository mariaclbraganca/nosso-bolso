import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nosso_bolso_v3/core/providers/saude_provider.dart';
import 'package:nosso_bolso_v3/core/providers/usuarios_provider.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';
import 'exercicio/exercicio_tab.dart';
import 'jejum/jejum_tab.dart';
import 'saude/saude_tab.dart';

/// Segmento aberto em Minha Vida (0 Saúde, 1 Exercício, 2 Jejum). Global para
/// a Home abrir direto no Jejum pelo chip.
final segmentoMinhaVidaProvider = StateProvider<int>((ref) => 0);

class MinhaVidaScreen extends ConsumerStatefulWidget {
  const MinhaVidaScreen({super.key});

  @override
  ConsumerState<MinhaVidaScreen> createState() => _MinhaVidaScreenState();
}

class _MinhaVidaScreenState extends ConsumerState<MinhaVidaScreen> {

  static const _segmentos = [
    ('🌿', 'Saúde'),
    ('💪', 'Exercício'),
    ('⏱️', 'Jejum'),
  ];

  @override
  Widget build(BuildContext context) {
    final segmento = ref.watch(segmentoMinhaVidaProvider);
    final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
    final membros = ref.watch(listaUsuariosProvider).asData?.value ?? [];
    final membroId = ref.watch(membroSaudeProvider) ?? perfil?['id'] as String? ?? '';
    final familiaId = perfil?['familia_id'] as String? ?? '';

    final membroNome = membros
        .where((m) => m['id'] == membroId)
        .map((m) => m['nome'] as String? ?? '')
        .firstOrNull ?? 'Eu';

    return Scaffold(
      backgroundColor: NBColors.papel,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text('Minha Vida', style: NBText.secao),
                  const Spacer(),
                  if (membros.length > 1)
                    PopupMenuButton<String>(
                      initialValue: membroId,
                      onSelected: (id) => ref.read(membroSaudeProvider.notifier).state = id,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: NBColors.afundado,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_rounded, size: 16, color: NBColors.tinta),
                            const SizedBox(width: 4),
                            Text(membroNome, style: NBText.legenda.copyWith(color: NBColors.tinta)),
                          ],
                        ),
                      ),
                      itemBuilder: (_) => membros.map((m) {
                        return PopupMenuItem(
                          value: m['id'] as String,
                          child: Text(m['nome'] as String? ?? ''),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),

            // ── Seletor de Segmentos ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: List.generate(_segmentos.length, (i) {
                  final sel = segmento == i;
                  final item = _segmentos[i];
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: i > 0 ? 4 : 0,
                        right: i < _segmentos.length - 1 ? 4 : 0,
                      ),
                      child: InkWell(
                        onTap: () => ref.read(segmentoMinhaVidaProvider.notifier).state = i,
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? NBColors.tinta : NBColors.afundado,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${item.$1} ${item.$2}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                              color: sel ? NBColors.papel : NBColors.tintaSuave,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 6),

            // ── Conteúdo do Segmento ──
            Expanded(
              child: switch (segmento) {
                0 => SaudeTab(membroId: membroId, familiaId: familiaId),
                1 => ExercicioTab(membroId: membroId, familiaId: familiaId),
                _ => JejumTab(membroId: membroId, familiaId: familiaId),
              },
            ),
          ],
        ),
      ),
    );
  }
}
