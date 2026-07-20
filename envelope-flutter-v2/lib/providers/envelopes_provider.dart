import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import 'usuarios_provider.dart';

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

/// Saldo geral disponível da família — LÊ a fonte de verdade (tabela `saldo_geral`)
/// via Realtime. NÃO calcula em Dart (RN01 — TRIGGER_IS_LAW): o valor já reflete
/// receitas, abastecimentos (trigger) e fixos pagos (routes/fixos.py).
final saldoGeralProvider = StreamProvider<double>((ref) {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  if (perfil == null || perfil['familia_id'] == null) return const Stream.empty();

  return supabase
      .from('saldo_geral')
      .stream(primaryKey: ['id'])
      .eq('familia_id', perfil['familia_id'])
      .map((rows) => rows.isEmpty
          ? 0.0
          : (rows.first['valor_total_disponivel'] as num?)?.toDouble() ?? 0.0);
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
