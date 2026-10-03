import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nosso_bolso_v3/core/providers/jejum_provider.dart';
import 'package:nosso_bolso_v3/screens/minha_vida/jejum/jejum_historico_view.dart';
import 'package:nosso_bolso_v3/screens/minha_vida/jejum/jejum_insights_view.dart';
import 'package:nosso_bolso_v3/screens/minha_vida/jejum/widgets/jejum_config_sheet.dart';
import 'package:nosso_bolso_v3/screens/minha_vida/jejum/widgets/jejum_extras.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

Widget _app(Widget body, [List<Override> o = const []]) => ProviderScope(
      overrides: o,
      child: MaterialApp(theme: nossoBolsoTheme(), home: Scaffold(body: body)),
    );

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  test('próxima fase e rótulos gentis', () {
    expect(textoProximaFase(const Duration(hours: 10, minutes: 30)), 'Faltam 1h 30min para ⚡ Cetose leve');
    expect(textoProximaFase(const Duration(hours: 21)), isNull);
    expect(rotuloStatusJejum('interrompido'), 'Dia de descanso');
    expect(rotuloStatusJejum('completo'), 'Concluído');
  });

  testWidgets('Histórico mostra números, semana e registros', (t) async {
    final ontem = DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String();
    await t.pumpWidget(_app(const JejumHistoricoView(membroId: 'm1'), [
      jejumHistoricoProvider.overrideWith((ref, m) async => {
            'registros': [
              {'iniciado_em': ontem, 'duracao_real_min': 990, 'meta_horas': 16, 'status': 'completo'},
              {'iniciado_em': ontem, 'duracao_real_min': 600, 'meta_horas': 16, 'status': 'interrompido'},
            ],
            'stats': {'total': 2, 'completos': 1, 'taxa_sucesso': 50, 'duracao_media_min': 795},
          }),
    ]));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('13h15'), findsOneWidget);
    expect(find.text('16h30'), findsOneWidget);
    expect(find.text('Dia de descanso'), findsOneWidget);
    expect(find.text('meta 16h · 1 de 7'), findsOneWidget);
  });

  testWidgets('Insights mostra fala do unicórnio e cartões', (t) async {
    await t.pumpWidget(_app(const JejumInsightsView(membroId: 'm1'), [
      jejumInsightsProvider.overrideWith((ref, m) async => {
            'insight_principal': 'Você vai melhor nos dias úteis.',
            'insights': [
              {'icone': '🌙', 'titulo': 'Noites tranquilas', 'texto': 'Começar às 20h funciona para você.'},
            ],
            'sugestao': 'Tente manter o mesmo horário no fim de semana.',
            'mensagem_unicornio': {'unicornio': 'sweet', 'texto': 'Que semana bonita!'},
          }),
    ]));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    expect(find.text('Que semana bonita!'), findsOneWidget);
    expect(find.text('Noites tranquilas'), findsOneWidget);
    expect(find.textContaining('mesmo horário'), findsOneWidget);
  });

  testWidgets('Config ajusta janela pelo protocolo e conta folgas', (t) async {
    await t.pumpWidget(_app(const SingleChildScrollView(
      child: JejumConfigSheet(
        usuarioId: 'm1',
        familiaId: 'f1',
        protocoloAtual: '16_8',
        config: {'janela_inicio': '12:00:00', 'janela_fim': '20:00:00', 'joker_days_mes': 2},
      ),
    )));
    await t.pump();
    expect(find.text('Das 12:00'), findsOneWidget);
    expect(find.text('Até 20:00'), findsOneWidget);
    final p = ProtocoloJejum.todos.firstWhere((p) => p.horas == 18);
    await t.ensureVisible(find.text(p.descricao));
    await t.tap(find.text(p.descricao));
    await t.pump();
    expect(find.text('Até 18:00'), findsOneWidget);
    await t.ensureVisible(find.byTooltip('Mais folgas'));
    await t.tap(find.byTooltip('Mais folgas'));
    await t.pump();
    expect(find.text('3'), findsOneWidget);
  });
}
