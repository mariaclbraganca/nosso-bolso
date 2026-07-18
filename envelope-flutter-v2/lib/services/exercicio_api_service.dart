import 'saude_api_service.dart';

class ExercicioApiService {
  static Future<void> registrarTreino({
    required String membroId,
    required String tipo,
    required String nomeExercicio,
    double caloriasKcal = 0,
    int? duracaoMinutos,
    int? series,
    int? repeticoes,
    double? pesoKg,
  }) async {
    final hoje = DateTime.now();
    final data = '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';

    await SaudeApiService.registrarExercicio({
      'membro_id':          membroId,
      'tipo':               tipo,
      'nome_exercicio':     nomeExercicio,
      'calorias_kcal':      caloriasKcal,
      'data':               data,
      if (duracaoMinutos != null) 'duracao_minutos': duracaoMinutos,
      if (series != null)         'series':          series,
      if (repeticoes != null)     'repeticoes':      repeticoes,
      if (pesoKg != null)         'peso_kg':         pesoKg,
    });
  }
}
