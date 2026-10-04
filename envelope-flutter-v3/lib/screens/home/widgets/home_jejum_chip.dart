import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/jejum_provider.dart';
import '../../../core/providers/usuarios_provider.dart';
import '../../../core/services/app_navigator.dart';
import '../../../ui/theme/nb_theme.dart';

/// Chip discreto com o jejum em andamento; toque abre Minha Vida › Jejum.
/// Só mostra tempo e fase — nada de finanças cruza para o jejum.
class HomeJejumChip extends ConsumerWidget {
  const HomeJejumChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membroId = ref.watch(perfilUsuarioLogadoProvider).valueOrNull?['id'] as String?;
    if (membroId == null) return const SizedBox.shrink();
    final ativo = ref.watch(jejumAtivoProvider(membroId)).valueOrNull;
    final inicio = DateTime.tryParse(ativo?['iniciado_em']?.toString() ?? '')?.toLocal();
    if (inicio == null) return const SizedBox.shrink();
    // Atualiza o tempo a cada minuto.
    return StreamBuilder<void>(
      stream: Stream.periodic(const Duration(minutes: 1)),
      builder: (context, _) => JejumChip(
        decorrido: DateTime.now().difference(inicio),
        metaHoras: (ativo!['meta_horas'] as num?)?.toDouble() ?? 16,
        onTap: () => abrirDestino(Destino.jejum),
      ),
    );
  }
}

class JejumChip extends StatelessWidget {
  const JejumChip({super.key, required this.decorrido, required this.metaHoras, required this.onTap});
  final Duration decorrido;
  final double metaHoras;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fase = FaseMetabolica.atual(decorrido);
    final tempo = '${decorrido.inHours}h${(decorrido.inMinutes % 60).toString().padLeft(2, '0')}';
    final pronto = decorrido.inMinutes >= metaHoras * 60;
    return Padding(
      padding: const EdgeInsets.only(bottom: NBSpacing.s),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: NBColors.lavandaClara,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                pronto ? '✨ Jejum de $tempo · meta alcançada!' : '${fase.emoji} Jejum $tempo · ${fase.nome}',
                style: NBText.rotulo.copyWith(fontSize: 13, color: NBColors.lavanda),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
