import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nosso_bolso_v3/core/providers/compras_provider.dart';
import 'package:nosso_bolso_v3/core/providers/dia_provider.dart';
import 'package:nosso_bolso_v3/core/providers/envelopes_provider.dart';
import 'package:nosso_bolso_v3/core/providers/insights_provider.dart';
import 'package:nosso_bolso_v3/core/providers/transacoes_provider.dart';
import 'package:nosso_bolso_v3/core/providers/usuarios_provider.dart';
import 'package:nosso_bolso_v3/screens/config/notificacoes_screen.dart';
import 'package:nosso_bolso_v3/screens/home/home_screen.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

class _Perfil extends PerfilUsuarioNotifier {
  @override
  Future<Map<String, dynamic>?> build() async =>
      {'id': 'u1', 'familia_id': 'f1', 'role': 'admin', 'nome': 'Frederico', 'familias': {'nome': 'Filhos de Rá'}};
}

void main() {
  testWidgets('Home renderiza envelopes, novo envelope e aviso de captura', (t) async {
    SharedPreferences.setMockInitialValues({'alarme_fechamento_permissao': true});
    final envelopes = [
      {'id': 'e1', 'nome_envelope': 'Mercado', 'natureza': 'consumo', 'valor_planejado': 1200, 'saldo_atual': 412.3},
      {'id': 'e2', 'nome_envelope': 'Reserva', 'natureza': 'reserva', 'valor_planejado': 400, 'saldo_atual': 8450},
    ];
    await t.pumpWidget(ProviderScope(
      overrides: [
        perfilUsuarioLogadoProvider.overrideWith(_Perfil.new),
        envelopesProvider.overrideWith((ref) => Stream.value(envelopes)),
        saldoGeralProvider.overrideWith((ref) => Stream.value(1240.0)),
        listaUsuariosProvider.overrideWith((ref) => Stream.value([
              {'id': 'u1', 'nome': 'Frederico'},
              {'id': 'u2', 'nome': 'Alanna'},
            ])),
        transacoesStreamProvider.overrideWith((ref) => Stream.value(<Map<String, dynamic>>[])),
        comprasPendentesProvider.overrideWith((ref) async => []),
        insightsProvider.overrideWith((ref, mes) async => []),
        resumoDiaProvider.overrideWith((ref) async => {'fechado': false}),
        permissaoCapturaProvider.overrideWith((ref) async => false),
      ],
      child: MaterialApp(theme: nossoBolsoTheme(), home: const HomeScreen()),
    ));
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Captura do Nubank e iFood desligada'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Novo envelope'), 300);
    expect(find.text('Mercado'), findsOneWidget);
    expect(find.text('Orçamento'), findsOneWidget);
  });
}
