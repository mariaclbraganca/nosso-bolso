import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/screens/planos/patrimonio_tab.dart';
import 'package:nosso_bolso_v3/screens/planos/widgets/patrimonio_ia_card.dart';
import 'package:nosso_bolso_v3/screens/planos/widgets/patrimonio_meta_card.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

void main() {
  test('prazo da meta com juros e aporte', () {
    expect(mesesAteMeta(saldo: 1000, meta: 1000, rendimentoPct: 0, aporte: 0), 0);
    expect(mesesAteMeta(saldo: 0, meta: 1000, rendimentoPct: 0, aporte: 0), isNull);
    expect(mesesAteMeta(saldo: 0, meta: 1000, rendimentoPct: 0, aporte: 100), 10);
    expect(mesesAteMeta(saldo: 0, meta: 1000, rendimentoPct: 1, aporte: 100), 10); // 1046 no 10º
    expect(mesesAteMeta(saldo: 500, meta: 1000, rendimentoPct: 1, aporte: 100), 5);
    expect(textoPrazo(14), '1 ano e 2 meses');
    expect(textoPrazo(24), '2 anos');
    expect(textoPrazo(null), 'Sem aporte não chega lá');
  });

  test('subtítulo da conta e urgência', () {
    expect(subtituloConta({'tipo': 'poupanca', 'banco': 'Caixa', 'rendimento_mensal': 0.5}), 'Poupança · Caixa · 0,50% a.m.');
    expect(subtituloConta({'tipo': 'caixinha'}), 'Caixinha');
    expect(rotuloUrgencia('proximo_mes'), 'Próximo mês');
  });

  testWidgets('Card da meta mostra progresso e prazo', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: nossoBolsoTheme(),
      home: const Scaffold(
        body: PatrimonioMetaCard(
          conta: {'nome': 'Viagem', 'emoji': '📦', 'saldo_atual': 500, 'meta_saldo': 1000, 'rendimento_mensal': 1},
          saldoLivre: 500, // aporte inicial 100
        ),
      ),
    ));
    expect(t.takeException(), isNull);
    expect(find.text('Viagem'), findsOneWidget);
    expect(find.textContaining('5 meses ·'), findsOneWidget);
    expect(find.textContaining('chega 65 meses antes'), findsOneWidget);
  });
}
