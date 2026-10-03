import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nosso_bolso_v3/core/plano/plano_mes.dart';
import 'package:nosso_bolso_v3/core/providers/mes_provider.dart';
import 'package:nosso_bolso_v3/core/providers/plano_provider.dart';
import 'package:nosso_bolso_v3/screens/planos/plano_mes_tab.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

PlanoMes _plano() => PlanoMes(
      mes: '2026-10',
      entradas: [
        {'id': 'e1', 'nome': 'Salário', 'valor': 5491, 'dia': 30, 'recebido': false},
        {'id': 'e2', 'nome': 'Vale alimentação', 'valor': 750, 'tipo': 'vale', 'recebido': true},
      ],
      contas: [
        {'nome': 'Aluguel apto', 'valor': 2148.43, 'pago': false, 'recorrente': true},
        {'nome': 'Resto da fatura', 'valor': 1688.08, 'pago': true},
      ],
      envelopes: [
        {'id': 'm', 'nome_envelope': 'Mercado', 'emoji': '🛒', 'valor_planejado': 1300},
      ],
      gastoPorEnvelope: const {'m': 400},
      compromissos: [
        {'id': 'c1', 'descricao': 'Auto Center', 'valor': 506.95, 'mes_fatura': '2026-11', 'parcela_atual': 2, 'total_parcelas': 3},
        {'id': 'c2', 'descricao': 'Claude', 'valor': 113.85, 'mes_fatura': '2026-11'},
      ],
      gastoNoCartao: 250,
    );

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('Plano do mês mostra resumo, blocos e projeção', (t) async {
    t.view.physicalSize = const Size(1080, 4000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [
        mesAtualProvider.overrideWith((ref) => '2026-10'),
        planoMesProvider.overrideWith((ref) => AsyncValue.data(_plano())),
      ],
      child: MaterialApp(theme: nossoBolsoTheme(), home: const Scaffold(body: PlanoMesTab())),
    ));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    // 6241 − 3836,51 − 620,80 − 1300
    expect(find.text(brl(483.69, sinal: true)), findsWidgets);
    expect(find.text('Salário'), findsOneWidget);
    expect(find.textContaining('dia 30'), findsOneWidget);
    expect(find.text('Auto Center'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('todo mês'), findsOneWidget);
    expect(find.text(brl(870.80)), findsOneWidget); // fatura projetada 620,80 + 250
    expect(find.text('Mercado'), findsOneWidget);
    expect(find.textContaining('Próximos meses'), findsOneWidget);
  });
}
