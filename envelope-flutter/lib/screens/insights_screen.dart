import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/insights_provider.dart';
import '../providers/astrix_provider.dart';
import '../widgets/mascote/astrix_painter.dart' show AstrixMood;
import '../widgets/mascote/unicorn_screen_guard.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(astrixInsightsProvider);

    return Stack(children: [
    Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surf,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.mu, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Text('🦄', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Astrix Insights', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.tx)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.mu, size: 20),
            onPressed: () => ref.invalidate(astrixInsightsProvider),
          ),
        ],
      ),
      body: insightsAsync.when(
        loading: () => _Loading(),
        error: (e, _) => _Error(error: '$e', onRetry: () => ref.invalidate(astrixInsightsProvider)),
        data: (data) => data.isEmpty ? _Empty() : _InsightsContent(data: data),
      ),
    ),
    UnicornScreenGuard(
      screenId: 'insights',
      onFirstMount: (r) => r.astrix(
        'Deixa eu compartilhar insights especiais sobre seu dinheiro...',
        mood: AstrixMood.thinking,
      ),
    ),
    ]);
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _Loading extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('🦄', style: TextStyle(fontSize: 52)),
          SizedBox(height: 20),
          CircularProgressIndicator(color: AppColors.pur),
          SizedBox(height: 16),
          Text('Astrix está analisando sua semana...', style: TextStyle(color: AppColors.mu, fontSize: 14)),
          SizedBox(height: 4),
          Text('Pode demorar alguns segundos', style: TextStyle(color: AppColors.mu, fontSize: 12)),
        ],
      ),
    ),
  );
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _Error extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _Error({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.mu, size: 40),
          const SizedBox(height: 12),
          const Text('Não consegui gerar os insights', style: TextStyle(color: AppColors.tx, fontSize: 15)),
          const SizedBox(height: 4),
          Text(error, style: const TextStyle(color: AppColors.mu, fontSize: 11), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.pur, side: const BorderSide(color: AppColors.pur)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}

// ── Empty ─────────────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🦄', style: TextStyle(fontSize: 52)),
          SizedBox(height: 12),
          Text('Faça login para ver seus insights', style: TextStyle(color: AppColors.mu)),
        ],
      ),
    ),
  );
}

// ── Content ───────────────────────────────────────────────────────────────────

class _InsightsContent extends StatelessWidget {
  final Map<String, dynamic> data;
  const _InsightsContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final saudacao     = data['saudacao'] as String? ?? 'Olá! 🦄';
    final scoreGeral   = (data['score_geral'] as num?)?.toInt() ?? 70;
    final dicaSemana   = data['dica_semana'] as String? ?? '';
    final destaques    = (data['destaques'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final alertas      = (data['alertas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final finScore     = (data['financeiro_score'] as num?)?.toInt() ?? 70;
    final nutScore     = (data['nutricao_score'] as num?)?.toInt() ?? 70;
    final exScore      = (data['exercicio_score'] as num?)?.toInt() ?? 70;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Astrix saudação
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.pur.withOpacity(0.2), AppColors.blu.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.pur.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🦄', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(saudacao, style: const TextStyle(fontSize: 14, color: AppColors.tx, height: 1.4)),
                    const SizedBox(height: 8),
                    _ScoreGauge(score: scoreGeral),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Scores por módulo
        Row(
          children: [
            Expanded(child: _ScoreChip('💰', 'Finanças', finScore, AppColors.acc)),
            const SizedBox(width: 8),
            Expanded(child: _ScoreChip('🥗', 'Nutrição', nutScore, AppColors.grn)),
            const SizedBox(width: 8),
            Expanded(child: _ScoreChip('🏋️', 'Exercício', exScore, AppColors.org)),
          ],
        ),

        // Destaques
        if (destaques.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('DESTAQUES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mu, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ...destaques.map((d) => _InsightTile(
            emoji: d['emoji'] as String? ?? '✨',
            titulo: d['titulo'] as String? ?? '',
            texto: d['texto'] as String? ?? '',
            color: AppColors.grn,
          )),
        ],

        // Alertas
        if (alertas.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('ATENÇÃO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mu, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ...alertas.map((a) => _InsightTile(
            emoji: a['emoji'] as String? ?? '⚠️',
            titulo: a['titulo'] as String? ?? '',
            texto: a['texto'] as String? ?? '',
            color: AppColors.org,
          )),
        ],

        // Dica da semana
        if (dicaSemana.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.pur.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.pur.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DICA DA SEMANA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.pur, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(dicaSemana, style: const TextStyle(fontSize: 13, color: AppColors.tx, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
        const Center(
          child: Text('Análise com base nos últimos 7 dias', style: TextStyle(fontSize: 11, color: AppColors.mu)),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _ScoreGauge extends StatelessWidget {
  final int score;
  const _ScoreGauge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 75 ? AppColors.grn : score >= 50 ? AppColors.org : AppColors.red;
    return Row(
      children: [
        Text(
          '$score',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
        ),
        const Text('/100', style: TextStyle(fontSize: 14, color: AppColors.mu)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: AppColors.surf,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String emoji;
  final String label;
  final int score;
  final Color color;
  const _ScoreChip(this.emoji, this.label, this.score, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3), width: 0.5),
    ),
    child: Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text('$score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.mu)),
      ],
    ),
  );
}

class _InsightTile extends StatelessWidget {
  final String emoji;
  final String titulo;
  final String texto;
  final Color color;
  const _InsightTile({required this.emoji, required this.titulo, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2), width: 0.5),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
              if (texto.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(texto, style: const TextStyle(fontSize: 12, color: AppColors.mu, height: 1.4)),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
