import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/screens/sheets/widgets/planejado_real.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

void main() {
  testWidgets('Planejado × gasto real mostra a diferença e ajusta pela média', (t) async {
    var ajustou = false;
    await t.pumpWidget(MaterialApp(
      theme: nossoBolsoTheme(),
      home: Scaffold(
        body: Column(children: [
          PlanejadoXRealCard(
            planejado: 2460,
            mediaReal: 1708.78,
            faltaNoMesSeguinte: 4482.24,
            proximoMes: 'novembro',
            onAjustar: () => ajustou = true,
          ),
          const ChipMedia(planejado: 1300, media: 690.84),
          const ChipMedia(planejado: 200, media: 303.48),
        ]),
      ),
    ));
    expect(find.textContaining('planejaram ${brl(751.22)} a mais'), findsOneWidget);
    expect(find.textContaining('falta de novembro fica em ${brl(3731.02)}'), findsOneWidget);
    expect(find.text('${brl(609.16)} acima da média'), findsOneWidget);
    expect(find.text('${brl(103.48)} abaixo da média'), findsOneWidget);
    await t.tap(find.text('Ajustar todos pela média'));
    expect(ajustou, isTrue);
  });
}
