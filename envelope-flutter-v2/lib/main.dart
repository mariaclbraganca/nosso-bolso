import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'constants.dart';
import 'providers/auth_provider.dart';
import 'providers/usuarios_provider.dart';
import 'services/notification_service.dart';
import 'services/ifood_notification_service.dart';
import 'services/active_notifications_service.dart';
import 'services/notificacao_fila_service.dart';
import 'screens/main_navigation_screen.dart';
import 'services/app_navigator.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/unicorn_splash_screen.dart';

/// Observer global de navegação — anexa as transições de tela como breadcrumbs
/// no Sentry, para que os crashes revelem qual tela Dart estava ativa.
final sentryObserver = SentryNavigatorObserver();

void main() async {
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.2;
        options.environment = 'production';
        // A navegação de telas é anexada como breadcrumbs pelo
        // SentryNavigatorObserver no MaterialApp — sem isso o crash só registra
        // o lifecycle do Android e não revela qual tela Dart estava ativa.
      },
      appRunner: _iniciar,
    );
  } else {
    await _iniciar();
  }
}

Future<void> _iniciar() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  await NotificationService.init();
  await IfoodNotificationService.init();
  await NotificationService.agendarTodas();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surf,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
      realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 10),
    );
  } catch (e, st) {
    await Sentry.captureException(e, stackTrace: st);
    debugPrint('Erro Supabase: $e');
  }

  runApp(const ProviderScope(child: NossoBolsoApp()));
}

class NossoBolsoApp extends ConsumerStatefulWidget {
  const NossoBolsoApp({super.key});

  @override
  ConsumerState<NossoBolsoApp> createState() => _NossoBolsoAppState();
}

class _NossoBolsoAppState extends ConsumerState<NossoBolsoApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ao voltar para o foreground, relê a bandeja de notificações. Rede de
    // segurança: se o listener em background perdeu algum evento (binder
    // instável no Android 16), as compras ainda são capturadas ao abrir o app.
    if (state == AppLifecycleState.resumed) {
      ActiveNotificationsService.processarAtivas();
      NotificacaoFilaService.flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nosso Bolso',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      // Registra a navegação de telas como breadcrumbs no Sentry — o crash
      // passa a mostrar qual tela estava ativa (rotas com settings.name).
      navigatorObservers: [sentryObserver],
      home: const _AuthGate(),
      routes: {
        '/gate': (_) => const _AuthGate(),
      },
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

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
                if (!UnicornSplashScreen.hasShown) {
                  return const UnicornSplashScreen();
                }
                return const MainNavigationScreen();
              }
              return const OnboardingScreen();
            },
            loading: () => const Scaffold(
              backgroundColor: AppColors.bg,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.acc),
                    SizedBox(height: 16),
                    Text('Sincronizando perfil...', style: TextStyle(color: AppColors.mu, fontSize: 12)),
                  ],
                ),
              ),
            ),
            error: (e, _) => Scaffold(
              backgroundColor: AppColors.bg,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Erro ao carregar perfil', style: TextStyle(color: AppColors.red)),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => ref.invalidate(perfilUsuarioLogadoProvider),
                      child: const Text('TENTAR NOVAMENTE', style: TextStyle(color: AppColors.acc)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const LoginScreen();
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.acc)),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: Text('Erro de conexão: $err', style: const TextStyle(color: AppColors.red))),
      ),
    );
  }
}
