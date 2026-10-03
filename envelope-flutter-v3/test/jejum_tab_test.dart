import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/providers/jejum_provider.dart';
import 'package:nosso_bolso_v3/screens/minha_vida/jejum/jejum_tab.dart';

void main() {
  testWidgets('JejumTab renderiza card de sequencia e timer display', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jejumConfigProvider((membroId: 'u1', familiaId: 'f1')).overrideWith(
            (ref) async => {
              'protocolo': '16_8',
              'sequencia_atual': 3,
              'joker_days_mes': 2,
              'jokers_usados': 0,
            },
          ),
          jejumAtivoProvider('u1').overrideWith(
            (ref) => Stream.value(null),
          ),
        ],
        child: MaterialApp(
          theme: nossoBolsoTheme(),
          home: const Scaffold(
            body: JejumTab(membroId: 'u1', familiaId: 'f1'),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Sua Sequência'), findsOneWidget);
    expect(find.text('Iniciar Jejum Agora ⏱️'), findsOneWidget);
  });
}
