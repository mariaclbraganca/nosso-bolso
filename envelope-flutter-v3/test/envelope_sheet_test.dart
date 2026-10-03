import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/services/app_navigator.dart';
import 'package:nosso_bolso_v3/screens/sheets/sheet_envelope.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

Future<void> abrir(WidgetTester t, {Map<String, dynamic>? envelope}) async {
  await t.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: nossoBolsoTheme(),
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: Scaffold(body: SheetEnvelope(envelope: envelope)),
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Novo envelope: meta só para reserva/objetivo e objetivo exige meta', (t) async {
    await abrir(t);
    expect(t.takeException(), isNull);
    expect(find.text('Novo envelope'), findsOneWidget);
    expect(find.text('Meta total'), findsNothing);

    await t.tap(find.text('Objetivo'));
    await t.pumpAndSettle();
    expect(find.text('Meta total'), findsOneWidget);

    await t.enterText(find.widgetWithText(TextField, 'Nome (ex.: Mercado)'), 'Viagem');
    await t.tap(find.text('Criar envelope'));
    await t.pumpAndSettle();
    expect(find.text('Informe quanto quer juntar neste objetivo.'), findsOneWidget);
  });

  testWidgets('Editar envelope vem preenchido e oferece excluir', (t) async {
    await abrir(t, envelope: {
      'id': 'e1', 'nome_envelope': 'Mercado', 'emoji': '🛒', 'natureza': 'consumo',
      'valor_planejado': 1200, 'saldo_atual': 412.3,
    });
    expect(t.takeException(), isNull);
    expect(find.text('Editar envelope'), findsOneWidget);
    expect(find.text('Mercado'), findsOneWidget);
    expect(find.text('1.200,00'), findsOneWidget);
    await t.ensureVisible(find.text('Excluir envelope'));
    await t.tap(find.text('Excluir envelope'));
    await t.pumpAndSettle();
    expect(find.textContaining('412,30'), findsOneWidget);
    expect(find.text('Remanejar'), findsOneWidget);
  });
}
