import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants.dart';

/// Gerencia o estado de autenticação do Supabase
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

/// Retorna o usuário logado atualmente (ou null).
/// Ao deslogar (signedOut), retorna null imediatamente — sem cair no
/// fallback de currentUser, que ainda poderia trazer o usuário do cache.
final currentUserProvider = Provider<User?>((ref) {
  final asyncAuth = ref.watch(authStateProvider);
  final authState = asyncAuth.value;
  if (authState != null) {
    if (authState.event == AuthChangeEvent.signedOut) return null;
    return authState.session?.user;
  }
  // Antes do primeiro evento do stream: usa a sessão persistida (restore).
  return supabase.auth.currentUser;
});

/// Provider para gerenciar as ações de Auth (Login, Logout, Google)
final authServiceProvider = Provider((ref) => AuthService());

class AuthService {
  final _supabase = supabase;

  /// Login com Email e Senha
  Future<void> signInWithEmail(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  /// Registro com Email e Senha
  /// Cria o auth user E o registro na tabela public.usuarios
  Future<void> signUpWithEmail(String email, String password, String name) async {
    final res = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'nome': name},
    );

    // Criar registro na tabela usuarios vinculado ao auth user
    final user = res.user;
    if (user != null) {
      await _supabase.from('usuarios').upsert({
        'id': user.id,
        'email': email,
        'nome': name,
      });
    }
  }

  /// Logout
  Future<void> signOut() async {
    // Desconecta também do Google (senão o app "lembra" a conta e não
    // pede seleção no próximo login). Ignora erro se não logou por Google.
    try {
      if (!kIsWeb) await GoogleSignIn().signOut();
    } catch (_) {}
    await _supabase.auth.signOut();
  }

  /// Recuperar Senha
  Future<void> recoverPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  /// Login via Google (OAuth)
  /// Web: usa signInWithOAuth (redirect flow do Supabase)
  /// Mobile: usa google_sign_in nativo + signInWithIdToken
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      // No Web, o Supabase gerencia todo o fluxo OAuth via redirect
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Uri.base.origin,
      );
      return;
    }

    // Mobile: fluxo nativo com google_sign_in.
    // serverClientId = Web Client ID (Google Cloud). Obrigatório para o
    // signInWithIdToken do Supabase aceitar o token gerado pelo Google.
    const webClientId =
        '148214132378-av2pjofruhg6a76uruh3o8a2jond8a3m.apps.googleusercontent.com';
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: ['email'],
      serverClientId: webClientId,
    );
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return;

    final googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (accessToken == null) throw 'No Access Token found.';
    if (idToken == null) throw 'No ID Token found.';

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }
}
