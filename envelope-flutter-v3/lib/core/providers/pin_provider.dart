import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kPinKey = 'admin_pin';
const _storage = FlutterSecureStorage();

// Estado da sessão PIN: null = não desbloqueado, DateTime = quando foi desbloqueado
final _pinSessionProvider = StateProvider<DateTime?>((ref) => null);

// Duração da sessão ativa antes de pedir PIN novamente
const _sessionDuration = Duration(minutes: 5);

/// Verifica se o PIN já foi configurado neste dispositivo
final pinConfiguradoProvider = FutureProvider<bool>((ref) async {
  final pin = await _storage.read(key: _kPinKey);
  return pin != null && pin.isNotEmpty;
});

/// Verifica se a sessão admin está ativa (desbloqueada recentemente)
final pinDesbloqueadoProvider = Provider<bool>((ref) {
  final session = ref.watch(_pinSessionProvider);
  if (session == null) return false;
  return DateTime.now().difference(session) < _sessionDuration;
});

/// Notifier para operações de PIN
class PinNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Salva o PIN (primeira configuração ou troca)
  Future<void> salvarPin(String pin) async {
    await _storage.write(key: _kPinKey, value: pin);
    // Considera sessão ativa ao definir PIN
    ref.read(_pinSessionProvider.notifier).state = DateTime.now();
  }

  /// Verifica PIN e desbloqueia sessão se correto. Retorna true se correto.
  Future<bool> verificarPin(String pin) async {
    final salvo = await _storage.read(key: _kPinKey);
    if (salvo == pin) {
      ref.read(_pinSessionProvider.notifier).state = DateTime.now();
      return true;
    }
    return false;
  }

  /// Renova a sessão ativa (chamar em interações dentro de telas protegidas)
  void renovarSessao() {
    if (ref.read(_pinSessionProvider) != null) {
      ref.read(_pinSessionProvider.notifier).state = DateTime.now();
    }
  }

  /// Bloqueia manualmente (logout da sessão admin)
  void bloquear() {
    ref.read(_pinSessionProvider.notifier).state = null;
  }

  /// Remove o PIN do dispositivo (não usar sem confirmação)
  Future<void> removerPin() async {
    await _storage.delete(key: _kPinKey);
    ref.read(_pinSessionProvider.notifier).state = null;
  }
}

final pinNotifierProvider = NotifierProvider<PinNotifier, void>(
  () => PinNotifier(),
);
