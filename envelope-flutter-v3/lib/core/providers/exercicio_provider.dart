import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/saude_api_service.dart';

// ── Catálogo (carregado uma vez) ──────────────────────────────────────────────

final catalogoExerciciosProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return SaudeApiService.getCatalogoExercicios();
});

// ── Registro do dia ───────────────────────────────────────────────────────────

typedef ExercicioDiaArgs = ({String membroId, String data});

final exercicioDiaProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ExercicioDiaArgs>((ref, args) async {
  return SaudeApiService.getExercicioDia(args.membroId, args.data);
});

// ── Histórico (últimos 30 dias) ───────────────────────────────────────────────

final historicoExercicioProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, membroId) async {
  return SaudeApiService.getHistoricoExercicio(membroId);
});

// ── Helpers ───────────────────────────────────────────────────────────────────

const Map<String, String> categoriaEmoji = {
  'cardio':        '🏃',
  'forca':         '💪',
  'flexibilidade': '🧘',
  'esporte':       '⚽',
  'lazer':         '🎭',
};

const List<String> categorias = [
  'cardio',
  'forca',
  'flexibilidade',
  'esporte',
  'lazer',
];

const Map<String, String> categoriaNome = {
  'cardio':        'Cardio',
  'forca':         'Força',
  'flexibilidade': 'Flexibilidade',
  'esporte':       'Esporte',
  'lazer':         'Lazer',
};
