import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/exercicio_provider.dart';

class HistoricoExercicioView extends ConsumerWidget {
  final String membroId;

  const HistoricoExercicioView({super.key, required this.membroId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historicoExercicioProvider(membroId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.org)),
      error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: AppColors.red))),
      data: (historico) {
        if (historico.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🏋️', style: TextStyle(fontSize: 64)),
                  SizedBox(height: 16),
                  Text('Nenhum treino registrado ainda', style: TextStyle(fontSize: 16, color: AppColors.tx, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  SizedBox(height: 8),
                  Text('Registre seus exercícios diariamente para ver o histórico aqui.', style: TextStyle(color: AppColors.mu, fontSize: 13), textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        // Agrupa por data
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final t in historico) {
          final raw  = t['data'] as String? ?? t['created_at'] as String? ?? '';
          final data = raw.length >= 10 ? raw.substring(0, 10) : raw;
          grouped.putIfAbsent(data, () => []).add(t as Map<String, dynamic>);
        }
        final datas = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: datas.length,
          itemBuilder: (context, i) {
            final data    = datas[i];
            final treinos = grouped[data]!;
            final kcalTotal = treinos.fold<int>(0, (sum, t) => sum + ((t['calorias_kcal'] as num?)?.toInt() ?? 0));
            final dt = DateTime.tryParse(data);
            final label = dt != null ? DateFormat('EEEE, dd/MM', 'pt_BR').format(dt) : data;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                      if (kcalTotal > 0)
                        Text('🔥 $kcalTotal kcal', style: const TextStyle(fontSize: 11, color: AppColors.org)),
                    ],
                  ),
                ),
                ...treinos.map((t) => _treinoTile(t)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _treinoTile(Map<String, dynamic> t) {
    final nome    = t['nome_exercicio'] as String? ?? t['tipo'] as String? ?? 'Exercício';
    final kcal    = (t['calorias_kcal'] as num?)?.toInt() ?? 0;
    final minutos = (t['duracao_minutos'] as num?)?.toInt() ?? 0;
    final series  = (t['series'] as num?)?.toInt();
    final reps    = (t['repeticoes'] as num?)?.toInt();
    final peso    = (t['peso_kg'] as num?)?.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.org.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.fitness_center_rounded, color: AppColors.org, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: const TextStyle(color: AppColors.tx, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  [
                    if (minutos > 0) '$minutos min',
                    if (series != null) '$series séries',
                    if (reps != null) '$reps reps',
                    if (peso != null) '${peso}kg',
                  ].join(' • '),
                  style: const TextStyle(color: AppColors.mu, fontSize: 11),
                ),
              ],
            ),
          ),
          if (kcal > 0)
            Text('$kcal kcal', style: const TextStyle(color: AppColors.org, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}
