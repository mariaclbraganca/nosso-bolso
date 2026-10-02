import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/transacoes_provider.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../sheets/sheet_abastecer.dart';
import '../../sheets/sheet_remanejar.dart';

class HomeGradeEnvelopes extends ConsumerWidget {
  const HomeGradeEnvelopes({super.key, required this.envelopes});
  final List<Map<String, dynamic>> envelopes;

  int _ordem(Map<String, dynamic> e) => switch (NaturezaEnvelope.from(e)) {
        NaturezaEnvelope.consumo => 0,
        NaturezaEnvelope.reserva => 1,
        NaturezaEnvelope.objetivo => 2,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gastos = ref.watch(gastosPorEnvelopeNoMesProvider);
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
                  gastoMes: gastos[env['id']] ?? 0.0,
                  onTap: () => EstadoEnvelope(env, gastoMes: gastos[env['id']] ?? 0.0).estourado
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

