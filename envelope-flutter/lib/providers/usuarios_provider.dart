import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import 'auth_provider.dart';

/// Provedor para o filtro de usuário selecionado nas telas de Extrato/Relatório
/// Se null, mostra 'Todos'.
final usuarioFiltroProvider = StateProvider<String?>((ref) => null);

/// Busca a lista de usuários da mesma família para filtros e labels
final listaUsuariosProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).value;
  if (perfil == null || perfil['familia_id'] == null) return [];

  final res = await supabase
      .from('usuarios')
      .select('*')
      .eq('familia_id', perfil['familia_id'])
      .order('nome');
  return List<Map<String, dynamic>>.from(res);
});

/// Notifier para gerenciar o perfil do usuário logado de forma estável.
/// Substitui o StreamProvider para garantir que JOINS e estados transientes sejam tratados com precisão.
class PerfilUsuarioNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  FutureOr<Map<String, dynamic>?> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;

    final res = await supabase
        .from('usuarios')
        .select('*, familias(*)')
        .eq('id', user.id)
        .maybeSingle();
    return res;
  }

  /// Força a atualização do perfil após ações de onboarding
  Future<void> recarregar() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => await build());
  }

  /// Injeção manual de estado (Optimistic Update) para evitar loops de latência
  void atualizarEstado(Map<String, dynamic>? novoPerfil) {
    state = AsyncData(novoPerfil);
  }
}

final perfilUsuarioLogadoProvider = AsyncNotifierProvider<PerfilUsuarioNotifier, Map<String, dynamic>?>(
  () => PerfilUsuarioNotifier(),
);
