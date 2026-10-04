import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/providers/jejum_provider.dart';
import 'package:nosso_bolso_v3/core/providers/usuarios_provider.dart';
import 'package:nosso_bolso_v3/screens/minha_vida/jejum/jejum_together_screen.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

Widget _app(List<Override> o) => ProviderScope(
      overrides: o,
      child: MaterialApp(theme: nossoBolsoTheme(), home: const JejumTogetherScreen(membroId: 'm1', familiaId: 'f1')),
    );

void main() {
  testWidgets('Sem dupla: lista membros para convidar, menos eu', (t) async {
    await t.pumpWidget(_app([
      jejumTogetherDuplaProvider.overrideWith((ref, a) async => null),
      listaUsuariosProvider.overrideWith((ref) => Stream.value([
            {'id': 'm1', 'nome': 'Eu'},
            {'id': 'm2', 'nome': 'Ana'},
          ])),
    ]));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Eu'), findsNothing);
    expect(find.text('Convidar'), findsOneWidget);
  });

  testWidgets('Com dupla: timers, mês juntas e incentivo', (t) async {
    final ini = DateTime.now().subtract(const Duration(hours: 5, minutes: 7)).toUtc().toIso8601String();
    await t.pumpWidget(_app([
      jejumTogetherDuplaProvider.overrideWith((ref, a) async => {
            'together_id': 't1',
            'eu': {'nome': 'Eu', 'jejum_ativo': {'iniciado_em': ini, 'meta_horas': 16}, 'sequencia': 3},
            'parceiro': {'nome': 'Ana', 'jejum_ativo': null, 'sequencia': 5},
            'mes': {'sincronizados': 4, 'melhor_sequencia_juntas': 2, 'taxa_combinada': 60},
            'mensagem_ia': 'Que dupla linda!',
          }),
    ]));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    expect(find.text('5h07'), findsOneWidget);
    expect(find.text('Fora do jejum'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('Que dupla linda!'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Enviar incentivo'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Enviar incentivo'), findsOneWidget);
  });
}
