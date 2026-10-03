import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/providers/saude_provider.dart';
import 'package:nosso_bolso_v3/screens/minha_vida/saude/historico_saude_screen.dart';
import 'package:nosso_bolso_v3/screens/minha_vida/saude/saude_tab.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

void main() {
  testWidgets('Aba Saúde mostra macros do dia e peso', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        extratoDiarioProvider.overrideWith((ref, a) async => {
              'calorias_consumidas_kcal': 900, 'meta_calorica_kcal': 1800,
              'proteina_consumida_g': 60, 'proteina_meta_g': 110,
              'carboidrato_consumido_g': 100, 'carboidrato_meta_g': 200,
              'gordura_consumida_g': 30, 'gordura_meta_g': 60,
            }),
        streakProvider.overrideWith((ref, m) async => 3),
        perfilMetabolicoProvider.overrideWith((ref, m) async => {'metabolico': {}}),
        historicoPesoProvider.overrideWith((ref, m) async => {
              'registros': [{'peso_kg': 72.4}, {'peso_kg': 72.9}],
              'media_movel_7d': 72.65,
            }),
        hidratacaoDiaProvider.overrideWith((ref, a) async => {'total_ml': 500, 'meta_ml': 2000}),
        refeicoesDiaProvider.overrideWith((ref, a) async => []),
      ],
      child: MaterialApp(theme: nossoBolsoTheme(), home: const Scaffold(body: SaudeTab(membroId: 'm1', familiaId: 'f1'))),
    ));
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
    expect(find.text('60 / 110 g'), findsOneWidget);
    expect(find.text('72,4 kg'), findsOneWidget);
    expect(find.text('Sua meta ainda é genérica'), findsNothing);
  });

  testWidgets('Evolução desenha calorias com meta e lida com 1 pesagem', (t) async {
    final dias = [for (var i = 1; i <= 7; i++) '2026-10-0$i'];
    await t.pumpWidget(ProviderScope(
      overrides: [
        historicoProvider.overrideWith((ref, a) async => {
              'meta_calorica_kcal': 1800,
              'series': {
                'calorias': [for (final d in dias) {'data': d, 'valor': 1500}],
                'proteina': [for (final d in dias) {'data': d, 'valor': 90}],
                'peso': [{'data': '2026-10-01', 'valor': 72.4}],
              },
            }),
      ],
      child: MaterialApp(theme: nossoBolsoTheme(), home: const HistoricoSaudeScreen(membroId: 'm1')),
    ));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.textContaining('meta de 1800 kcal'), findsOneWidget);
    await t.scrollUntilVisible(find.textContaining('Uma pesagem só'), 300);
    expect(find.textContaining('Uma pesagem só'), findsOneWidget);
  });
}
