import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/providers/patrimonio_provider.dart';
import 'package:nosso_bolso_v3/core/services/bcb_service.dart';
import 'package:nosso_bolso_v3/screens/config/simulador_gastos_screen.dart';
import 'package:nosso_bolso_v3/screens/planos/simulador_realocacao_screen.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

void main() {
  test('juros compostos e simulação em JSON', () {
    expect(projetarValor(1000, 1, 12), closeTo(1126.83, 0.01));
    final s = SimulacaoGastos(nome: 'Apto', receita: 5000, itens: const [(nome: 'Aluguel', valor: 2000), (nome: 'Condomínio', valor: 600)]);
    final volta = SimulacaoGastos.fromJson(s.toJson());
    expect(volta.total, 2600);
    expect(volta.sobra, 2400);
    expect(volta.itens.last.nome, 'Condomínio');
  });

  testWidgets('Realocação compara a conta com o destino', (t) async {
    final conta = {'id': 'c1', 'nome': 'Poupança Caixa', 'saldo_atual': 10000, 'rendimento_mensal': 0.5};
    await t.pumpWidget(ProviderScope(
      overrides: [
        patrimonioProvider.overrideWith((ref) => Stream.value([conta])),
        taxasBcbProvider.overrideWith((ref) async =>
            const TaxasBrasil(selicMensal: 1.0, cdiMensal: 1.0, ipcaAnual: 4.5, dataReferencia: 'set/2026')),
      ],
      child: MaterialApp(theme: nossoBolsoTheme(), home: SimuladorRealocacaoScreen(contaInicial: conta)),
    ));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    expect(find.text('Rende 0,50% a.m. hoje'), findsOneWidget);
    await t.scrollUntilVisible(find.textContaining('Em 12 meses'), 300, scrollable: find.byType(Scrollable).first);
    // 10000×1,01^12 − 10000×1,005^12 = 11268,25 − 10616,78
    expect(find.textContaining('651,47'), findsNWidgets(2)); // linha de 12 meses + resumo
  });

  testWidgets('Detalhe da simulação mostra sobra', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: nossoBolsoTheme(),
      home: const DetalheSimulacaoScreen(
        simulacao: SimulacaoGastos(nome: 'Carro', receita: 3000, itens: [(nome: 'Parcela', valor: 3500)]),
      ),
    ));
    expect(find.text('Falta'), findsOneWidget);
    expect(find.text(brl(500)), findsOneWidget);
  });
}
