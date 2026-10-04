import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nosso_bolso_v3/core/plano/plano_mes.dart';
import 'package:nosso_bolso_v3/core/providers/compras_provider.dart';
import 'package:nosso_bolso_v3/core/providers/exercicio_provider.dart';
import 'package:nosso_bolso_v3/core/providers/fixos_provider.dart';
import 'package:nosso_bolso_v3/core/providers/plano_provider.dart';
import 'package:nosso_bolso_v3/core/providers/saude_provider.dart';
import 'package:nosso_bolso_v3/core/providers/usuarios_provider.dart';
import 'package:nosso_bolso_v3/screens/shell/barra_modulo.dart';
import 'package:nosso_bolso_v3/screens/shell/modulos_saude.dart';
import 'package:nosso_bolso_v3/screens/shell/shell_screen.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

class _Perfil extends PerfilUsuarioNotifier {
  @override
  Future<Map<String, dynamic>?> build() async => {'id': 'u', 'familia_id': 'f', 'nome': 'Frederico Rosa'};
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('Escolha do módulo mostra os três módulos com o resumo de cada', (t) async {
    final l = LimiteMes(
      mes: '2026-10',
      receitas: const [],
      contasDoMes: const [],
      compromissos: const [],
      envelopes: const [{'id': 'm', 'valor_planejado': 2722}],
      compras: const [(valor: 56, envelopeId: 'm', forma: 'credito')],
    );
    Modulo? escolhido;
    await t.pumpWidget(ProviderScope(
      overrides: [
        perfilUsuarioLogadoProvider.overrideWith(_Perfil.new),
        limiteMesProvider.overrideWith((ref) => AsyncValue.data(l)),
        fixosStreamProvider.overrideWith((ref) => Stream.value(const [])),
        comprasPendentesProvider.overrideWith((ref) async => [{'id': 'c1'}, {'id': 'c2'}]),
        extratoDiarioProvider.overrideWith((ref, a) async => {'calorias_consumidas_kcal': 900, 'meta_calorica_kcal': 1800}),
        exercicioDiaProvider.overrideWith((ref, a) async => {'total_duracao_min': 30}),
      ],
      child: MaterialApp(theme: nossoBolsoTheme(), home: EscolhaModuloScreen(onEscolher: (m) => escolhido = m)),
    ));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(t.takeException(), isNull);
    expect(find.text('Olá, Frederico'), findsOneWidget);
    expect(find.text(brl(2666)), findsOneWidget);
    expect(find.text('Compras a confirmar'), findsOneWidget);
    expect(find.text('900 de 1800 kcal'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    await t.tap(find.text('Alimentação e jejum'));
    expect(escolhido, Modulo.alimentacao);
  });

  testWidgets('Barra com 3 itens deixa o + no meio', (t) async {
    var lancou = false;
    await t.pumpWidget(MaterialApp(
      theme: nossoBolsoTheme(),
      home: Scaffold(
        bottomNavigationBar: BarraModulo(
          itens: [itemBarra('Hoje', Icons.today), itemBarra('Semana', Icons.bar_chart), itemBarra('Histórico', Icons.history)],
          ativo: 0,
          onItem: (_) {},
          onLancar: () => lancou = true,
        ),
      ),
    ));
    final xMais = t.getCenter(find.text('Lançar')).dx;
    expect(t.getCenter(find.text('Semana')).dx, lessThan(xMais));
    expect(t.getCenter(find.text('Histórico')).dx, greaterThan(xMais));
    await t.tap(find.text('Lançar'));
    expect(lancou, isTrue);
  });

  testWidgets('Ver alimentação de: só quem deixou a família ver', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        perfilUsuarioLogadoProvider.overrideWith(_Perfil.new),
        listaUsuariosProvider.overrideWith((ref) => Stream.value([
              {'id': 'u', 'nome': 'Frederico', 'alimentacao_visivel': false},
              {'id': 'a', 'nome': 'Alanna'},
              {'id': 'b', 'nome': 'Alan', 'alimentacao_visivel': false},
            ])),
      ],
      child: MaterialApp(theme: nossoBolsoTheme(), home: const Scaffold(appBar: null, body: Center(child: SeletorMembroSaude()))),
    ));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Frederico (você)'), findsOneWidget); // abre no seu, mesmo privado
    await t.tap(find.text('Frederico (você)'));
    await t.pumpAndSettle();
    expect(find.text('Alanna'), findsOneWidget);
    expect(find.text('Alan'), findsNothing);
  });
}
