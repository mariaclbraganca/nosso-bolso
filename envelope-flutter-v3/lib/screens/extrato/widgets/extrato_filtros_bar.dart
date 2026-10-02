import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/envelopes_provider.dart';
import '../../../core/providers/usuarios_provider.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';

/// Barra de filtros rápidos para a listagem do extrato
class ExtratoFiltrosBar extends ConsumerWidget {
  final String? envelopeFiltroId;
  final String? usuarioFiltroId;
  final ValueChanged<String?> onEnvelopeChanged;
  final ValueChanged<String?> onUsuarioChanged;

  const ExtratoFiltrosBar({
    super.key,
    required this.envelopeFiltroId,
    required this.usuarioFiltroId,
    required this.onEnvelopeChanged,
    required this.onUsuarioChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envelopes = ref.watch(envelopesViseisProvider);
    final membros = ref.watch(listaUsuariosProvider).value ?? [];

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: NBSpacing.margemTela),
        children: [
          ChipNB(
            rotulo: 'Todos',
            selecionado: envelopeFiltroId == null && usuarioFiltroId == null,
            onTap: () {
              onEnvelopeChanged(null);
              onUsuarioChanged(null);
            },
          ),
          if (membros.length > 1) ...[
            const SizedBox(width: 8),
            for (final m in membros)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChipNB(
                  rotulo: (m['nome'] as String? ?? '').split(' ').first,
                  selecionado: usuarioFiltroId == m['id'],
                  icone: const Icon(Icons.person_outline_rounded, size: 14, color: NBColors.tintaSuave),
                  onTap: () {
                    onUsuarioChanged(usuarioFiltroId == m['id'] ? null : m['id']);
                  },
                ),
              ),
          ],
          if (envelopes.isNotEmpty) ...[
            for (final e in envelopes)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChipNB(
                  rotulo: e['nome_envelope'] as String? ?? '',
                  selecionado: envelopeFiltroId == e['id'],
                  icone: Text(e['emoji'] as String? ?? '📦', style: const TextStyle(fontSize: 12)),
                  onTap: () {
                    onEnvelopeChanged(envelopeFiltroId == e['id'] ? null : e['id']);
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}
