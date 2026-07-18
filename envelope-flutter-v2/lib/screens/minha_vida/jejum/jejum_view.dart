import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/jejum_provider.dart';
import '../../../services/jejum_api_service.dart';
import '../../../widgets/unicorn/unicorn_system.dart';
import 'jejum_unicorn_card.dart';
import 'jejum_config_sheet.dart';
import 'jejum_timer_screen.dart';
import 'jejum_historico_view.dart';
import 'jejum_insights_view.dart';
import 'jejum_onboarding_screen.dart';
import 'jejum_janela_sheet.dart';
import 'jejum_notificacoes_screen.dart';
import 'jejum_fases_screen.dart';
import 'jejum_together_sheet.dart';

/// View raiz do módulo Jejum — 4ª aba dentro de Saúde.
/// REGRA CRÍTICA: nenhum dado financeiro aparece aqui, nunca.
class JejumView extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;

  const JejumView({
    super.key,
    required this.membroId,
    required this.familiaId,
  });

  @override
  ConsumerState<JejumView> createState() => _JejumViewState();
}

class _JejumViewState extends ConsumerState<JejumView> {
  int _aba = 0; // 0 = Hoje, 1 = Histórico, 2 = Insights, 3 = Configurar

  JejumArgs get _args =>
      (membroId: widget.membroId, familiaId: widget.familiaId);

  bool _onboardingVerificado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_onboardingVerificado && widget.membroId.isNotEmpty) {
      _onboardingVerificado = true;
      _verificarOnboarding();
    }
  }

  void _verificarOnboarding() {
    final configAsync = ref.read(
      jejumConfigProvider((membroId: widget.membroId, familiaId: widget.familiaId)),
    );
    configAsync.whenData((config) {
      final protocolo = config['protocolo'] as String?;
      if (protocolo == null || protocolo.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => JejumOnboardingScreen(
                membroId: widget.membroId,
                familiaId: widget.familiaId,
              ),
            ),
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.membroId.isEmpty) {
      return const UnicornEmpty(
        type: UnicornType.happy,
        title: 'Carregando…',
        subtitle: 'Um instante',
      );
    }

    return Column(
      children: [
        _buildAbas(),
        Expanded(
          child: IndexedStack(
            index: _aba,
            children: [
              _buildHoje(),
              JejumHistoricoView(
                membroId: widget.membroId,
                familiaId: widget.familiaId,
              ),
              JejumInsightsView(
                membroId: widget.membroId,
                familiaId: widget.familiaId,
              ),
              _buildConfigurar(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Chips de sub-navegação ─────────────────────────────────────────────────

  Widget _buildAbas() {
    const labels = ['Hoje', 'Histórico', 'Insights', 'Configurar'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePad, 0, AppSpacing.pagePad, AppSpacing.cardGap,
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final ativo = _aba == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _aba = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: ativo
                      ? AppColors.pur.withOpacity(0.18)
                      : AppColors.surf,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                  border: Border.all(
                    color: ativo ? AppColors.pur.withOpacity(0.5) : AppColors.bord,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ativo ? AppColors.pur : AppColors.mu,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Aba Hoje ───────────────────────────────────────────────────────────────

  Widget _buildHoje() {
    final ativoAsync = ref.watch(jejumAtivoProvider(widget.membroId));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePad, 0, AppSpacing.pagePad, 100,
      ),
      child: Column(
        children: [
          JejumUnicornCard(membroId: widget.membroId),
          ativoAsync.when(
            data: (ativo) => ativo != null
                ? _buildJejumAtivoCard(ativo)
                : _buildIniciarCard(),
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: UnicornLoading(),
            ),
            error: (_, __) => _buildIniciarCard(),
          ),
        ],
      ),
    );
  }

  // ── Card: jejum em andamento (resumo → abre timer) ─────────────────────────

  Widget _buildJejumAtivoCard(Map<String, dynamic> ativo) {
    final inicio = DateTime.tryParse(ativo['iniciado_em'] ?? '')?.toLocal();
    final decorrido =
        inicio != null ? DateTime.now().difference(inicio) : Duration.zero;
    final fase = FaseMetabolica.atual(decorrido);
    final metaHoras = (ativo['meta_horas'] as num?)?.toDouble();
    final pct = metaHoras != null && metaHoras > 0
        ? (decorrido.inMinutes / (metaHoras * 60)).clamp(0.0, 1.0)
        : null;

    final h = decorrido.inHours;
    final m = decorrido.inMinutes % 60;

    return GestureDetector(
      onTap: () => _abrirTimer(ativo),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: fase.cor.withOpacity(0.4), width: 1),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(fase.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Jejum em andamento',
                        style: AppTextStyles.caption.copyWith(color: AppColors.mu)),
                    Text(fase.nome,
                        style: AppTextStyles.bodySm.copyWith(
                          color: fase.cor,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
                const Spacer(),
                Text(
                  '${h}h ${m.toString().padLeft(2, '0')}min',
                  style: AppTextStyles.mono.copyWith(color: fase.cor),
                ),
              ],
            ),
            if (pct != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: AppColors.bord,
                  valueColor: AlwaysStoppedAnimation(fase.cor),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${(pct * 100).toInt()}% da meta de ${metaHoras!.toStringAsFixed(metaHoras.truncateToDouble() == metaHoras ? 0 : 1)}h',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => _abrirTimer(ativo),
                icon: const Icon(Icons.timer_outlined, size: 18),
                label: const Text('Abrir timer',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: fase.cor.withOpacity(0.15),
                  foregroundColor: fase.cor,
                  elevation: 0,
                  side: BorderSide(color: fase.cor.withOpacity(0.6), width: 0.8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card: iniciar jejum ────────────────────────────────────────────────────

  Widget _buildIniciarCard() {
    final configAsync = ref.watch(jejumConfigProvider(_args));

    return configAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: UnicornLoading(),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Column(
          children: [
            Text('Não consegui carregar sua configuração.',
                style: AppTextStyles.bodySm),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => ref.invalidate(jejumConfigProvider(_args)),
              child: const Text('Tentar de novo',
                  style: TextStyle(color: AppColors.acc)),
            ),
          ],
        ),
      ),
      data: (config) {
        final protocolo = config['protocolo'] as String? ?? '16_8';
        final duracao = (config['duracao_horas'] as num?)?.toDouble() ?? 16.0;
        final modalidade = config['modalidade'] as String? ?? 'com_meta';
        final sequencia = config['sequencia_atual'] as int? ?? 0;
        final recorde = config['recorde_sequencia'] as int? ?? 0;
        final protocoloLabel = ProtocoloJejum.todos
            .firstWhere((p) => p.id == protocolo,
                orElse: () => ProtocoloJejum.todos.first)
            .label;

        return Column(
          children: [
            // Streak chips
            if (sequencia > 0 || recorde > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                child: Row(
                  children: [
                    Expanded(
                      child: _chipStat('🔥 Sequência', '$sequencia dias',
                          AppColors.org),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _chipStat('🏆 Recorde', '$recorde dias',
                          AppColors.gold),
                    ),
                  ],
                ),
              ),

            // Card principal de início
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                border: Border.all(color: AppColors.bord, width: 0.5),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('⏱️', style: TextStyle(fontSize: 26)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Seu protocolo',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.mu)),
                          Text(
                            modalidade == 'livre'
                                ? '$protocoloLabel · Livre'
                                : '$protocoloLabel · ${duracao.toStringAsFixed(duracao.truncateToDouble() == duracao ? 0 : 1)}h',
                            style: AppTextStyles.bodySm.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.tx,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _abrirConfig,
                        icon: const Icon(Icons.tune_rounded,
                            color: AppColors.mu, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _iniciarJejum(config),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pur,
                        foregroundColor: AppColors.bg,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusBtn),
                        ),
                      ),
                      child: const Text('Iniciar jejum',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Aba Configurar ────────────────────────────────────────────────────────

  Widget _buildConfigurar() {
    final configAsync = ref.watch(jejumConfigProvider(_args));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePad, 0, AppSpacing.pagePad, 100),
      child: configAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: UnicornLoading(),
        ),
        error: (_, __) => const SizedBox.shrink(),
        data: (config) {
          final protocolo = config['protocolo'] as String? ?? '16_8';
          final duracaoH = (config['duracao_horas'] as num?)?.toDouble() ?? 16.0;
          final horaInicio = config['hora_inicio_janela'] as String? ?? '12:00';
          final horaFim    = config['hora_fim_janela']    as String? ?? '20:00';
          final jokers     = (config['joker_days_mes']   as int? ?? 2) -
              (config['jokers_usados'] as int? ?? 0);
          final protLabel = ProtocoloJejum.todos
              .firstWhere((p) => p.id == protocolo,
                  orElse: () => ProtocoloJejum.todos.first)
              .label;

          return Column(
            children: [
              // Protocolo atual
              _buildConfigCard(
                emoji: '⏱️',
                titulo: 'Protocolo',
                subtitulo: '$protLabel · ${duracaoH.toStringAsFixed(duracaoH.truncateToDouble() == duracaoH ? 0 : 1)}h',
                onTap: _abrirConfig,
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // Horário da janela
              _buildConfigCard(
                emoji: '🍽️',
                titulo: 'Horário da janela',
                subtitulo: '${horaInicio.replaceAll(':', 'h')} – ${horaFim.replaceAll(':', 'h')}',
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => JejumJanelaSheet(
                    membroId: widget.membroId,
                    familiaId: widget.familiaId,
                    protocolo: protocolo,
                  ),
                ).then((_) => ref.invalidate(jejumConfigProvider(_args))),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // Notificações
              _buildConfigCard(
                emoji: '🔔',
                titulo: 'Notificações',
                subtitulo: 'Configurar lembretes',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JejumNotificacoesScreen(
                      membroId: widget.membroId,
                      familiaId: widget.familiaId,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // Fases metabólicas
              _buildConfigCard(
                emoji: '🧬',
                titulo: 'Fases metabólicas',
                subtitulo: 'O que acontece no seu corpo',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const JejumFasesScreen(),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // Fast Together
              _buildConfigCard(
                emoji: '👭',
                titulo: 'Fast Together',
                subtitulo: 'Jejuar em dupla',
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => JejumTogetherSheet(
                    membroId: widget.membroId,
                    familiaId: widget.familiaId,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // Joker Day
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  border: Border.all(color: AppColors.bord, width: 0.5),
                ),
                child: Row(
                  children: [
                    const Text('🃏', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Joker Day',
                            style: AppTextStyles.bodySm.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.tx,
                            ),
                          ),
                          Text(
                            '$jokers disponível${jokers == 1 ? '' : 'is'} este mês',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusChip),
                        border: Border.all(
                            color: AppColors.gold.withOpacity(0.4), width: 0.8),
                      ),
                      child: Text(
                        '$jokers',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConfigCard({
    required String emoji,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: AppTextStyles.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.tx,
                    ),
                  ),
                  Text(subtitulo, style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.mu, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _chipStat(String label, String valor, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
        border: Border.all(color: cor.withOpacity(0.25), width: 0.8),
      ),
      child: Column(
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(valor,
              style: AppTextStyles.bodySm
                  .copyWith(color: cor, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── Ações ──────────────────────────────────────────────────────────────────

  void _abrirConfig() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JejumConfigSheet(
        membroId: widget.membroId,
        familiaId: widget.familiaId,
      ),
    ).then((_) => ref.invalidate(jejumConfigProvider(_args)));
  }

  Future<void> _iniciarJejum(Map<String, dynamic> config) async {
    HapticFeedback.mediumImpact();
    final modalidade = config['modalidade'] as String? ?? 'com_meta';
    final duracao = (config['duracao_horas'] as num?)?.toDouble() ?? 16.0;

    try {
      final registro = await JejumApiService.iniciar(
        usuarioId: widget.membroId,
        familiaId: widget.familiaId,
        metaHoras: modalidade == 'livre' ? null : duracao,
      );
      if (!mounted) return;
      _abrirTimer(registro);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível iniciar: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  void _abrirTimer(Map<String, dynamic> registro) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JejumTimerScreen(
          membroId: widget.membroId,
          familiaId: widget.familiaId,
          registroInicial: registro,
        ),
      ),
    );
  }
}
