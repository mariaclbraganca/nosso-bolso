import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:envelope_flutter/theme/app_theme.dart';
import 'package:envelope_flutter/screens/main_navigation_screen.dart';
import 'package:envelope_flutter/screens/login_screen.dart';
import 'package:envelope_flutter/screens/onboarding_screen.dart';
import 'package:envelope_flutter/providers/auth_provider.dart';
import 'package:envelope_flutter/providers/usuarios_provider.dart';

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  await Supabase.initialize(
    url: 'https://enqltolmazmrkdghitae.supabase.co',
    anonKey: 'sb_publishable_2Msl4wQ-mqg_6TQwjqjqhA_cfF-_FyY',
    realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 10),
  );
  runApp(const ProviderScope(child: NossoBolsoApp()));
}

class NossoBolsoApp extends ConsumerWidget {
  const NossoBolsoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Nosso Bolso',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: authState.when(
        data: (state) {
          if (state.session != null) {
            final perfilAsync = ref.watch(perfilUsuarioLogadoProvider);
            
            return perfilAsync.when(
              data: (perfil) {
                // Se o perfil existe e tem família, Dashboard. Caso contrário, Onboarding.
                if (perfil != null && perfil['familia_id'] != null) {
                  return const MainNavigationScreen();
                }
                // Se chegamos aqui com dados carregados e nada de família, Onboarding.
                return const OnboardingScreen();
              },
              loading: () => const Scaffold(
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
              error: (e, stack) => Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Erro ao carregar perfil: $e', style: const TextStyle(color: AppColors.red)),
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
          body: Center(child: CircularProgressIndicator(color: AppColors.acc)),
        ),
        error: (err, stack) => Scaffold(
          body: Center(child: Text('Erro de conexão: $err')),
        ),
      ),
    );
  }
}
