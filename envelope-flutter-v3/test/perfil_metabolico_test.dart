import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/providers/saude_provider.dart';
import 'package:nosso_bolso_v3/screens/minha_vida/saude/perfil_metabolico_screen.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

Widget app(Map<String, dynamic>? perfil) => ProviderScope(
      overrides: [perfilMetabolicoProvider('m1').overrideWith((ref) async => perfil)],
      child: MaterialApp(theme: nossoBolsoTheme(), home: const PerfilMetabolicoScreen(membroId: 'm1')),
    );

void main() {
  test('corpo do perfil vai no formato que o backend calcula', () {
    final c = corpoPerfilMetabolico(
        membroId: 'm1', sexo: 'F', idade: 34, pesoKg: 62, alturaCm: 165, objetivo: 'perda_peso', nivelAtividade: 'leve');
    expect(c['antropometria'], {'sexo': 'F', 'idade': 34, 'peso_kg': 62.0, 'altura_cm': 165.0});
    expect(c['metabolico'], {'objetivo': 'perda_peso', 'nivel_atividade': 'leve'});
  });

  testWidgets('Sem perfil convida a montar o plano', (t) async {
    await t.pumpWidget(app(null));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Montar meu plano'), findsOneWidget);
  });

  testWidgets('Com perfil mostra meta e macros', (t) async {
    await t.pumpWidget(app({
      'antropometria': {'peso_kg': 62, 'altura_cm': 165, 'idade': 34},
      'metabolico': {
        'meta_calorica_kcal': 1315, 'tdee_kcal': 1815, 'tmb_kcal': 1320, 'objetivo': 'perda_peso',
        'nivel_atividade': 'leve', 'meta_agua_ml': 2170, 'meta_fibra_g': 25,
        'metas_macros': {'proteina_total_g': 99, 'carboidrato_g': 130, 'gordura_g': 44},
      },
    }));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('1315 kcal'), findsOneWidget);
    expect(find.text('99 g'), findsOneWidget);
    expect(find.textContaining('Perder peso'), findsOneWidget);
  });
}
