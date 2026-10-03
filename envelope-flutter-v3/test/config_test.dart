import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nosso_bolso_v3/screens/config/pin_config_screen.dart';
import 'package:nosso_bolso_v3/screens/config/ia_config_screen.dart';
import 'package:nosso_bolso_v3/core/services/gemini_key_service.dart';
import 'package:nosso_bolso_v3/core/providers/pin_provider.dart';
import 'package:nosso_bolso_v3/core/providers/usuarios_provider.dart';
import 'package:nosso_bolso_v3/screens/config/config_screen.dart';
import 'package:nosso_bolso_v3/screens/config/notificacoes_screen.dart';
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

  testWidgets('Central leva a Notificações e captura', (t) async {
    await abrirConfig(t, extras: [permissaoCapturaProvider.overrideWith((ref) async => true)]);
    await t.tap(find.text('Notificações e captura'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('CAPTURA AUTOMÁTICA'), findsOneWidget);
  });

  for (final permitido in [true, false]) {
    testWidgets('Captura com permissão=$permitido', (t) async {
      await t.pumpWidget(ProviderScope(
        overrides: [permissaoCapturaProvider.overrideWith((ref) async => permitido)],
        child: MaterialApp(theme: nossoBolsoTheme(), home: const NotificacoesScreen()),
      ));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull);
      expect(find.text('Ativa'), permitido ? findsNWidgets(2) : findsNothing);
      expect(find.text('Conceder permissão'), permitido ? findsNothing : findsOneWidget);
    });
  }

  testWidgets('Permissões do sistema negadas mostram o botão de pedir', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        permissaoCapturaProvider.overrideWith((ref) async => true),
        permissoesSistemaProvider.overrideWith((ref) async => (false, false)),
      ],
      child: MaterialApp(theme: nossoBolsoTheme(), home: const NotificacoesScreen()),
    ));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    expect(find.text('Sem permissão'), findsNWidgets(2));
    expect(find.text('Permitir notificações e alarmes'), findsOneWidget);
  });

  testWidgets('Lembretes ligam e desligam e ficam salvos', (t) async {
    SharedPreferences.setMockInitialValues({'notif_cafe': false});
    await t.pumpWidget(ProviderScope(
      overrides: [
        permissaoCapturaProvider.overrideWith((ref) async => true),
        permissoesSistemaProvider.overrideWith((ref) async => (true, true)),
      ],
      child: MaterialApp(theme: nossoBolsoTheme(), home: const NotificacoesScreen()),
    ));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final cafe = t.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Café da manhã'));
    expect(cafe.value, isFalse);

    final hidratacao = find.widgetWithText(SwitchListTile, 'Hidratação');
    await t.ensureVisible(hidratacao);
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: hidratacao, matching: find.byType(Switch)));
    await t.pumpAndSettle();
    expect(t.widget<SwitchListTile>(hidratacao).value, isFalse);
    expect((await SharedPreferences.getInstance()).getBool('notif_hidratacao'), isFalse);
    expect(find.text('Alarme do fechamento do dia'), findsOneWidget);
  });

  testWidgets('PIN: cria e depois troca, recusando PIN atual errado', (t) async {
    FlutterSecureStorage.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(navigatorKey: nav, theme: nossoBolsoTheme(), home: const Scaffold()),
    ));
    Future<void> abrir() async {
      nav.currentState!.push(MaterialPageRoute(builder: (_) => const PinConfigScreen()));
      await t.pumpAndSettle();
    }

    await abrir();
    await t.enterText(find.widgetWithText(TextField, 'PIN'), '1234');
    await t.enterText(find.widgetWithText(TextField, 'Repita o PIN'), '1234');
    await t.tap(find.text('Criar PIN'));
    await t.pumpAndSettle();
    expect(find.byType(PinConfigScreen), findsNothing);
    expect(await container.read(pinConfiguradoProvider.future), isTrue);
    expect(await container.read(pinNotifierProvider.notifier).verificarPin('1234'), isTrue);

    await abrir();
    await t.enterText(find.widgetWithText(TextField, 'PIN atual'), '0000');
    await t.enterText(find.widgetWithText(TextField, 'PIN novo'), '5678');
    await t.enterText(find.widgetWithText(TextField, 'Repita o PIN'), '5678');
    await t.tap(find.widgetWithText(FilledButton, 'Trocar PIN'));
    await t.pumpAndSettle();
    expect(find.byType(PinConfigScreen), findsOneWidget, reason: 'PIN atual errado não pode fechar a tela');
    expect(await container.read(pinNotifierProvider.notifier).verificarPin('1234'), isTrue);

    await t.enterText(find.widgetWithText(TextField, 'PIN atual'), '1234');
    await t.tap(find.widgetWithText(FilledButton, 'Trocar PIN'));
    await t.pumpAndSettle();
    expect(await container.read(pinNotifierProvider.notifier).verificarPin('5678'), isTrue);
  });

  testWidgets('IA: mostra chaves salvas e remove só a escolhida', (t) async {
    FlutterSecureStorage.setMockInitialValues({
      'ia_gemini_key_1': 'AIza-principal',
      'ia_gemini_key_2': 'AIza-reserva',
    });
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(theme: nossoBolsoTheme(), home: const IaConfigScreen()),
    ));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('AIza-principal'), findsOneWidget);
    expect(find.text('AIza-reserva'), findsOneWidget);

    final reserva = find.widgetWithText(TextField, 'Chave reserva 1');
    await t.tap(find.descendant(of: reserva, matching: find.byTooltip('Remover')));
    await t.pumpAndSettle();
    expect(await GeminiKeyService.carregarChavesSalvas(), ['AIza-principal', '', '']);
  });
}
