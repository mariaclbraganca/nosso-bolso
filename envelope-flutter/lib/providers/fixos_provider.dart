import 'package:envelope_flutter/providers/envelopes_provider.dart';
import 'package:envelope_flutter/providers/usuarios_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';

/// Stream de gastos fixos em tempo real com isolamento por família
final fixosStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).value;
  if (perfil == null || perfil['familia_id'] == null) return const Stream.empty();

  return supabase
      .from('gastos_fixos')
      .stream(primaryKey: ['id'])
      .eq('familia_id', perfil['familia_id'])
      .order('nome');
});

/// Total reservado = soma dos fixos PENDENTES (pago=false)
final totalReservadoProvider = Provider<double>((ref) {
  final fixos = ref.watch(fixosStreamProvider).value ?? [];
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
