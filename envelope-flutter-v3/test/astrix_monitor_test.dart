import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/providers/monitor_ia_provider.dart';
import 'package:nosso_bolso_v3/core/services/gemini_monitor_service.dart';
import 'package:nosso_bolso_v3/screens/config/insights_astrix_screen.dart';
import 'package:nosso_bolso_v3/screens/home/widgets/home_monitor_ia.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

void main() {
  testWidgets('Relatório mostra nota, áreas, destaques, alertas e dica', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: nossoBolsoTheme(),
      home: const Scaffold(
        body: RelatorioAstrix(dados: {
          'saudacao': 'Oi, família!',
          'score_geral': 82,
          'financeiro_score': 90,
          'nutricao_score': 60,
          'exercicio_score': 40,
          'destaques': [{'emoji': '💰', 'titulo': 'Mercado no limite', 'texto': 'Gastaram 10% menos.'}],
          'alertas': [{'titulo': 'Lazer', 'texto': 'Passou do planejado.'}],
          'dica_semana': 'Planejem o cardápio no domingo.',
        }),
      ),
    ));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    expect(find.text('82'), findsOneWidget);
    expect(find.text('Oi, família!'), findsOneWidget);
    expect(find.text('Mercado no limite'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Planejem o cardápio no domingo.'), 200);
    expect(find.text('Passou do planejado.'), findsOneWidget);
  });

  testWidgets('Monitor abre e mostra projeção e ações; some com erro', (t) async {
    final analise = MonitorAnalise(
      status: 'atencao',
      titulo: 'Mercado acelerado',
      resumo: 'O mercado está 20% acima do ritmo.',
      insights: const [],
      projecaoMes: 'No ritmo atual, passam R\$ 300 do planejado.',
      acoesRecomendadas: const ['Segurar delivery até sexta'],
      geradoEm: DateTime(2026, 10, 3),
    );
    await t.pumpWidget(ProviderScope(
      overrides: [monitorIAProvider.overrideWith((ref) async => analise)],
      child: MaterialApp(theme: nossoBolsoTheme(), home: const Scaffold(body: SingleChildScrollView(child: HomeMonitorIA()))),
    ));
    await t.pump();
    expect(find.text('Mercado acelerado'), findsOneWidget);
    expect(find.textContaining('passam'), findsNothing);
    await t.tap(find.text('Mercado acelerado'));
    await t.pump();
    expect(find.textContaining('passam'), findsOneWidget);
    expect(find.text('• Segurar delivery até sexta'), findsOneWidget);

    await t.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [monitorIAProvider.overrideWith((ref) async => throw Exception('sem chave'))],
      child: MaterialApp(theme: nossoBolsoTheme(), home: const Scaffold(body: HomeMonitorIA())),
    ));
    await t.pump();
    await t.pump();
    expect(find.text('MONITOR DO ASTRIX'), findsNothing);
  });
}
