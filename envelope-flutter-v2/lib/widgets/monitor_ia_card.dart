import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/monitor_ia_provider.dart';
import '../services/gemini_monitor_service.dart';

class MonitorIACard extends ConsumerStatefulWidget {
  const MonitorIACard({super.key});

  @override
  ConsumerState<MonitorIACard> createState() => _MonitorIACardState();
}

class _MonitorIACardState extends ConsumerState<MonitorIACard>
    with SingleTickerProviderStateMixin {
  bool _expandido = false;
  bool _atualizando = false;
  late AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  Future<void> _atualizar() async {
    setState(() => _atualizando = true);
    await GeminiMonitorService.limparCache();
    ref.invalidate(monitorIAProvider);
    if (mounted) setState(() => _atualizando = false);
  }

  // Fração do mês já decorrida (0.0 – 1.0)
  double get _fracaoMes {
    final now = DateTime.now();
    final diasNoMes = DateTime(now.year, now.month + 1, 0).day;
    return now.day / diasNoMes;
  }

  @override
  Widget build(BuildContext context) {
    final analiseAsync = ref.watch(monitorIAProvider);
    final isLoading = analiseAsync.isLoading || _atualizando;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePad),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(
            color: analiseAsync.whenOrNull(
                  data: (a) => _corStatus(a.status).withOpacity(0.35),
                ) ??
                AppColors.bord,
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            // ── Cabeçalho ──────────────────────────────────────────────────
            InkWell(
              onTap: () => setState(() => _expandido = !_expandido),
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Ícone de status
                        analiseAsync.when(
                          loading: () => const _IconeStatus(status: 'loading'),
                          error: (_, __) => const _IconeStatus(status: 'erro'),
                          data: (a) => _IconeStatus(status: a.status),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(
                                  'Monitor IA',
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.mu,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8),
                                ),
                                const SizedBox(width: 6),
                                analiseAsync.when(
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, __) => const SizedBox.shrink(),
                                  data: (a) => _StatusChip(status: a.status),
                                ),
                              ]),
                              const SizedBox(height: 4),

                              // ── [2] Título da análise em destaque ──────
                              analiseAsync.when(
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                                data: (a) => Text(
                                  a.titulo,
                                  style: AppTextStyles.caption.copyWith(
                                    color: _corStatus(a.status),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    height: 1.2,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 2),
                              analiseAsync.when(
                                loading: () => isLoading
                                    ? _LoadingText(controller: _dotsController)
                                    : Text(
                                        'Analisando seus gastos...',
                                        style: AppTextStyles.bodySm
                                            .copyWith(color: AppColors.mu),
                                      ),
                                error: (e, _) => Text(
                                  'Toque para tentar novamente',
                                  style: AppTextStyles.bodySm
                                      .copyWith(color: AppColors.org),
                                ),
                                data: (a) => Text(
                                  a.resumo,
                                  style: AppTextStyles.bodySm,
                                  maxLines: _expandido ? null : 2,
                                  overflow: _expandido
                                      ? null
                                      : TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ── [6] Loading com spinner + texto ────────────
                        if (isLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.acc),
                          )
                        else
                          Icon(
                            _expandido
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: AppColors.mu,
                            size: 20,
                          ),
                      ],
                    ),

                    // ── [1] Barra de progresso do mês (card fechado) ──────
                    if (!_expandido) ...[
                      const SizedBox(height: 10),
                      _BarraProgressoMes(fracao: _fracaoMes),
                    ],
                  ],
                ),
              ),
            ),

            // ── Conteúdo expandido ─────────────────────────────────────────
            if (_expandido)
              analiseAsync.when(
                loading: () => _LoadingExpandido(controller: _dotsController),
                error: (e, _) => _ErroCard(
                  erro: e.toString(),
                  onRetry: _atualizar,
                ),
                data: (analise) => _ConteudoExpandido(
                  analise: analise,
                  atualizando: _atualizando,
                  onAtualizar: _atualizar,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── [1] Barra de progresso do mês ────────────────────────────────────────────

class _BarraProgressoMes extends StatelessWidget {
  final double fracao;
  const _BarraProgressoMes({required this.fracao});

  @override
  Widget build(BuildContext context) {
    final pct = (fracao * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progresso do mês',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mu,
                fontSize: 9,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              '$pct%',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mu,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: fracao,
            minHeight: 3,
            backgroundColor: AppColors.bord,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.acc.withOpacity(0.55),
            ),
          ),
        ),
      ],
    );
  }
}

// ── [6] Texto animado de loading ──────────────────────────────────────────────

class _LoadingText extends StatelessWidget {
  final AnimationController controller;
  const _LoadingText({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final dots = '.' * (((controller.value * 3).floor() % 3) + 1);
        return Text(
          'Astrix está analisando seus dados$dots',
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.mu,
            fontStyle: FontStyle.italic,
          ),
        );
      },
    );
  }
}

class _LoadingExpandido extends StatelessWidget {
  final AnimationController controller;
  const _LoadingExpandido({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 14),
      child: Column(
        children: [
          const CircularProgressIndicator(
              color: AppColors.acc, strokeWidth: 2),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: controller,
            builder: (_, __) {
              final dots = '.' * (((controller.value * 3).floor() % 3) + 1);
              return Text(
                'Astrix está analisando seus dados$dots',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.mu,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Conteúdo expandido ────────────────────────────────────────────────────────

class _ConteudoExpandido extends StatelessWidget {
  final MonitorAnalise analise;
  final bool atualizando;
  final VoidCallback onAtualizar;
  const _ConteudoExpandido({
    required this.analise,
    required this.atualizando,
    required this.onAtualizar,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final horasAtras = DateTime.now().difference(analise.geradoEm).inHours;
    final labelTempo = horasAtras == 0
        ? 'agora'
        : horasAtras == 1
            ? 'há 1 hora'
            : 'há ${horasAtras}h';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: AppColors.bord, height: 1),
          const SizedBox(height: 14),

          // Projeção do mês
          if (analise.projecaoMes != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _corStatus(analise.status).withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(
                    color: _corStatus(analise.status).withOpacity(0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analise.status == 'alerta'
                        ? '🚨'
                        : analise.status == 'atencao'
                            ? '⚠️'
                            : '✅',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROJEÇÃO DO MÊS',
                          style: AppTextStyles.caption.copyWith(
                            color: _corStatus(analise.status),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          analise.projecaoMes!,
                          style: AppTextStyles.caption
                              .copyWith(height: 1.5, color: AppColors.tx),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Padrão detectado
          if (analise.padraoDetectado != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔍', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PADRÃO DETECTADO',
                        style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        analise.padraoDetectado!,
                        style: AppTextStyles.caption.copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Insights por categoria
          if (analise.insights.isNotEmpty) ...[
            Text(
              'DETALHAMENTO',
              style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            ...analise.insights.map((ins) => _InsightItem(insight: ins, fmt: fmt)),
            const SizedBox(height: 6),
          ],

          // ── [4] Ações recomendadas com container destacado ───────────────
          if (analise.acoesRecomendadas.isNotEmpty) ...[
            Text(
              'O QUE FAZER',
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.acc,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            ...analise.acoesRecomendadas.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.acc.withOpacity(0.06),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(
                          color: AppColors.acc.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: AppColors.acc,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${e.key + 1}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.bg,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e.value,
                              style: AppTextStyles.caption
                                  .copyWith(height: 1.5, color: AppColors.tx),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 4),
          ],

          // ── [5] Rodapé: timestamp + botão outlined ───────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Análise gerada $labelTempo',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.mu, fontSize: 10),
              ),
              SizedBox(
                height: 28,
                child: OutlinedButton.icon(
                  onPressed: atualizando ? null : onAtualizar,
                  icon: atualizando
                      ? const SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppColors.mu),
                        )
                      : const Icon(Icons.refresh_rounded, size: 13),
                  label: const Text('Atualizar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.mu,
                    side: BorderSide(
                        color: AppColors.mu.withOpacity(0.35), width: 0.8),
                    textStyle: AppTextStyles.caption.copyWith(fontSize: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── [3] Insight individual com valor em destaque ──────────────────────────────

class _InsightItem extends StatelessWidget {
  final MonitorInsight insight;
  final NumberFormat fmt;
  const _InsightItem({required this.insight, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cor = insight.tipo == 'positivo'
        ? AppColors.grn
        : insight.tipo == 'negativo'
            ? AppColors.red
            : AppColors.mu;
    final icone = insight.tipo == 'positivo'
        ? '↑'
        : insight.tipo == 'negativo'
            ? '↓'
            : '→';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: cor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(icone,
                style: TextStyle(
                    color: cor, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      insight.categoria,
                      style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700, color: cor),
                    ),
                    if (insight.variacaoPercent != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${insight.variacaoPercent! >= 0 ? '+' : ''}${insight.variacaoPercent!.toStringAsFixed(0)}%',
                        style: AppTextStyles.caption
                            .copyWith(color: cor, fontSize: 10),
                      ),
                    ],
                    // ── [3] Valor de referência em destaque ──────────────
                    if (insight.valorReferencia != null) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: cor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          fmt.format(insight.valorReferencia),
                          style: AppTextStyles.caption.copyWith(
                            color: cor,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  insight.mensagem,
                  style: AppTextStyles.caption.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _IconeStatus extends StatelessWidget {
  final String status;
  const _IconeStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    final (emoji, cor) = switch (status) {
      'alerta' => ('🚨', AppColors.red),
      'atencao' => ('⚠️', AppColors.org),
      'erro' => ('⚡', AppColors.org),
      'loading' => ('🔄', AppColors.mu),
      _ => ('✅', AppColors.grn),
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, cor) = switch (status) {
      'alerta' => ('ALERTA', AppColors.red),
      'atencao' => ('ATENÇÃO', AppColors.org),
      _ => ('OK', AppColors.grn),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
            color: cor, fontWeight: FontWeight.w700, fontSize: 9),
      ),
    );
  }
}

class _ErroCard extends StatelessWidget {
  final String erro;
  final VoidCallback onRetry;
  const _ErroCard({required this.erro, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            erro.contains('Chave Gemini')
                ? '⚙️ Configure a chave Gemini em Configurações → IA para ativar o Monitor.'
                : '⚠️ $erro',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.org, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Tentar novamente'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.acc,
              side: const BorderSide(color: AppColors.acc),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper global ─────────────────────────────────────────────────────────────

Color _corStatus(String status) => switch (status) {
  'alerta' => AppColors.red,
  'atencao' => AppColors.org,
  _ => AppColors.grn,
};
