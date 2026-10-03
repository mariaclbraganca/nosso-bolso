import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/screens/auth/splash_unicornios.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

void main() {
  testWidgets('Splash apresenta o time e marca como visto ao tocar', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: nossoBolsoTheme(), home: const SplashUnicornios()),
    ));
    await t.pump(const Duration(milliseconds: 2500));
    expect(t.takeException(), isNull);
    for (final n in ['Astrix', 'Sweet', 'Happy', 'Geronimo']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(c.read(splashVistoProvider), isFalse);
    await t.tap(find.text('Toque para entrar'));
    expect(c.read(splashVistoProvider), isTrue);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Splash entra sozinho depois do tempo', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: nossoBolsoTheme(), home: const SplashUnicornios(duracao: Duration(seconds: 1))),
    ));
    await t.pump(const Duration(milliseconds: 1100));
    expect(c.read(splashVistoProvider), isTrue);
    await t.pumpWidget(const SizedBox());
  });
}
