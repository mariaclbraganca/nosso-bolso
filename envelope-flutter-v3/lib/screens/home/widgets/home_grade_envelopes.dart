import 'package:flutter/material.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../sheets/sheet_abastecer.dart';
import '../../sheets/sheet_remanejar.dart';

class HomeGradeEnvelopes extends StatelessWidget {
  const HomeGradeEnvelopes({super.key, required this.envelopes});
  final List<Map<String, dynamic>> envelopes;

  int _ordem(Map<String, dynamic> e) => switch (NaturezaEnvelope.from(e)) {
        NaturezaEnvelope.consumo => 0,
        NaturezaEnvelope.reserva => 1,
        NaturezaEnvelope.objetivo => 2,
      };

  @override
  Widget build(BuildContext context) {
    final ordenados = [...envelopes]..sort((a, b) => _ordem(a).compareTo(_ordem(b)));
    return LayoutBuilder(
      builder: (context, c) {
        final colunas = c.maxWidth > 560 ? 3 : 2;
        final largura = (c.maxWidth - (colunas - 1) * NBSpacing.m) / colunas;
        return Wrap(
          spacing: NBSpacing.m,
          runSpacing: NBSpacing.m,
          children: [
            for (final env in ordenados)
              SizedBox(
                width: largura,
                child: CartaoEnvelope(
                  env: env,
                  onTap: () => EstadoEnvelope(env).estourado
                      ? abrirSheet(context, SheetRemanejar(destinoId: env['id'] as String))
                      : abrirSheet(context, SheetAbastecer(envelopeId: env['id'] as String)),
                ),
              ),
          ],
        );
      },
    );
  }
}
