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
        {'nome': 'Aluguel da casa', 'tipo': 'eventual', 'valor': 1150.0, 'recebido': false},
      ],
      contasDoMes: const [
        {'nome': 'Fatura Aruã', 'valor': 7058.46, 'valor_pago': 5370.38},
        {'nome': 'Recorrentes', 'valor': 5173.25, 'recorrente': true},
      ],
      compromissos: const [
        {'descricao': 'Parcelas e assinaturas', 'valor': 2339.99, 'mes_fatura': '2026-11'},
      ],
      envelopes: const [
        {'id': 'mercado', 'valor_planejado': 2722},
      ],
      compras: const [
        (valor: 56, envelopeId: 'mercado', forma: 'credito'),
        (valor: 30, envelopeId: 'va', forma: 'va'),
      ],
      dinheiroAnterior: 5370.38,
    );
    await t.pumpWidget(MaterialApp(
      theme: nossoBolsoTheme(),
      home: Scaffold(body: SingleChildScrollView(child: CartaoDisponivel(limite: l, saldoConta: 0))),
    ));
    expect(t.takeException(), isNull);
    expect(find.text('PODE GASTAR AINDA EM OUTUBRO'), findsOneWidget);
    expect(find.text(brl(2666)), findsOneWidget);
    expect(find.text('Vai sair da reserva em outubro: ${brl(6861.33)}'), findsOneWidget);
    expect(find.text('para terminar de pagar as contas de outubro'), findsOneWidget);
    expect(find.text('Se Aluguel da casa cair: ${brl(5711.33)}'), findsOneWidget);
    expect(find.text('Falta dinheiro em novembro (sai da reserva): ${brl(4744.24)}'), findsOneWidget);
    expect(find.text('CONTAS QUE VENCEM EM OUTUBRO'), findsOneWidget);
    expect(find.text(brl(12231.71)), findsOneWidget);
    expect(find.text(brl(6861.33)), findsOneWidget); // falta pagar no card de contas
    expect(find.text('Vale-alimentação'), findsOneWidget);
    expect(find.text(brl(720)), findsOneWidget);
  });
}
