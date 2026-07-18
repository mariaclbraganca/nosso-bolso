import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/exercicio_provider.dart';

class DashboardExercicioView extends ConsumerWidget {
  final String membroId;

  const DashboardExercicioView({super.key, required this.membroId});

  String get _hoje {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(exercicioDiaProvider((membroId: membroId, data: _hoje)));

    return RefreshIndicator(
      color: AppColors.org,
      backgroundColor: AppColors.surf,
      onRefresh: () async => ref.invalidate(exercicioDiaProvider),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: AppColors.org)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Erro: $e', style: const TextStyle(color: AppColors.red)),
              ),
              data: (data) => _buildContent(data),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    final treinos     = (data['treinos'] as List<dynamic>?) ?? [];
    final totalKcal   = (data['total_calorias_kcal'] as num?)?.toInt() ?? 0;
    final totalMin    = (data['total_minutos'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            _kpiChip('🔥', '${totalKcal} kcal', 'Queimadas'),
            const SizedBox(width: 10),
            _kpiChip('⏱️', '${totalMin} min', 'Duração'),
            const SizedBox(width: 10),
            _kpiChip('🏋️', '${treinos.length}', 'Exercícios'),
          ]),
        ),

        if (treinos.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                const Text('🏃', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text(
                  'Nenhum treino hoje ainda!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.tx),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Toque no + para registrar seu primeiro exercício do dia.',
                  style: TextStyle(color: AppColors.mu, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Text(
              'TREINOS DO DIA',
              style: TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
          ),
          ...treinos.map((t) => _treinoCard(t as Map<String, dynamic>)),
        ],
      ],
    );
  }

  Widget _kpiChip(String emoji, String valor, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(valor, style: const TextStyle(color: AppColors.tx, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label, style: const TextStyle(color: AppColors.mu, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _treinoCard(Map<String, dynamic> t) {
    final nome     = t['nome_exercicio'] as String? ?? t['tipo'] as String? ?? 'Exercício';
    final kcal     = (t['calorias_kcal'] as num?)?.toInt() ?? 0;
    final minutos  = (t['duracao_minutos'] as num?)?.toInt() ?? 0;
    final series   = (t['series'] as num?)?.toInt();
    final reps     = (t['repeticoes'] as num?)?.toInt();
    final peso     = (t['peso_kg'] as num?)?.toDouble();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.org.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fitness_center_rounded, color: AppColors.org, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: const TextStyle(color: AppColors.tx, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 3),
                Text(
                  [
                    if (minutos > 0) '$minutos min',
                    if (series != null) '$series séries',
                    if (reps != null) '$reps reps',
                    if (peso != null) '${peso}kg',
                  ].join(' • '),
                  style: const TextStyle(color: AppColors.mu, fontSize: 12),
                ),
              ],
            ),
          ),
          if (kcal > 0)
            Text('$kcal kcal', style: const TextStyle(color: AppColors.org, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
