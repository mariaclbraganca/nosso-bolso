import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/saude_api_service.dart';
import 'usuarios_provider.dart';

final membroSaudeProvider = StateProvider<String?>((ref) {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  return perfil?['id'] as String?;
});

final perfilMetabolicoProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, membroId) async {
  if (membroId.isEmpty) return null;
  return SaudeApiService.getPerfilMetabolico(membroId);
});

typedef _DataArgs = ({String membroId, String data});

final extratoDiarioProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, _DataArgs>((ref, args) async {
  return SaudeApiService.getExtratoDiario(args.membroId, args.data);
});

final refeicoesDiaProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, _DataArgs>((ref, args) async {
  return SaudeApiService.getRefeicoesDia(args.membroId, args.data);
});

final hidratacaoDiaProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, _DataArgs>((ref, args) async {
  return SaudeApiService.getHidratacao(args.membroId, args.data);
});

typedef _JantarArgs = ({String familiaId, List<String> membroIds});

final sugestaoJantarProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, _JantarArgs>((ref, args) async {
  return SaudeApiService.getSugestaoJantar(args.familiaId, args.membroIds);
});

final historicoPesoProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, membroId) async {
  return SaudeApiService.getHistoricoPeso(membroId);
});

typedef _HistArgs = ({String membroId, String periodo});

final historicoProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, _HistArgs>((ref, args) async {
  return SaudeApiService.getHistorico(args.membroId, periodo: args.periodo);
});

typedef _DigestArgs = ({String membroId, String familiaId});

final morningDigestProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, _DigestArgs>((ref, args) async {
  return SaudeApiService.getMorningDigest(args.membroId, args.familiaId);
});
