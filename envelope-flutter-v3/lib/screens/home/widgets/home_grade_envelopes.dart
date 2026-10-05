import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/transacoes_provider.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../sheets/sheet_envelope.dart';
import '../../sheets/sheet_envelope_detalhe.dart';

class HomeGradeEnvelopes extends ConsumerWidget {
  const HomeGradeEnvelopes({super.key, required this.envelopes});
  final List<Map<String, dynamic>> envelopes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gastos = ref.watch(gastosPorEnvelopeNoMesProvider);
    return LayoutBuilder(
      builder: (context, c) {
        final colunas = c.maxWidth > 560 ? 3 : 2;
        final largura = (c.maxWidth - (colunas - 1) * NBSpacing.m) / colunas;
        return Wrap(
          spacing: NBSpacing.m,
          runSpacing: NBSpacing.m,
          children: [
            for (final env in envelopes)
              SizedBox(
                width: largura,
                child: CartaoEnvelope(
                  env: env,
                  gastoMes: gastos[env['id']] ?? 0.0,
                  onTap: () => abrirDetalheEnvelope(context, env['id'] as String),
                  onLongPress: () => abrirEnvelope(context, envelope: env),
                ),
              ),
          ],
        );
      },
    );
  }
}
