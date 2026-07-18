import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:envelope_flutter_v2/constants.dart';
import 'package:envelope_flutter_v2/theme/app_theme.dart';
import 'package:envelope_flutter_v2/screens/auth/login_screen.dart';
import 'package:envelope_flutter_v2/screens/main_navigation_screen.dart';
import 'package:envelope_flutter_v2/providers/auth_provider.dart';
import 'package:envelope_flutter_v2/providers/usuarios_provider.dart';
import 'package:envelope_flutter_v2/screens/unicorn_splash_screen.dart';

// Credenciais de teste — conta de teste dedicada no Supabase
const _email = 'teste@nossabolso.app';
const _senha  = 'Teste@123';

// Inicializa o app sem Sentry (modo teste)
Future<void> iniciarAppTeste() async {
  await initializeDateFormatting('pt_BR', null);
  // Evita double-init se o Supabase já foi inicializado
  try {
    Supabase.instance.client;
  } catch (_) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}

Widget appTeste() => const ProviderScope(child: _AppTeste());

class _AppTeste extends ConsumerWidget {
  const _AppTeste();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Nosso Bolso',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: _AuthGateTeste(),
    );
  }
}

class _AuthGateTeste extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (state) {
        if (state.session != null) {
          final perfilAsync = ref.watch(perfilUsuarioLogadoProvider);
          return perfilAsync.when(
            data: (perfil) {
              if (perfil != null && perfil['familia_id'] != null) {
                if (!UnicornSplashScreen.hasShown) return const UnicornSplashScreen();
                return const MainNavigationScreen();
              }
              return const LoginScreen();
            },
            loading: () => const Scaffold(backgroundColor: AppColors.bg, body: Center(child: CircularProgressIndicator(color: AppColors.acc))),
            error: (_, __) => const LoginScreen(),
          );
        }
        return const LoginScreen();
      },
      loading: () => const Scaffold(backgroundColor: AppColors.bg, body: Center(child: CircularProgressIndicator(color: AppColors.acc))),
      error: (_, __) => const LoginScreen(),
    );
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    await iniciarAppTeste();
  });

  // ── Helper: faz login na tela ─────────────────────────────────────────────
  Future<void> fazerLogin(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('campo_email')), _email);
    await tester.enterText(find.byKey(const Key('campo_senha')), _senha);
    await tester.tap(find.byKey(const Key('btn_entrar')));
    await tester.pumpAndSettle(const Duration(seconds: 8));
  }

  // ── Grupo 1: Autenticação ─────────────────────────────────────────────────
  group('Fluxo de autenticação', () {
    testWidgets('Exibe tela de login ao abrir o app', (tester) async {
      await tester.pumpWidget(appTeste());
      await tester.pumpAndSettle(const Duration(seconds: 4));

      expect(find.byKey(const Key('campo_email')), findsOneWidget);
      expect(find.byKey(const Key('campo_senha')), findsOneWidget);
      expect(find.byKey(const Key('btn_entrar')),  findsOneWidget);
    });

    testWidgets('Bloqueia login com campos vazios', (tester) async {
      await tester.pumpWidget(appTeste());
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Toca em entrar sem preencher nada
      await tester.tap(find.byKey(const Key('btn_entrar')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Deve mostrar SnackBar de validação
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Login válido navega para Home com FAB', (tester) async {
      await tester.pumpWidget(appTeste());
      await tester.pumpAndSettle(const Duration(seconds: 4));

      await fazerLogin(tester);

      expect(find.byKey(const Key('fab_main')), findsOneWidget);
    });
  });

  // ── Grupo 2: Lançamento de gasto ─────────────────────────────────────────
  group('Fluxo de lançamento de gasto', () {
    testWidgets('Abre form de gasto via FAB', (tester) async {
      await tester.pumpWidget(appTeste());
      await tester.pumpAndSettle(const Duration(seconds: 4));
      await fazerLogin(tester);

      await tester.tap(find.byKey(const Key('fab_main')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gastei'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('campo_valor')),          findsOneWidget);
      expect(find.byKey(const Key('btn_registrar_gasto')),  findsOneWidget);
    });

    testWidgets('Validação impede envio sem valor', (tester) async {
      await tester.pumpWidget(appTeste());
      await tester.pumpAndSettle(const Duration(seconds: 4));
      await fazerLogin(tester);

      await tester.tap(find.byKey(const Key('fab_main')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gastei'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_registrar_gasto')));
      await tester.pumpAndSettle();

      expect(find.text('Informe o valor'), findsOneWidget);
    });
  });

  // ── Grupo 3: Navegação ────────────────────────────────────────────────────
  group('Navegação entre abas', () {
    testWidgets('Navega para Extrato', (tester) async {
      await tester.pumpWidget(appTeste());
      await tester.pumpAndSettle(const Duration(seconds: 4));
      await fazerLogin(tester);

      await tester.tap(find.byIcon(Icons.receipt_long_outlined));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Extrato tem botões de mês ou lista de transações
      expect(
        find.byIcon(Icons.chevron_left).evaluate().isNotEmpty ||
        find.byType(ListView).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Navega para Planos', (tester) async {
      await tester.pumpWidget(appTeste());
      await tester.pumpAndSettle(const Duration(seconds: 4));
      await fazerLogin(tester);

      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(
        find.text('Fixos').evaluate().isNotEmpty ||
        find.text('Metas').evaluate().isNotEmpty ||
        find.text('Contas').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
