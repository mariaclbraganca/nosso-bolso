import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/screens/planos/widgets/fixos_card.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

void main() {
  testWidgets('Conta com pagamento parcial mostra o pago e o que falta', (t) async {
    var parte = 0;
    await t.pumpWidget(MaterialApp(
      theme: nossoBolsoTheme(),
      home: Scaffold(
        body: FixosCard(
          fixo: const {'nome': 'Fatura Aruã', 'valor': 7058.46, 'valor_pago': 5370.38, 'pago': false, 'dia_vencimento': 7},
          selecionado: false,
          modoSelecao: false,
          onTogglePago: (_) {},
          onTap: () {},
          onLongPress: () {},
          onEditar: () {},
          onExcluir: () {},
          onPagarParte: () => parte++,
        ),
      ),
    ));
    expect(find.text('Pago ${brl(5370.38)} · falta ${brl(1688.08)}'), findsOneWidget);
    await t.tap(find.byIcon(Icons.more_vert_rounded));
    await t.pumpAndSettle();
    await t.tap(find.text('Pagar parte'));
    await t.pumpAndSettle();
    expect(parte, 1);
  });
}
