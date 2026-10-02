import 'package:flutter/material.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';

Future<Map<String, dynamic>?> mostrarModalEscolhaEnvelope({
  required BuildContext context,
  required String estabelecimento,
  required List<Map<String, dynamic>> envelopes,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(NBSpacing.l, 0, NBSpacing.l, NBSpacing.l),
        children: [
          TopoSheet(titulo: estabelecimento, subtitulo: 'Em qual envelope entra?'),
          const SizedBox(height: NBSpacing.m),
          for (final e in envelopes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 6, backgroundColor: NaturezaEnvelope.from(e).forte),
              title: Text(e['nome_envelope'] as String? ?? '', style: NBText.corpo),
              trailing: Text(
                brl((e['saldo_atual'] as num?) ?? 0),
                style: NBText.corpo.copyWith(color: NBColors.tintaSuave),
              ),
              onTap: () => Navigator.pop(ctx, {'id': e['id'], 'nome': e['nome_envelope']}),
            ),
        ],
      ),
    ),
  );
}
