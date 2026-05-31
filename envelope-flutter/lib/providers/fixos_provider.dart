import 'package:envelope_flutter/providers/envelopes_provider.dart';
import 'package:envelope_flutter/providers/usuarios_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import 'mes_provider.dart';

/// Stream bruto — todos os fixos da família (necessário pois .stream() aceita só 1 .eq()).
final fixosStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).value;
  if (perfil == null || perfil['familia_id'] == null) return const Stream.empty();

  return supabase
      .from('gastos_fixos')
      .stream(primaryKey: ['id'])
      .eq('familia_id', perfil['familia_id'])
      .order('nome');
});

/// Fixos filtrados pelo mês selecionado — use este na tela e nos cálculos.
final fixosMesAtualProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final todos = ref.watch(fixosStreamProvider).value ?? [];
  final mes   = ref.watch(mesAtualProvider);
  return todos.where((f) => f['mes'] == mes).toList();
});

/// Total reservado = soma dos fixos PENDENTES do mês atual (pago=false)
final totalReservadoProvider = Provider<double>((ref) {
  final fixos = ref.watch(fixosMesAtualProvider);
  double total = 0;
  for (var f in fixos) {
    if (f['pago'] != true) {
      total += (f['valor'] as num).toDouble();
    }
  }
  return total;
});

/// Saldo livre para envelopes = saldo_geral - reservado
final saldoLivreProvider = Provider<double>((ref) {
  final saldoGeral = ref.watch(saldoGeralProvider).value ?? 0.0;
  final reservado = ref.watch(totalReservadoProvider);
  return saldoGeral - reservado;
});
