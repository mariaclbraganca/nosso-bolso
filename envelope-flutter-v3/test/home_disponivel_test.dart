import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/plano/plano_mes.dart';
import 'package:nosso_bolso_v3/screens/home/widgets/home_cartao_saldo.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

void main() {
  test('último dia útil', () {
    expect(ultimoDiaUtil('2026-10'), '30/10'); // 31/10/2026 é sábado
    expect(ultimoDiaUtil('2026-11'), '30/11');
    expect(ultimoDiaUtil('2027-01'), '29/01'); // 31 domingo, 30 sábado
  });

  testWidgets('Card do Início com os números de outubro', (t) async {
    final l = LimiteMes(
      mes: '2026-10',
      receitas: const [
        {'tipo': 'dinheiro', 'valor': 5491.0},
        {'tipo': 'vale', 'valor': 750.0},
      ],
      contasDoMes: const [
        {'valor': 4706.47, 'recorrente': true},
      ],
      compromissos: const [
        {'descricao': 'Parcelas e assinaturas', 'valor': 2339.99, 'mes_fatura': '2026-11'},
      ],
      envelopes: const [],
      compras: const [
        (valor: 56, envelopeId: 'mercado', forma: 'credito'),
        (valor: 30, envelopeId: 'va', forma: 'va'),
      ],
    );
    await t.pumpWidget(MaterialApp(
      theme: nossoBolsoTheme(),
      home: Scaffold(body: SingleChildScrollView(child: CartaoDisponivel(limite: l, saldoConta: 0))),
    ));
    expect(t.takeException(), isNull);
    expect(find.text('DISPONÍVEL PARA GASTAR EM OUTUBRO'), findsOneWidget);
    expect(find.text(brl(-1611.46)), findsOneWidget);
    expect(find.text(brl(-1555.46)), findsOneWidget);
    expect(find.textContaining('salário de 30/10 já está todo comprometido com as contas de novembro'), findsOneWidget);
    expect(find.text('Vale-alimentação'), findsOneWidget);
    expect(find.text(brl(720)), findsOneWidget);
  });
}
