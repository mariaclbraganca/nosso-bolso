import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import 'usuarios_provider.dart';
import 'transacoes_provider.dart';

/// Todos os envelopes da família (sem filtro — usado internamente e por admins)
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

  // Recalcula em tempo real: receitas do mês - abastecimentos do mês
  final transacoes = ref.watch(transacoesStreamProvider).value ?? [];
  final familiaId = perfil['familia_id'] as String;
  final mesAtual = DateTime.now();
  final mesStr = '${mesAtual.year}-${mesAtual.month.toString().padLeft(2, '0')}';

  double receitas = 0;
  double abastecimentos = 0;
  for (final t in transacoes) {
    if (t['deleted_at'] != null) continue;
    if (t['familia_id'] != familiaId) continue;
    final data = t['data']?.toString() ?? t['created_at']?.toString() ?? '';
    if (!data.startsWith(mesStr)) continue;
    final val = (t['valor'] as num?)?.toDouble() ?? 0.0;
    if (t['tipo'] == 'receita') receitas += val;
    if (t['tipo'] == 'abastecimento') abastecimentos += val;
  }

  return Stream.value(receitas - abastecimentos);
});

/// Envelopes visíveis para o usuário atual (admin vê tudo, membro vê só públicos)
final envelopesViseisProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  final isAdmin = perfil?['role'] == 'admin';
  final todos = ref.watch(envelopesProvider).value ?? [];
  if (isAdmin) return todos;
  return todos.where((e) => e['visivel_apenas_admin'] != true).toList();
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
