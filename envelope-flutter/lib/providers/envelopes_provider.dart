import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import 'usuarios_provider.dart';

final envelopesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  if (perfil == null || perfil['familia_id'] == null) return const Stream.empty();
  
  return supabase
      .from('envelopes')
      .stream(primaryKey: ['id'])
      .eq('familia_id', perfil['familia_id'])
      .order('nome_envelope');
});

final saldoGeralProvider = StreamProvider<double>((ref) {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  if (perfil == null || perfil['familia_id'] == null) return const Stream.empty();

  return supabase
      .from('saldo_geral')
      .stream(primaryKey: ['id'])
      .eq('familia_id', perfil['familia_id'])
      .map((list) {
        if (list.isEmpty) return 0.0;
        return (list.first['valor_total_disponivel'] as num).toDouble();
      });
});

// Estatísticas globais filtradas por família
final totalStatsProvider = Provider<Map<String, double>>((ref) {
  final envelopes = ref.watch(envelopesProvider).value ?? [];
  
  double totalPlanned = 0;
  double totalInEnvelopes = 0;
  
  for (var e in envelopes) {
    totalPlanned += (e['valor_planejado'] as num).toDouble();
    totalInEnvelopes += (e['saldo_atual'] as num).toDouble();
  }
  
  double totalSpent = totalPlanned - totalInEnvelopes;

  return {
    'planned': totalPlanned,
    'available': totalInEnvelopes,
    'spent': totalSpent,
  };
});
