import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/usuarios_provider.dart';
import '../../providers/exercicio_provider.dart';
import '../../services/saude_api_service.dart';
import 'registrar_treino_sheet.dart';

class DashboardExercicioScreen extends ConsumerWidget {
  const DashboardExercicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
    final membroId = perfil?['id'] as String? ?? '';

    final hoje = DateTime.now();
    final dataStr = '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';

    if (membroId.isEmpty) {
      return const Center(
        child: Text('Faça login para registrar treinos', style: TextStyle(color: AppColors.mu)),
      );
    }

    final diaAsync = ref.watch(exercicioDiaProvider((membroId: membroId, data: dataStr)));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: diaAsync.when(
        data: (dia) => _buildContent(context, ref, dia, membroId, dataStr),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.org)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, color: AppColors.mu, size: 40),
              const SizedBox(height: 12),
              Text('Erro ao carregar', style: const TextStyle(color: AppColors.mu)),
              TextButton(
                onPressed: () => ref.invalidate(exercicioDiaProvider),
                child: const Text('Tentar novamente', style: TextStyle(color: AppColors.org)),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.org,
        foregroundColor: Colors.black,
        onPressed: () => _abrirRegistro(context, ref, membroId, dataStr),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> dia,
    String membroId,
    String dataStr,
  ) {
    final exercicios = (dia['exercicios'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final totalKcal = (dia['total_calorias_kcal'] as num?)?.toInt() ?? 0;
    final totalMin  = (dia['total_duracao_min'] as num?)?.toInt() ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(totalKcal: totalKcal, totalMin: totalMin),
        const SizedBox(height: 20),
        if (exercicios.isEmpty)
          _EmptyState(onAdd: () => _abrirRegistro(context, ref, membroId, dataStr))
        else ...[
          const Text(
            'TREINOS DE HOJE',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mu, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          ...exercicios.map((ex) => _ExercicioTile(
                exercicio: ex,
                onDelete: () async {
                  await SaudeApiService.deletarExercicio(
                    ex['id'] as String,
                    membroId,
                    dataStr,
                  );
                  ref.invalidate(exercicioDiaProvider);
                },
              )),
        ],
      ],
    );
  }

  void _abrirRegistro(BuildContext context, WidgetRef ref, String membroId, String dataStr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RegistrarTreinoSheet(
        data: dataStr,
        onSaved: () => ref.invalidate(exercicioDiaProvider),
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final int totalKcal;
  final int totalMin;
  const _SummaryCard({required this.totalKcal, required this.totalMin});

  @override
  Widget build(BuildContext context) {
    final hours   = totalMin ~/ 60;
    final minutes = totalMin % 60;
    final tempoStr = hours > 0 ? '${hours}h ${minutes}min' : '${minutes}min';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.org.withOpacity(0.2), AppColors.org.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.org.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  totalKcal > 0 ? '$totalKcal kcal queimadas' : 'Nenhum treino hoje',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.tx,
                  ),
                ),
                if (totalMin > 0)
                  Text(
                    '$tempoStr de atividade',
                    style: const TextStyle(fontSize: 13, color: AppColors.mu),
                  )
                else
                  const Text(
                    'Toque em + para adicionar',
                    style: TextStyle(fontSize: 13, color: AppColors.mu),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Text('🏋️', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            const Text(
              'Sem treinos registrados hoje',
              style: TextStyle(fontSize: 15, color: AppColors.tx, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const Text(
              'Registre seus exercícios para\nacompanhar as calorias queimadas',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.mu),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onAdd,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.org,
                side: const BorderSide(color: AppColors.org),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar treino'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Exercise tile ─────────────────────────────────────────────────────────────

class _ExercicioTile extends StatelessWidget {
  final Map<String, dynamic> exercicio;
  final VoidCallback onDelete;
  const _ExercicioTile({required this.exercicio, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final nome      = exercicio['nome'] as String? ?? '';
    final categoria = exercicio['categoria'] as String? ?? 'cardio';
    final kcal      = (exercicio['calorias_kcal'] as num?)?.toInt() ?? 0;
    final duracao   = (exercicio['duracao_min'] as num?)?.toInt() ?? 0;
    final emoji     = categoriaEmoji[categoria] ?? '🏃';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.org.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.tx)),
                Text(
                  '$duracao min · $kcal kcal',
                  style: const TextStyle(fontSize: 12, color: AppColors.mu),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.mu),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
