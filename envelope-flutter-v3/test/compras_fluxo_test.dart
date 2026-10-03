import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/screens/compras/nfce_fluxo.dart';
import 'package:nosso_bolso_v3/screens/compras/widgets/compras_falhas_card.dart';
import 'package:nosso_bolso_v3/screens/compras/widgets/compras_pendente_card.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

Widget app(Widget w) => ProviderScope(
      child: MaterialApp(theme: nossoBolsoTheme(), home: Scaffold(body: SingleChildScrollView(child: w))),
    );

void main() {
  test('montarBodyIngestao normaliza itens, categoria e vínculo', () {
    final body = montarBodyIngestao(
      familiaId: 'f1',
      qrUrl: 'https://nfce.sefaz.go.gov.br/x',
      compraIdVinculo: 'c9',
      extraido: {
        'supermercado': 'Assaí',
        'valor_total': 55.8,
        'itens': [
          {'nome_original': 'ARROZ T1', 'categoria': 'Grãos e Cereais', 'quantidade': 2, 'valor_unitario': 27.9, 'valor_total_item': 55.8},
          {'nome_padronizado': 'Detergente', 'categoria': 'LIMPEZA'},
          {'nome_original': 'X', 'categoria': 'Inventada'},
        ],
      },
    );
    expect(body['compra_id'], 'c9');
    final itens = body['itens'] as List;
    expect(itens[0]['nome_padronizado'], 'ARROZ T1');
    expect(itens[0]['quantidade'], 2.0);
    expect(itens[1]['categoria'], 'Limpeza');
    expect(itens[1]['quantidade'], 1.0);
    expect(itens[2]['categoria'], 'Outros');
  });

  testWidgets('Card de falhas: dica da SEFAZ e tentar de novo com a URL', (t) async {
    String? tentou;
    await t.pumpWidget(app(ComprasFalhasCard(
      falhas: const [
        {'erro': 'timeout', 'erro_categoria': 'sefaz', 'qr_code_url': 'https://nfce.sefaz.go.gov.br/a'},
        {'erro': 'x'},
      ],
      onTentarDeNovo: (u) => tentou = u,
      onDispensar: () {},
    )));
    expect(t.takeException(), isNull);
    expect(find.text('2 notas não foram lidas'), findsOneWidget);
    expect(find.textContaining('SEFAZ está instável'), findsOneWidget);
    await t.tap(find.text('Tentar de novo'));
    expect(tentou, 'https://nfce.sefaz.go.gov.br/a');
  });

  testWidgets('Compra sem itens oferece escanear o cupom', (t) async {
    await t.pumpWidget(app(const ComprasPendenteCard(compra: {
      'compra_id': 'c1', 'supermercado': 'Drogaria', 'valor_total': 38.9,
      'data_compra': '2026-10-02T10:00:00', 'fonte': 'nubank', 'itens': [],
    })));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('Escanear o cupom desta compra'), findsOneWidget);
  });
}
