import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gemini_monitor_service.dart';
import 'envelopes_provider.dart';
import 'fixos_provider.dart';
import 'patrimonio_provider.dart';
import 'usuarios_provider.dart';

/// Provider de análise do Monitor IA — usa cache de 24h automaticamente.
/// Invalide com ref.invalidate(monitorIAProvider) para forçar atualização.
final monitorIAProvider =
    FutureProvider.autoDispose<MonitorAnalise>((ref) async {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  if (perfil == null) throw Exception('Usuário não autenticado');

  final familiaId = perfil['familia_id'] as String? ?? '';
  final envelopes = ref.watch(envelopesProvider).value ?? [];
  final fixos = ref.watch(fixosMesAtualProvider);
  final evolucao = ref.watch(evolucaoPatrimonioProvider);

  return GeminiMonitorService.analisar(
    familiaId: familiaId,
    envelopes: envelopes,
    fixosMesAtual: fixos,
    evolucaoPatrimonio: evolucao,
  );
});

/// Provider para forçar atualização ignorando cache.
final monitorIAForcarProvider =
    FutureProvider.autoDispose<MonitorAnalise>((ref) async {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  if (perfil == null) throw Exception('Usuário não autenticado');

  final familiaId = perfil['familia_id'] as String? ?? '';
  final envelopes = ref.watch(envelopesProvider).value ?? [];
  final fixos = ref.watch(fixosMesAtualProvider);
  final evolucao = ref.watch(evolucaoPatrimonioProvider);

  return GeminiMonitorService.analisar(
    familiaId: familiaId,
    envelopes: envelopes,
    fixosMesAtual: fixos,
    evolucaoPatrimonio: evolucao,
    forcarAtualizacao: true,
  );
});
