import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nosso_bolso_v3/core/providers/envelopes_provider.dart';
import 'package:nosso_bolso_v3/core/plano/plano_mes.dart';
import 'package:nosso_bolso_v3/core/providers/plano_provider.dart';
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
    for (final a in ['Orçamento', 'Compra', 'Transferir']) {
      expect(find.text(a), findsOneWidget);
    }
    expect(find.text('Assaí'), findsOneWidget);
    expect(find.text('Abastecimento'), findsOneWidget);
  });

  testWidgets('Orçamento mensal compara o total orçado com o limite de compras', (t) async {
    t.view.physicalSize = const Size(1200, 4000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final limite = LimiteMes(
      mes: '2026-10',
      receitas: const [
        {'tipo': 'dinheiro', 'valor': 5000.0},
      ],
      contasDoMes: const [
        {'nome': 'Aluguel', 'valor': 2000.0, 'recorrente': true},
      ],
      compromissos: const [
        {'descricao': 'Dentista', 'valor': 500.0, 'mes_fatura': '2026-11', 'parcela_atual': 1, 'total_parcelas': 2},
      ],
      envelopes: envelopes,
      compras: const [],
    );
    await t.pumpWidget(app(const SingleChildScrollView(child: SheetPlanejarMes()),
        extras: [limiteMesProvider.overrideWith((ref) => AsyncValue.data(limite))]));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('ENTRADAS (+)'), findsOneWidget);
    expect(find.text('Gastos a serem pagos em novembro'), findsOneWidget);
    expect(find.text(brl(2500)), findsOneWidget); // 2000 de contas + 500 de parcela
    expect(find.text('Custo do mês'), findsOneWidget);
    expect(find.text(brl(4000)), findsOneWidget); // 2500 + planejado 1500
    expect(find.text('Ainda pode distribuir'), findsOneWidget);
    expect(find.text('Planejado ${brl(1500)}'), findsOneWidget); // barra fixa
    expect(find.text(brl(-1500)), findsNothing); // sem números negativos

    await t.enterText(find.widgetWithText(TextField, '300,00'), '2000');
    await t.pumpAndSettle();
    expect(find.text('Falta dinheiro (sai da reserva)'), findsOneWidget);
    expect(find.text('Falta dinheiro ${brl(700)}'), findsOneWidget); // 5000 − (2500 + 3200)
  });
}
