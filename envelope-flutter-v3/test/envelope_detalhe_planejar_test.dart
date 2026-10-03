import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nosso_bolso_v3/core/providers/envelopes_provider.dart';
import 'package:nosso_bolso_v3/core/providers/fixos_provider.dart';
import 'package:nosso_bolso_v3/core/providers/transacoes_provider.dart';
import 'package:nosso_bolso_v3/screens/sheets/sheet_envelope_detalhe.dart';
import 'package:nosso_bolso_v3/screens/sheets/sheet_planejar_mes.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

final envelopes = [
  {'id': 'e1', 'nome_envelope': 'Mercado', 'emoji': '🛒', 'natureza': 'consumo', 'valor_planejado': 1200, 'saldo_atual': 412.3},
  {'id': 'e2', 'nome_envelope': 'Lazer', 'emoji': '🎮', 'natureza': 'consumo', 'valor_planejado': 300, 'saldo_atual': 0},
];

Widget app(Widget filho, {List<Override> extras = const []}) => ProviderScope(
      overrides: [
        envelopesProvider.overrideWith((ref) => Stream.value(envelopes)),
        envelopesViseisProvider.overrideWithValue(envelopes),
        ...extras,
      ],
      child: MaterialApp(theme: nossoBolsoTheme(), home: Scaffold(body: filho)),
    );

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('Detalhe do envelope mostra saldo, ações e lançamentos', (t) async {
    await t.pumpWidget(app(const SheetEnvelopeDetalhe(envelopeId: 'e1'), extras: [
      gastosPorEnvelopeNoMesProvider.overrideWithValue({'e1': 787.7}),
      transacoesDoEnvelopeProvider('e1').overrideWith((ref) => Stream.value([
            {'id': 't1', 'valor': 287.45, 'tipo': 'despesa', 'descricao': 'Assaí', 'created_at': '2026-10-02T10:00:00Z'},
            {'id': 't2', 'valor': 500, 'tipo': 'abastecimento', 'created_at': '2026-10-01T09:00:00Z'},
          ])),
    ]));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Mercado'), findsOneWidget);
    expect(find.textContaining('412,30'), findsOneWidget);
    for (final a in ['Abastecer', 'Gastar', 'Mover']) {
      expect(find.text(a), findsOneWidget);
    }
    expect(find.text('Assaí'), findsOneWidget);
    expect(find.text('Abastecimento'), findsOneWidget);
  });

  testWidgets('Planejar o mês soma o total e compara com o saldo livre', (t) async {
    await t.pumpWidget(app(const SheetPlanejarMes(), extras: [saldoLivreProvider.overrideWithValue(2000)]));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Sobra para distribuir'), findsOneWidget);
    expect(find.text(brl(1500)), findsOneWidget); // total planejado
    expect(find.text(brl(500)), findsOneWidget); // sobra: 2000 - 1500

    await t.enterText(find.widgetWithText(TextField, '300,00'), '100000');
    await t.pumpAndSettle();
    expect(find.text('Planejado acima do saldo'), findsOneWidget);
  });
}
