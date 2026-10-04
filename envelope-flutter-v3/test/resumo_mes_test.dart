import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/plano/plano_mes.dart';
import 'package:nosso_bolso_v3/core/providers/mes_provider.dart';
import 'package:nosso_bolso_v3/core/providers/plano_provider.dart';
import 'package:nosso_bolso_v3/screens/planos/plano_mes_tab.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

void main() {
  testWidgets('Resumo mostra o resultado do ciclo, a transição e os próximos meses', (t) async {
    t.view.physicalSize = const Size(1200, 6000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final l = LimiteMes(
      mes: '2026-10',
      receitas: const [
        {'id': 'r1', 'nome': 'Salário', 'tipo': 'dinheiro', 'valor': 5491.0, 'dia': 30},
        {'id': 'r2', 'nome': 'Pintura', 'tipo': 'eventual', 'valor': 300.0, 'recebido': true, 'destino': 'mes', 'quem': 'Ana'},
      ],
      contasDoMes: const [
        {'nome': 'Aluguel', 'valor': 4706.47, 'recorrente': true},
      ],
      compromissos: const [
        {'descricao': 'Auto Center', 'valor': 506.95, 'mes_fatura': '2026-11', 'parcela_atual': 2, 'total_parcelas': 3},
      ],
      envelopes: const [
        {'id': 'm', 'nome_envelope': 'Mercado', 'valor_planejado': 1300},
      ],
      compras: const [(valor: 100, envelopeId: 'm', forma: 'credito')],
    );
    await t.pumpWidget(ProviderScope(
      overrides: [
        mesAtualProvider.overrideWith((ref) => '2026-10'),
        limiteMesProvider.overrideWith((ref) => AsyncValue.data(l)),
      ],
      child: MaterialApp(theme: nossoBolsoTheme(), home: const Scaffold(body: PlanoMesTab())),
    ));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    expect(find.textContaining('RESULTADO DO CICLO · SALÁRIO DE 30/10'), findsOneWidget);
    // limite 5491 − 4706,47 − 506,95 = 277,58 (eventual vai para o caixa); orçado 1300 → previsto −1.022,42
    expect(find.text(brl(-1022.42)), findsWidgets);
    expect(find.text('Déficit coberto pela reserva'), findsOneWidget);
    expect(find.textContaining('eventual · Ana'), findsOneWidget);
    expect(find.textContaining('Transição de outubro'), findsOneWidget);
    expect(find.text('DISPONÍVEL PARA PLANEJAR NOS PRÓXIMOS MESES'), findsNothing); // fica no Futuro
  });
}
