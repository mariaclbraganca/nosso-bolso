import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/screens/extrato/exportar_dialog.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

void main() {
  testWidgets('Exportar oferece PDF e CSV', (t) async {
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: nossoBolsoTheme(),
        home: const Scaffold(body: ExportarDialog(transacoes: [{'valor': 10}], mes: '2026-10')),
      ),
    ));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);
    expect(find.textContaining('1 lançamentos de 2026-10'), findsOneWidget);
  });
}
