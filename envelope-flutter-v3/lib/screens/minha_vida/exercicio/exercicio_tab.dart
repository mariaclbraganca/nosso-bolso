import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nosso_bolso_v3/core/providers/exercicio_provider.dart';
import 'package:nosso_bolso_v3/core/services/saude_api_service.dart';
import 'package:nosso_bolso_v3/screens/sheets/comum.dart';
import 'package:nosso_bolso_v3/ui/components/nb_components.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';
import 'package:nosso_bolso_v3/core/plano/falas.dart';
import 'package:nosso_bolso_v3/screens/home/widgets/home_fala_time.dart';
import 'widgets/form_treino_sheet.dart';
import 'exercicio_historico_view.dart';

class ExercicioTab extends StatefulWidget {
  final String membroId;
  final String familiaId;

  const ExercicioTab({super.key, required this.membroId, required this.familiaId});

  @override
  State<ExercicioTab> createState() => _ExercicioTabState();
}

class _ExercicioTabState extends State<ExercicioTab> {
  int _aba = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Segmentado<int>(
            opcoes: const {0: 'Hoje', 1: 'Semana e histórico'},
            valor: _aba,
            onChanged: (v) => setState(() => _aba = v),
          ),
        ),
        Expanded(
          child: _aba == 0
              ? ExercicioHoje(membroId: widget.membroId, familiaId: widget.familiaId)
              : ExercicioHistoricoView(membroId: widget.membroId),
        ),
      ],
    );
  }
}

/// Treinos de hoje com o resumo do dia.
class ExercicioHoje extends ConsumerWidget {
  final String membroId;
  final String familiaId;

  const ExercicioHoje({super.key, required this.membroId, required this.familiaId});

  String get _hoje {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  void _abrirForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NBColors.papel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FormTreinoSheet(membroId: membroId, familiaId: familiaId, data: _hoje),
    );
  }

  Future<void> _deletar(WidgetRef ref, String id) async {
    try {
      await SaudeApiService.deletarExercicio(id, membroId, _hoje);
      ref.invalidate(exercicioDiaProvider);
      ref.invalidate(historicoExercicioProvider);
      avisar('Treino removido');
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoje = _hoje;
    final args = (membroId: membroId, data: hoje);
    final exercicioAsync = ref.watch(exercicioDiaProvider(args));

    final dados = exercicioAsync.asData?.value ?? {};
    final itens = (dados['exercicios'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final totalMin = (dados['total_duracao_min'] as num?)?.round() ?? 0;
    final totalCal = dados['total_calorias_kcal'] as num? ?? 0;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(exercicioDiaProvider);
        ref.invalidate(historicoExercicioProvider);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Resumo de Atividade ──
          CartaoNB(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Atividade Física de Hoje', style: NBText.secao),
                const SizedBox(height: 6),
                Text(
                  '$totalMin min · ${totalCal.toInt()} kcal',
                  style: NBText.valorCartao.copyWith(color: NBColors.ambarTexto),
                ),
                const SizedBox(height: 4),
                Text(
                  totalMin >= 30 ? 'Meta diária atingida! 🌟' : 'Faltam ${30 - totalMin} min para a meta',
                  style: NBText.legenda.copyWith(
                    color: totalMin >= 30 ? NBColors.verde : NBColors.tintaSuave,
                  ),
                ),
                const SizedBox(height: 12),
                FalaCurta(fala: falaDoExercicio(minSemana: minutosDaSemana(ref.watch(historicoExercicioProvider(membroId)).valueOrNull))),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Botão Adicionar Treino ──
          BotaoPrincipal(
            rotulo: '+ Registrar Atividade',
            onPressed: () => _abrirForm(context),
          ),
          const SizedBox(height: 16),

          // ── Lista de Exercícios ──
          Text('Treinos Realizados', style: NBText.secao),
          const SizedBox(height: 8),
          if (itens.isEmpty)
            CartaoNB(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      const Text('🏃‍♂️', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text('Nenhum treino registrado hoje', style: NBText.secao),
                      const SizedBox(height: 4),
                      Text(
                        'Qualquer movimento conta! Caminhada, yoga ou musculação.',
                        style: NBText.legenda,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...itens.map((ex) {
              final cat = ex['categoria'] as String? ?? 'cardio';
              final emoji = categoriaEmoji[cat] ?? '🏃';
              final min = ex['duracao_min'] ?? 0;
              final cal = ex['calorias_kcal'] ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CartaoNB(
                  child: Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ex['nome'] ?? 'Exercício', style: NBText.secao),
                            Text(
                              '$min minutos · ${(cal as num).toInt()} kcal',
                              style: NBText.legenda,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: NBColors.tintaSuave),
                        onPressed: () => _deletar(ref, ex['id']?.toString() ?? ''),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
