import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/usuarios_provider.dart';
import '../../providers/exercicio_provider.dart';

class HistoricoExercicioScreen extends ConsumerWidget {
  const HistoricoExercicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
    final membroId = perfil?['id'] as String? ?? '';

    if (membroId.isEmpty) {
      return const Center(child: Text('Login necessário', style: TextStyle(color: AppColors.mu)));
    }

    final historicoAsync = ref.watch(historicoExercicioProvider(membroId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: historicoAsync.when(
        data: (historico) => _buildList(historico),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.org)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, color: AppColors.mu, size: 40),
              const SizedBox(height: 12),
              const Text('Erro ao carregar histórico', style: TextStyle(color: AppColors.mu)),
              TextButton(
                onPressed: () => ref.invalidate(historicoExercicioProvider),
                child: const Text('Tentar novamente', style: TextStyle(color: AppColors.org)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> historico) {
    if (historico.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📅', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text(
              'Nenhum treino registrado ainda',
              style: TextStyle(fontSize: 15, color: AppColors.tx, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 4),
            Text(
              'Seus treinos aparecerão aqui',
              style: TextStyle(fontSize: 12, color: AppColors.mu),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: historico.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _DiaTile(dia: historico[i]),
    );
  }
}

class _DiaTile extends StatelessWidget {
  final Map<String, dynamic> dia;
  const _DiaTile({required this.dia});

  @override
  Widget build(BuildContext context) {
    final data       = dia['data'] as String? ?? '';
    final totalKcal  = (dia['total_calorias_kcal'] as num?)?.toInt() ?? 0;
    final totalMin   = (dia['total_duracao_min'] as num?)?.toInt() ?? 0;
    final exercicios = (dia['exercicios'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final dataParts  = data.split('-');
    final dataFmt    = dataParts.length == 3
        ? '${dataParts[2]}/${dataParts[1]}/${dataParts[0]}'
        : data;

    final hours   = totalMin ~/ 60;
    final minutes = totalMin % 60;
    final tempoStr = hours > 0 ? '${hours}h ${minutes}min' : '${minutes}min';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🗓️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                dataFmt,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.tx),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.org.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🔥 $totalKcal kcal',
                  style: const TextStyle(fontSize: 12, color: AppColors.org, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$tempoStr · ${exercicios.length} exercício${exercicios.length != 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 12, color: AppColors.mu),
          ),
          if (exercicios.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: exercicios.map((ex) {
                final emoji = categoriaEmoji[ex['categoria'] as String? ?? 'cardio'] ?? '🏃';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surf,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$emoji ${ex['nome']}',
                    style: const TextStyle(fontSize: 11, color: AppColors.mu),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
