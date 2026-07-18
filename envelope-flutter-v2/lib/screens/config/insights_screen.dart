import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/insights_provider.dart';
import '../../widgets/unicorn/unicorn_system.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(astrixInsightsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.mu, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          const Text('🔮', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text('Insights IA', style: AppTextStyles.titleSm),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.mu, size: 20),
            tooltip: 'Atualizar análise',
            onPressed: () => ref.invalidate(astrixInsightsProvider),
          ),
        ],
      ),
      body: insightsAsync.when(
        loading: () => const _Loading(),
        error: (e, _) => _Error(
          error: '$e',
          onRetry: () => ref.invalidate(astrixInsightsProvider),
        ),
        data: (data) => data.isEmpty
            ? const _Empty()
            : _Content(data: data, ref: ref),
      ),
    );
  }
}

// ── Loading ────────────────────────────────────────────────────────────────────

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 80, width: 80, child: UnicornLoading()),
              const SizedBox(height: 24),
              Text(
                'Astrix está analisando...',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Analisando suas finanças da semana.\nPode demorar alguns segundos.',
                style: TextStyle(
                    color: AppColors.mu, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

// ── Error ──────────────────────────────────────────────────────────────────────

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
              Text(
                'Não foi possível gerar os insights',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                error,
                style: const TextStyle(
                    color: AppColors.mu, fontSize: 11, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.acc,
                  side: const BorderSide(color: AppColors.acc),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusBtn)),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
}

// ── Empty ──────────────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🦄', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text('Nenhum insight disponível', style: AppTextStyles.body),
              const SizedBox(height: 4),
              const Text(
                'Faça mais registros financeiros e o Astrix\ngerará sua análise em breve.',
                style: TextStyle(
                    color: AppColors.mu, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

// ── Content ────────────────────────────────────────────────────────────────────

class _Content extends StatelessWidget {
  final Map<String, dynamic> data;
  final WidgetRef ref;
  const _Content({required this.data, required this.ref});

  @override
  Widget build(BuildContext context) {
    final saudacao   = data['saudacao'] as String? ?? 'Olá! 🦄';
    final scoreGeral = (data['score_geral'] as num?)?.toInt() ?? 70;
    final dicaSemana = data['dica_semana'] as String? ?? '';
    final destaques  = (data['destaques'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final alertas = (data['alertas'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final finScore = (data['financeiro_score'] as num?)?.toInt() ?? 70;
    final nutScore = (data['nutricao_score'] as num?)?.toInt() ?? 70;
    final exScore  = (data['exercicio_score'] as num?)?.toInt() ?? 70;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePad),
      children: [
        // ── Hero card com gradiente dourado ────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.gold.withOpacity(0.15),
                AppColors.acc.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(
                color: AppColors.gold.withOpacity(0.35), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🦄', style: TextStyle(fontSize: 36)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      saudacao,
                      style: AppTextStyles.bodySm
                          .copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    _ScoreGauge(score: scoreGeral),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.cardGap),

        // ── Scores por módulo ──────────────────────────────────────────────
        Row(children: [
          Expanded(
              child: _ScoreChip(
                  emoji: '💰',
                  label: 'Finanças',
                  score: finScore,
                  color: AppColors.acc)),
          const SizedBox(width: 8),
          Expanded(
              child: _ScoreChip(
                  emoji: '🥗',
                  label: 'Nutrição',
                  score: nutScore,
                  color: AppColors.grn)),
          const SizedBox(width: 8),
          Expanded(
              child: _ScoreChip(
                  emoji: '🏋️',
                  label: 'Exercício',
                  score: exScore,
                  color: AppColors.org)),
        ]),

        // ── Destaques ──────────────────────────────────────────────────────
        if (destaques.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sectionGap),
          _SubHeader(label: 'DESTAQUES'),
          const SizedBox(height: 8),
          ...destaques.map((d) => _InsightCard(
                emoji: d['emoji'] as String? ?? '✨',
                titulo: d['titulo'] as String? ?? '',
                texto: d['texto'] as String? ?? '',
                color: AppColors.grn,
              )),
        ],

        // ── Alertas ────────────────────────────────────────────────────────
        if (alertas.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sectionGap),
          _SubHeader(label: 'ATENÇÃO'),
          const SizedBox(height: 8),
          ...alertas.map((a) => _InsightCard(
                emoji: a['emoji'] as String? ?? '⚠️',
                titulo: a['titulo'] as String? ?? '',
                texto: a['texto'] as String? ?? '',
                color: AppColors.org,
              )),
        ],

        // ── Dica da semana ─────────────────────────────────────────────────
        if (dicaSemana.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sectionGap),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pur.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(
                  color: AppColors.pur.withOpacity(0.25), width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DICA DA SEMANA',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.pur,
                            letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dicaSemana,
                        style: AppTextStyles.bodySm
                            .copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.sectionGap),

        // ── Botão atualizar ────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.acc,
              side: const BorderSide(color: AppColors.acc, width: 0.8),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusBtn)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Atualizar análise',
                style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => ref.invalidate(astrixInsightsProvider),
          ),
        ),

        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Análise com base nos últimos 7 dias',
            style: TextStyle(fontSize: 11, color: AppColors.mu),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _SubHeader extends StatelessWidget {
  final String label;
  const _SubHeader({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.mu,
          letterSpacing: 1.2,
        ),
      );
}

class _ScoreGauge extends StatelessWidget {
  final int score;
  const _ScoreGauge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 75
        ? AppColors.grn
        : score >= 50
            ? AppColors.org
            : AppColors.red;
    return Row(children: [
      Text(
        '$score',
        style: TextStyle(
            fontSize: 30, fontWeight: FontWeight.bold, color: color),
      ),
      const Text('/100',
          style: TextStyle(fontSize: 14, color: AppColors.mu)),
      const SizedBox(width: 10),
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
    ]);
  }
}

class _ScoreChip extends StatelessWidget {
  final String emoji;
  final String label;
  final int score;
  final Color color;
  const _ScoreChip({
    required this.emoji,
    required this.label,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(
              color: color.withOpacity(0.3), width: 0.5),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text('$score',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label, style: AppTextStyles.caption),
        ]),
      );
}

class _InsightCard extends StatelessWidget {
  final String emoji;
  final String titulo;
  final String texto;
  final Color color;
  const _InsightCard({
    required this.emoji,
    required this.titulo,
    required this.texto,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(
              color: color.withOpacity(0.2), width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                  if (texto.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      texto,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mu,
                          height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}
