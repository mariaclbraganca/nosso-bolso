import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/providers/usuarios_provider.dart';
import 'package:nosso_bolso_v3/screens/config/config_screen.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

class _Perfil extends PerfilUsuarioNotifier {
  @override
  Future<Map<String, dynamic>?> build() async => {
        'id': 'u1',
        'familia_id': 'f1',
        'role': 'admin',
        'nome': 'Frederico',
        'email': 'fred@exemplo.com',
        'familias': {'nome': 'Filhos de Rá', 'codigo_acesso': 'AB12CD'},
      };
}

Future<void> abrirConfig(WidgetTester t, {List<Override> extras = const []}) async {
  await t.pumpWidget(ProviderScope(
    overrides: [perfilUsuarioLogadoProvider.overrideWith(_Perfil.new), ...extras],
    child: MaterialApp(theme: nossoBolsoTheme(), home: const ConfigScreen()),
  ));
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('Configurações mostra o usuário e confirma antes de sair', (t) async {
    await abrirConfig(t);
    expect(t.takeException(), isNull);
    expect(find.text('Frederico'), findsOneWidget);
    expect(find.textContaining('Filhos de Rá'), findsOneWidget);

    await t.scrollUntilVisible(find.text('Sair da conta'), 200);
    await t.tap(find.text('Sair da conta'));
    await t.pumpAndSettle();
    expect(find.text('Sair da conta?'), findsOneWidget);
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();
    expect(find.text('Sair da conta?'), findsNothing);
  });
}
