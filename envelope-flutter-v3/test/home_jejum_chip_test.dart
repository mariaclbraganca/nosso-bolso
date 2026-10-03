import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/screens/home/widgets/home_jejum_chip.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

Widget _app(Widget w) => MaterialApp(theme: nossoBolsoTheme(), home: Scaffold(body: w));

void main() {
  testWidgets('Chip mostra tempo e fase, e abre ao tocar', (t) async {
    var abriu = false;
    await t.pumpWidget(_app(JejumChip(
      decorrido: const Duration(hours: 13, minutes: 5),
      metaHoras: 16,
      onTap: () => abriu = true,
    )));
    expect(find.text('⚡ Jejum 13h05 · Cetose leve'), findsOneWidget);
    await t.tap(find.text('⚡ Jejum 13h05 · Cetose leve'));
    expect(abriu, isTrue);
  });

  testWidgets('Chip comemora a meta', (t) async {
    await t.pumpWidget(_app(JejumChip(decorrido: const Duration(hours: 16, minutes: 2), metaHoras: 16, onTap: () {})));
    expect(find.text('✨ Jejum de 16h02 · meta alcançada!'), findsOneWidget);
  });
}
