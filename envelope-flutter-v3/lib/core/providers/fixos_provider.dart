import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'usuarios_provider.dart';
import '../constants.dart';
import '../services/notification_service.dart';
import 'mes_provider.dart';
import 'envelopes_provider.dart';

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
  final fixosMes = todos.where((f) => f['mes'] == mes).toList();

  // Agenda notificações sempre que a lista muda (idempotente por ID)
  NotificationService.agendarAlertasFixos(fixosMes, mes);

  return fixosMes;
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

/// Saldo livre para distribuir em envelopes = saldo_geral atual − fixos pendentes.
/// `saldo_geral` (fonte de verdade) já desconta fixos PAGOS; aqui subtraímos os
/// fixos ainda NÃO pagos como reserva ("quanto posso distribuir sem furar as contas").
final saldoLivreProvider = Provider<double>((ref) {
  final saldoGeral = ref.watch(saldoGeralProvider).value ?? 0;
  final reservado  = ref.watch(totalReservadoProvider); // fixos pendentes do mês
  return saldoGeral - reservado;
});
