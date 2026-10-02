import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/usuarios_provider.dart';
import 'core/services/active_notifications_service.dart';
import 'core/services/app_navigator.dart';
import 'core/services/ifood_notification_service.dart';
import 'core/services/notificacao_fila_service.dart';
import 'core/services/notification_service.dart';
import 'screens/auth/entrar_screen.dart';
import 'screens/auth/onboarding_pendente_screen.dart';
import 'screens/shell/shell_screen.dart';
import 'ui/theme/nb_theme.dart';
import 'ui/unicorn/unicorn.dart';

final sentryObserver = SentryNavigatorObserver();

void main() async {
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (o) {
        o.dsn = sentryDsn;
        o.tracesSampleRate = 0.2;
        o.environment = 'production';
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

  // Supabase antes dos listeners: o init deles faz flush da fila, que usa a sessão.
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 10),
    );
  } catch (e, st) {
    await Sentry.captureException(e, stackTrace: st);
  }

  await NotificationService.init();
  await IfoodNotificationService.init();
  await NotificationService.agendarTodas();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: NBColors.cartao,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const ProviderScope(child: NossoBolsoApp()));
}

class NossoBolsoApp extends StatefulWidget {
  const NossoBolsoApp({super.key});

  @override
  State<NossoBolsoApp> createState() => _NossoBolsoAppState();
}

class _NossoBolsoAppState extends State<NossoBolsoApp> with WidgetsBindingObserver {
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
    // Rede de segurança do listener em background (Android 16): relê a bandeja ao voltar.
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
      theme: nossoBolsoTheme(),
      locale: const Locale('pt', 'BR'),
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorObservers: [sentryObserver],
      builder: (context, child) => UnicornStage(child: child ?? const SizedBox.shrink()),
      home: const _Portao(),
    );
  }
}

class _Portao extends ConsumerWidget {
  const _Portao();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const carregando = Scaffold(body: UnicornCarregando(texto: 'Abrindo o bolso…'));
    return ref.watch(authStateProvider).when(
          loading: () => carregando,
          error: (e, _) => const Scaffold(body: UnicornErro(mensagem: 'Sem conexão com o servidor. Verifique a internet.')),
          data: (auth) {
            if (auth.session == null) return const EntrarScreen();
            return ref.watch(perfilUsuarioLogadoProvider).when(
                  loading: () => carregando,
                  error: (e, _) => Scaffold(
                    body: UnicornErro(
                      mensagem: 'Não consegui carregar seu perfil.',
                      onTentar: () => ref.invalidate(perfilUsuarioLogadoProvider),
                    ),
                  ),
                  data: (perfil) => perfil != null && perfil['familia_id'] != null
                      ? const ShellScreen()
                      : const OnboardingPendenteScreen(),
                );
          },
        );
  }
}
