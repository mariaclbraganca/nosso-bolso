import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/plano/plano_mes.dart';
import 'package:nosso_bolso_v3/core/providers/envelopes_provider.dart';
import 'package:nosso_bolso_v3/core/providers/plano_provider.dart';
import 'package:nosso_bolso_v3/core/providers/usuarios_provider.dart';
import 'package:nosso_bolso_v3/screens/lancar/lancar.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

final _envs = <Map<String, dynamic>>[
  {'id': 'pets', 'nome_envelope': 'Pets', 'valor_planejado': 100},
  {'id': 'va', 'nome_envelope': 'Vale Alimentação', 'valor_planejado': 750},
];

LimiteMes _limite() => LimiteMes(
      mes: '2026-10',
      receitas: const [
        {'tipo': 'dinheiro', 'valor': 5491.0},
        {'tipo': 'vale', 'valor': 750.0},
      ],
      contasDoMes: const [
        {'valor': 4706.47, 'recorrente': true},
      ],
      compromissos: const [
        {'descricao': 'Parcelas', 'valor': 2339.99, 'mes_fatura': '2026-11'},
      ],
      envelopes: [_envs.first],
      compras: const [(valor: 56, envelopeId: null, forma: 'credito')],
    );

Widget _app(Widget folha) => ProviderScope(
      overrides: [
        envelopesViseisProvider.overrideWithValue(_envs),
        limiteMesProvider.overrideWith((ref) => AsyncValue.data(_limite())),
        perfilUsuarioLogadoProvider.overrideWith(() => _PerfilFixo()),
        listaUsuariosProvider.overrideWith((ref) => Stream.value([
              {'id': 'u1', 'nome': 'Frederico Rosa'},
              {'id': 'u2', 'nome': 'Ana'},
            ])),
      ],
      child: MaterialApp(theme: nossoBolsoTheme(), home: Scaffold(body: SingleChildScrollView(child: folha))),
    );

class _PerfilFixo extends PerfilUsuarioNotifier {
  @override
  Future<Map<String, dynamic>?> build() async => {'id': 'u1', 'nome': 'Frederico Rosa', 'familia_id': 'f1'};
}

void main() {
  testWidgets('Compra parcelada mostra o efeito no mês e a linha de meses', (t) async {
    t.view.physicalSize = const Size(1200, 3600);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const SheetCompra()));
    await t.pump();
    await t.enterText(find.byType(TextField).first, '300000');
    await t.tap(find.text('Pets'));
    await t.pump();
    await t.tap(find.text('À vista'));
    await t.pumpAndSettle();
    await t.tap(find.text('Parcelada em 7x').last);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Efeito desta compra neste mês'), findsOneWidget);
    expect(find.text(brl(-2040.03)), findsOneWidget); // −1.611,46 − 428,57
    expect(find.text('Pets fica ${brl(328.57)} acima do orçado.'), findsOneWidget);
    expect(find.textContaining('7x de ${brl(428.57)}'), findsOneWidget);
    expect(find.text('7/7'), findsOneWidget);
    expect(find.text('mai'), findsOneWidget);
  });

  testWidgets('Receita: quem recebeu e destino mudam a prévia', (t) async {
    t.view.physicalSize = const Size(1200, 3000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const SheetReceita()));
    await t.pump();
    await t.pump();
    expect(find.text('Frederico'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, '115000');
    await t.pump();
    expect(find.text(brl(-461.46)), findsOneWidget); // disponível −1.611,46 + 1.150
    await t.tap(find.text('Guardar na reserva'));
    await t.pump();
    expect(find.text('Guardado na reserva neste mês'), findsOneWidget);
    expect(find.textContaining('Não muda o limite do mês'), findsOneWidget);
  });
}
