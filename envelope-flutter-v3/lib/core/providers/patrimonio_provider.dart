import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../services/gemini_patrimonio_service.dart';
import 'usuarios_provider.dart';

final patrimonioProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  if (perfil == null || perfil['familia_id'] == null) return const Stream.empty();

  return supabase
      .from('contas_patrimonio')
      .stream(primaryKey: ['id'])
      .eq('familia_id', perfil['familia_id'])
      .order('created_at');
});

/// Total consolidado de patrimônio
final totalPatrimonioProvider = Provider<double>((ref) {
  final contas = ref.watch(patrimonioProvider).value ?? [];
  return contas.fold(0.0, (sum, c) => sum + ((c['saldo_atual'] as num?)?.toDouble() ?? 0.0));
});

/// Provider de análise IA do portfólio — invalidar manualmente para atualizar.
final patrimonioAnaliseProvider =
    FutureProvider.autoDispose<PatrimonioAnalise>((ref) async {
  final contas = ref.watch(patrimonioProvider).value ?? [];
  return GeminiPatrimonioService.analisar(contas);
});

// ── Snapshots de patrimônio ───────────────────────────────────────────────────

/// Busca todos os snapshots da família ordenados por mês.
final snapshotsPatrimonioProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  if (perfil == null || perfil['familia_id'] == null) return [];

  final rows = await supabase
      .from('snapshots_patrimonio')
      .select('mes, saldo, conta_id')
      .eq('familia_id', perfil['familia_id'] as String)
      .order('mes', ascending: true);

  return List<Map<String, dynamic>>.from(rows);
});

/// Agrega snapshots por mês — retorna lista de {mes, total} ordenada.
final evolucaoPatrimonioProvider =
    Provider.autoDispose<List<({String mes, double total})>>((ref) {
  final snapshots = ref.watch(snapshotsPatrimonioProvider).value ?? [];

  final porMes = <String, double>{};
  for (final s in snapshots) {
    final mes = s['mes'] as String;
    final saldo = (s['saldo'] as num).toDouble();
    porMes[mes] = (porMes[mes] ?? 0) + saldo;
  }

  final lista = porMes.entries
      .map((e) => (mes: e.key, total: e.value))
      .toList()
    ..sort((a, b) => a.mes.compareTo(b.mes));

  return lista;
});

/// Salva snapshot do mês atual para todas as contas da família.
/// Usa UPSERT — seguro chamar múltiplas vezes no mesmo mês.
Future<void> salvarSnapshotMesAtual(
  List<Map<String, dynamic>> contas,
  String familiaId,
) async {
  if (contas.isEmpty) return;
  final agora = DateTime.now();
  final mes =
      '${agora.year}-${agora.month.toString().padLeft(2, '0')}';

  try {
    final rows = contas
        .where((c) => c['id'] != null)
        .map((c) => {
              'familia_id': familiaId,
              'conta_id': c['id'] as String,
              'mes': mes,
              'saldo': (c['saldo_atual'] as num?)?.toDouble() ?? 0.0,
            })
        .toList();

    if (rows.isEmpty) return;

    await supabase.from('snapshots_patrimonio').upsert(
          rows,
          onConflict: 'conta_id,mes',
        );
  } catch (e) {
    debugPrint('Snapshot patrimônio: erro ao salvar — $e');
  }
}
