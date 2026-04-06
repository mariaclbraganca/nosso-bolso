import 'package:envelope_flutter/providers/usuarios_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import './envelopes_provider.dart';
import './mes_provider.dart';
import '../services/api_service.dart';
import 'dart:async';

/// Provedor de transações em Tempo Real com isolamento por família
final transacoesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  if (perfil == null || perfil['familia_id'] == null) return const Stream.empty();

  return supabase
      .from('transacoes')
      .stream(primaryKey: ['id'])
      .eq('familia_id', perfil['familia_id'])
      .order('data', ascending: false);
});

/// Transações filtradas pelo mês selecionado + detalhes resolvidos
final transacoesComDetalhesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final transacoes = ref.watch(transacoesStreamProvider).value ?? [];
  final envelopes = ref.watch(envelopesProvider).value ?? [];
  final usuarios = ref.watch(listaUsuariosProvider).value ?? [];
  final mesSelecionado = ref.watch(mesAtualProvider); // 'yyyy-MM'

  return transacoes.where((t) {
    // Filtrar pelo mês selecionado
    final data = t['data']?.toString() ?? t['created_at']?.toString() ?? '';
    if (data.length >= 7) {
      return data.substring(0, 7) == mesSelecionado;
    }
    return false;
  }).map((t) {
    final env = envelopes.firstWhere((e) => e['id'] == t['envelope_id'], orElse: () => {});
    final usr = usuarios.firstWhere((u) => u['id'] == t['usuario_id'], orElse: () => {});

    return {
      ...t,
      'usuarios': {'nome': usr['nome'] ?? '?'},
      'envelopes': {
        'nome_envelope': env['nome_envelope'] ?? 'Sem envelope',
        'emoji': env['emoji'] ?? '💰'
      },
    };
  }).toList();
});

/// Record para estatísticas rápidas
class MesStats {
  final double totalReceita;
  final double totalDespesa;
  final double saldo;
  MesStats({this.totalReceita = 0, this.totalDespesa = 0, this.saldo = 0});
}

/// Provider para estatísticas de um mês específico (SPEC-09)
final statsPorMesProvider = Provider.family<MesStats, String>((ref, mes) {
  final transacoes = ref.watch(transacoesStreamProvider).value ?? [];
  
  double rec = 0;
  double desp = 0;
  
  for (var t in transacoes) {
    final data = t['data']?.toString() ?? t['created_at']?.toString() ?? '';
    if (data.startsWith(mes)) {
      final val = (t['valor'] as num?)?.toDouble() ?? 0.0;
      if (t['tipo'] == 'receita') rec += val;
      if (t['tipo'] == 'despesa') desp += val;
    }
  }
  
  return MesStats(totalReceita: rec, totalDespesa: desp, saldo: rec - desp);
});

/// Provedor para Paginação Infinita via API FastAPI (SPEC-12)
class PagedTransacoesNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  int _currentPage = 1;
  static const int _limit = 20;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  @override
  FutureOr<List<Map<String, dynamic>>> build() async {
    _currentPage = 1;
    return _fetchPage(1);
  }

  Future<List<Map<String, dynamic>>> _fetchPage(int page) async {
    final perfil = ref.read(perfilUsuarioLogadoProvider).asData?.value;
    if (perfil == null || perfil['familia_id'] == null) return [];

    final result = await ApiService.get(
      '/transacoes/extrato', 
      perfil['familia_id'], 
      params: {
        'page': page.toString(),
        'limit': _limit.toString(),
      }
    );
    
    final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(result);
    if (items.length < _limit) _hasMore = false;
    return items;
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || !_hasMore) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      _currentPage++;
      final nextItems = await _fetchPage(_currentPage);
      return [...state.value ?? [], ...nextItems];
    });
  }
}

final pagedTransacoesProvider = AsyncNotifierProvider<PagedTransacoesNotifier, List<Map<String, dynamic>>>(
  () => PagedTransacoesNotifier(),
);
