import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/providers/fechamento_provider.dart';
import 'package:nosso_bolso_v3/core/services/api_service.dart';
import 'package:nosso_bolso_v3/screens/retrospectiva/retrospectiva_screen.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

Widget app(List<Override> o) => ProviderScope(
      overrides: o,
      child: MaterialApp(theme: nossoBolsoTheme(), home: const RetrospectivaScreen(mes: '2026-09')),
    );

void main() {
  testWidgets('Mês fechado no vermelho mostra resultado, coberto e envelope que passou', (t) async {
    await t.pumpWidget(app([
      retrospectivaProvider('2026-09').overrideWith((ref) async => {
            'receita_total': 6200, 'total_consumo': 5000, 'total_compromisso': 1650,
            'resultado_mes': -450, 'coberto_por_fora': 450,
          }),
      visaoMesProvider('2026-09').overrideWith((ref) async => {
            'envelopes': [
              {'nome_envelope': 'Transporte', 'natureza': 'consumo', 'valor_planejado': 600, 'total_gasto': 702},
              {'nome_envelope': 'Reserva', 'natureza': 'reserva', 'valor_planejado': 400, 'total_gasto': 0},
            ],
          }),
    ]));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.textContaining('fechou no vermelho'), findsOneWidget);
    expect(find.textContaining('cobertos por fora'), findsOneWidget);
    expect(find.text('Transporte'), findsOneWidget);
    expect(find.text('Reserva'), findsNothing); // só envelopes de consumo
    expect(find.textContaining('Passou'), findsOneWidget);
  });

  testWidgets('Mês não fechado (404) explica e oferece o mês anterior', (t) async {
    await t.pumpWidget(app([
      retrospectivaProvider('2026-09').overrideWith((ref) async => throw const ApiException('Mês ainda não foi fechado.', 404)),
      visaoMesProvider('2026-09').overrideWith((ref) async => {}),
      retrospectivaProvider('2026-08').overrideWith((ref) async => {'resultado_mes': 100}),
      visaoMesProvider('2026-08').overrideWith((ref) async => {}),
    ]));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Este mês ainda não foi fechado'), findsOneWidget);
    await t.tap(find.text('Ver o mês anterior'));
    await t.pump(const Duration(seconds: 1));
    await t.pump();
    expect(find.textContaining('fechou no azul'), findsOneWidget);
  });
}
