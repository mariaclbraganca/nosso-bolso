import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/plano/plano_mes.dart';
import 'package:nosso_bolso_v3/screens/planos/widgets/proximos_meses.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

void main() {
  testWidgets('Próximos meses mostram a falta depois dos envelopes, mesmo sem parcelas', (t) async {
    final l = LimiteMes(
      mes: '2026-10',
      receitas: const [{'tipo': 'dinheiro', 'valor': 5491.0}],
      contasDoMes: const [{'valor': 5173.25, 'recorrente': true}],
      compromissos: const [],
      envelopes: const [{'id': 'm', 'valor_planejado': 2460}],
      compras: const [],
    );
    await t.pumpWidget(MaterialApp(theme: nossoBolsoTheme(), home: Scaffold(body: SingleChildScrollView(child: ProximosMeses(limite: l)))));
    // livre 317,75; depois dos envelopes −2.142,25 todo mês
    expect(find.text(brl(317.75)), findsNWidgets(5));
    expect(find.text('−${brl(2142.25)}'), findsNWidgets(5));
    expect(find.textContaining('falta ${brl(2142.25)} por mês mesmo depois que as parcelas acabam'), findsOneWidget);
  });
}
