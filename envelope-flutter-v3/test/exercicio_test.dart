import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nosso_bolso_v3/core/providers/exercicio_provider.dart';
import 'package:nosso_bolso_v3/screens/minha_vida/exercicio/exercicio_historico_view.dart';
import 'package:nosso_bolso_v3/screens/minha_vida/exercicio/widgets/form_treino_sheet.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('Histórico soma a semana pelos documentos de cada dia', (t) async {
    final hoje = DateTime.now();
    await t.pumpWidget(ProviderScope(
      overrides: [
        historicoExercicioProvider.overrideWith((ref, m) async => [
              {
                'data': _iso(hoje),
                'total_duracao_min': 40,
                'total_calorias_kcal': 210,
                'exercicios': [{'nome': 'Corrida (8 km/h)', 'categoria': 'cardio', 'duracao_min': 40}],
              },
              {
                'data': _iso(hoje.subtract(const Duration(days: 2))),
                'total_duracao_min': 30,
                'total_calorias_kcal': 90,
                'exercicios': [{'nome': 'Yoga', 'categoria': 'flexibilidade', 'duracao_min': 30}],
              },
            ]),
      ],
      child: MaterialApp(theme: nossoBolsoTheme(), home: const Scaffold(body: ExercicioHistoricoView(membroId: 'm1'))),
    ));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    expect(find.text('70 min · 300 kcal · 2 dias ativos'), findsOneWidget);
    expect(find.text('Faltam 80 min para os 150 da semana'), findsOneWidget);
    expect(find.text('Corrida (8 km/h)'), findsOneWidget);
    expect(find.text('Yoga'), findsOneWidget);
  });

  testWidgets('Catálogo preenche o nome do treino', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        catalogoExerciciosProvider.overrideWith((ref) async => [
              {'nome': 'Caminhada leve', 'categoria': 'cardio', 'met': 2.8},
              {'nome': 'Pilates', 'categoria': 'flexibilidade', 'met': 3.0},
            ]),
      ],
      child: MaterialApp(
        theme: nossoBolsoTheme(),
        home: const Scaffold(body: SingleChildScrollView(child: FormTreinoSheet(membroId: 'm1', familiaId: 'f1', data: '2026-10-03'))),
      ),
    ));
    await t.pump();
    expect(find.text('Pilates'), findsNothing);
    await t.tap(find.text('Caminhada leve'));
    await t.pump();
    expect(find.widgetWithText(TextField, 'Caminhada leve'), findsOneWidget);
  });
}
