import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/jejum_provider.dart';
import '../../../services/jejum_api_service.dart';
import '../../../services/jejum_notification_service.dart';
import '../../../widgets/unicorn/unicorn_system.dart';
import 'jejum_celebracao_sheet.dart';

/// Timer fullscreen do jejum ativo: anel de progresso, fases metabólicas,
/// humor e finalização com linguagem sempre positiva.
class JejumTimerScreen extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;
  final Map<String, dynamic> registroInicial;

  const JejumTimerScreen({
    super.key,
    required this.membroId,
    required this.familiaId,
    required this.registroInicial,
  });

  @override
  ConsumerState<JejumTimerScreen> createState() => _JejumTimerScreenState();
}

class _JejumTimerScreenState extends ConsumerState<JejumTimerScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Atualiza o contador a cada segundo enquanto a tela está aberta
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    JejumNotificationService.iniciar(widget.registroInicial);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ativoAsync = ref.watch(jejumAtivoProvider(widget.membroId));
    final registro = ativoAsync.asData?.value ?? widget.registroInicial;
    final configAsync = ref.watch(jejumConfigProvider(
        (membroId: widget.membroId, familiaId: widget.familiaId)));
    final sequencia =
        configAsync.asData?.value['sequencia_atual'] as int? ?? 0;

    final inicio = DateTime.tryParse(registro['iniciado_em'] ?? '')?.toLocal();
    final decorrido =
        inicio != null ? DateTime.now().difference(inicio) : Duration.zero;
    final metaHoras = (registro['meta_horas'] as num?)?.toDouble();
    final fase = FaseMetabolica.atual(decorrido);
    final proxima = FaseMetabolica.proxima(decorrido);
    final pct = metaHoras != null && metaHoras > 0
        ? (decorrido.inMinutes / (metaHoras * 60)).clamp(0.0, 1.0)
        : null;
    final metaAtingida = pct != null && pct >= 1.0;
    final status = registro['status'] as String? ?? '';
    final janelaAberta = metaAtingida || status == 'completo';

    // Calcular hora fim da janela
    final horaInicioJanela = registro['hora_inicio_janela'] as String?;
    final horaFimJanela    = registro['hora_fim_janela']    as String?;
    final duracaoJanelaH   = _calcDuracaoJanela(horaInicioJanela, horaFimJanela);

    if (janelaAberta) {
      return _buildJanelaAberta(
        context,
        registro: registro,
        decorrido: decorrido,
        horaFimJanela: horaFimJanela,
        duracaoJanelaH: duracaoJanelaH,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePad, 12, AppSpacing.pagePad, 0,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.mu),
                  ),
                  if (sequencia > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusChip),
                      ),
                      child: Text(
                        'Dia $sequencia 🔥',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: fase.cor.withOpacity(0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusChip),
                    ),
                    child: Text(
                      '${fase.emoji} ${fase.nome}',
                      style: AppTextStyles.caption.copyWith(
                        color: fase.cor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Anel ──────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: CustomPaint(
                        painter: _AnelJejumPainter(
                          progresso: pct,
                          cor: fase.cor,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatarDuracao(decorrido),
                                style: AppTextStyles.display.copyWith(
                                  fontSize: 40,
                                  color: AppColors.tx,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                metaHoras != null
                                    ? (metaAtingida
                                        ? 'Meta atingida! ✨'
                                        : 'meta: ${_fmtHoras(metaHoras)}')
                                    : 'jejum livre',
                                style: AppTextStyles.caption.copyWith(
                                  color: metaAtingida
                                      ? AppColors.acc
                                      : AppColors.mu,
                                  fontWeight: metaAtingida
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Card começa / termina
                    if (inicio != null)
                      _buildComecaTermina(
                          registro, inicio, metaHoras),
                    const SizedBox(height: 12),

                    // Próxima fase
                    if (proxima != null)
                      Text(
                        'próxima fase: ${proxima.emoji} ${proxima.nome} '
                        'em ${_tempoAteFase(decorrido, proxima)}',
                        style: AppTextStyles.caption,
                      ),
                  ],
                ),
              ),
            ),

            // ── Linha do tempo das fases ──────────────────────────────
            _buildFasesTimeline(decorrido),

            // ── Hidratação contextual (a cada 2h de jejum) ────────────
            _buildHidratacaoContextual(decorrido),

            // ── Ações ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePad, 16, AppSpacing.pagePad, 24,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _finalizar(registro, metaAtingida),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        metaAtingida ? AppColors.acc : AppColors.surf,
                    foregroundColor:
                        metaAtingida ? AppColors.bg : AppColors.tx,
                    elevation: 0,
                    side: metaAtingida
                        ? BorderSide.none
                        : const BorderSide(color: AppColors.bord),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusBtn),
                    ),
                  ),
                  child: Text(
                    metaAtingida ? 'Concluir jejum 🎉' : 'Encerrar jejum',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
          ),
          // ── Bubble do unicórnio (Happy — Astrix banido no jejum) ──
          Positioned(
            right: 12,
            bottom: 96,
            child: UnicornBubble(
              type: UnicornType.happy,
              message: _mensagemBubble(fase),
            ),
          ),
        ],
      ),
    );
  }

  String _mensagemBubble(FaseMetabolica fase) {
    switch (fase.emoji) {
      case '🔥':
        return 'Você está queimando gordura agora. Continue firme! 💪';
      case '✨':
      case '🌙':
        return 'Autofagia ativa — seu corpo está se renovando. Que orgulho! 🦄';
      case '⚡':
        return 'Cetose leve chegando. Sua mente vai clarear ✨';
      default:
        return 'Tô aqui com você nesse jejum. Cuida da hidratação 💧';
    }
  }

  // ── Estado: Janela alimentar aberta ──────────────────────────────────────────

  Widget _buildJanelaAberta(
    BuildContext context, {
    required Map<String, dynamic> registro,
    required Duration decorrido,
    String? horaFimJanela,
    double? duracaoJanelaH,
  }) {
    // protocolo disponível para uso futuro se necessário
    final horasExtra = decorrido.inMinutes / 60.0 -
        ((registro['meta_horas'] as num?)?.toDouble() ?? decorrido.inHours.toDouble());
    final horasExtraStr = horasExtra > 0
        ? '${horasExtra.toInt()}h${((horasExtra * 60) % 60).toInt().toString().padLeft(2, '0')}min'
        : '0min';

    // Progresso da janela
    double janelaProgresso = 0;
    String janelaRestanteStr = '';
    if (horaFimJanela != null && duracaoJanelaH != null && duracaoJanelaH > 0) {
      final fimParts = horaFimJanela.split(':');
      final fimH = int.tryParse(fimParts[0]) ?? 20;
      final fimM = fimParts.length > 1 ? (int.tryParse(fimParts[1]) ?? 0) : 0;
      final agora = DateTime.now();
      final fimDt = DateTime(agora.year, agora.month, agora.day, fimH, fimM);
      final diff = fimDt.difference(agora);
      if (diff.inSeconds > 0) {
        janelaProgresso =
            1.0 - (diff.inMinutes / (duracaoJanelaH * 60)).clamp(0.0, 1.0);
        final hR = diff.inHours;
        final mR = diff.inMinutes % 60;
        janelaRestanteStr = hR > 0 ? '${hR}h${mR}min restante' : '${mR}min restante';
      } else {
        janelaProgresso = 1.0;
        janelaRestanteStr = 'janela encerrada';
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePad, 12, AppSpacing.pagePad, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.mu),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Spacer(),
                  _chipCompleto(),
                ],
              ),
              const SizedBox(height: 24),

              // Anel verde 100%
              Center(
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: CustomPaint(
                    painter: _AnelJejumPainter(
                      progresso: 1.0,
                      cor: AppColors.grn,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎉', style: TextStyle(fontSize: 32)),
                          const SizedBox(height: 4),
                          Text(
                            _formatarDuracao(decorrido),
                            style: AppTextStyles.display.copyWith(
                              fontSize: 34,
                              color: AppColors.grn,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Jejum completo!',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.grn,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _chipMetaSuperada(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Card celebração unicórnio
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.grn.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  border: Border.all(
                      color: AppColors.grn.withOpacity(0.3), width: 0.8),
                ),
                child: Row(
                  children: [
                    const Text('🦄', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Você foi além! $horasExtraStr ✨',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.grn,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Seu corpo e sua mente estão mais fortes. Orgulho enorme!',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Card janela aberta
              if (horaFimJanela != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    border: Border.all(color: AppColors.bord, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '🍽️ Janela aberta',
                            style: AppTextStyles.bodySm.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.tx),
                          ),
                          Text(
                            'Até ${horaFimJanela.replaceAll(':', 'h')}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: janelaProgresso,
                          minHeight: 8,
                          backgroundColor: AppColors.bord,
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.acc),
                        ),
                      ),
                      if (janelaRestanteStr.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            janelaRestanteStr,
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.acc,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // Card proteína
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.org.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  border: Border.all(
                      color: AppColors.org.withOpacity(0.3), width: 0.8),
                ),
                child: Row(
                  children: [
                    const Text('💪', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Priorize proteína agora',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.org,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Sua primeira refeição deve ser rica em proteína para preservar músculos.',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botão registrar refeição
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    // Navega para registro de refeição
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.acc,
                    foregroundColor: AppColors.bg,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusBtn),
                    ),
                  ),
                  child: const Text(
                    '🍽️ Registrar primeira refeição',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Botão iniciar próximo jejum
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => _iniciarProximoJejum(registro),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.tx,
                    side: const BorderSide(color: AppColors.bord),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusBtn),
                    ),
                  ),
                  child: Text(
                    horaFimJanela != null
                        ? 'Iniciar próximo jejum às ${horaFimJanela.replaceAll(':', 'h')}'
                        : 'Iniciar próximo jejum',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipCompleto() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.grn.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
      ),
      child: Text(
        'Completo ✓',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.grn,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _chipMetaSuperada() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.grn.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        border: Border.all(color: AppColors.grn.withOpacity(0.4), width: 0.8),
      ),
      child: Text(
        '✓ Meta superada',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.grn,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  double? _calcDuracaoJanela(String? inicio, String? fim) {
    if (inicio == null || fim == null) return null;
    final iParts = inicio.split(':');
    final fParts = fim.split(':');
    if (iParts.isEmpty || fParts.isEmpty) return null;
    final iMin = (int.tryParse(iParts[0]) ?? 0) * 60 +
        (iParts.length > 1 ? (int.tryParse(iParts[1]) ?? 0) : 0);
    final fMin = (int.tryParse(fParts[0]) ?? 0) * 60 +
        (fParts.length > 1 ? (int.tryParse(fParts[1]) ?? 0) : 0);
    final diff = fMin >= iMin ? fMin - iMin : (1440 - iMin) + fMin;
    return diff / 60.0;
  }

  Future<void> _iniciarProximoJejum(Map<String, dynamic> registro) async {
    HapticFeedback.mediumImpact();
    try {
      final metaHoras = (registro['meta_horas'] as num?)?.toDouble();
      final novo = await JejumApiService.iniciar(
        usuarioId: widget.membroId,
        familiaId: widget.familiaId,
        metaHoras: metaHoras,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => JejumTimerScreen(
            membroId: widget.membroId,
            familiaId: widget.familiaId,
            registroInicial: novo,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao iniciar: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  // ── Timeline horizontal das fases ────────────────────────────────────────

  Widget _buildFasesTimeline(Duration decorrido) {
    final horasDecorridas = decorrido.inMinutes / 60.0;
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.pagePad),
        itemCount: FaseMetabolica.fases.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = FaseMetabolica.fases[i];
          final alcancada = horasDecorridas >= f.inicioHoras;
          return Container(
            width: 92,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: alcancada
                  ? f.cor.withOpacity(0.12)
                  : AppColors.surf,
              borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
              border: Border.all(
                color: alcancada ? f.cor.withOpacity(0.5) : AppColors.bord,
                width: 0.8,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${f.emoji} ${f.inicioHoras.toInt()}h+',
                    style: AppTextStyles.caption.copyWith(
                      color: alcancada ? f.cor : AppColors.mu,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 2),
                Text(
                  f.nome,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 9,
                    color: alcancada ? AppColors.tx : AppColors.mu,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Finalização (linguagem sempre positiva) ───────────────────────────────

  Future<void> _finalizar(
      Map<String, dynamic> registro, bool metaAtingida) async {
    HapticFeedback.mediumImpact();

    if (metaAtingida || registro['meta_horas'] == null) {
      // Meta batida (ou jejum livre): abre a celebração + micro-reflexão
      final inicio =
          DateTime.tryParse(registro['iniciado_em'] ?? '')?.toLocal();
      final duracao = inicio != null
          ? DateTime.now().difference(inicio)
          : Duration.zero;
      if (!mounted) return;
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => JejumCelebracaoSheet(
          membroId: widget.membroId,
          familiaId: widget.familiaId,
          registroId: registro['id'] as String,
          duracao: duracao,
        ),
      );
      if (ok == true && mounted) {
        ref.invalidate(jejumAtivoProvider(widget.membroId));
        // Celebração final com Sweet + partículas
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => UnicornCelebration(
            title: 'Jejum concluído! 🎉',
            subtitle: 'Seu corpo e sua mente agradecem. Que orgulho!',
            onContinue: () => Navigator.pop(ctx),
          ),
        );
        if (mounted) Navigator.pop(context);
      }
      return;
    }

    // Meta ainda não atingida: oferece opções sem punição
    final config = await JejumApiService.getConfig(
        widget.membroId, widget.familiaId);
    final jokersDisponiveis = (config['joker_days_mes'] as int? ?? 2) -
        (config['jokers_usados'] as int? ?? 0);

    if (!mounted) return;
    final escolha = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.bord,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Como você quer encerrar?',
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(fontSize: 17)),
            const SizedBox(height: 6),
            Text(
              'Tudo bem parar agora — cada hora já foi uma vitória. 💜',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 20),
            if (jokersDisponiveis > 0) ...[
              _opcaoEncerrar(
                ctx, 'joker', '🌿', 'Dia de descanso planejado',
                'Usa 1 joker ($jokersDisponiveis restantes) — sua sequência continua',
                AppColors.acc,
              ),
              const SizedBox(height: 10),
            ],
            _opcaoEncerrar(
              ctx, 'interrompido', '🕊️', 'Encerrar por hoje',
              'Sem problema nenhum. Amanhã tem mais!',
              AppColors.blu,
            ),
            const SizedBox(height: 10),
            _opcaoEncerrar(
              ctx, null, '⏱️', 'Continuar o jejum',
              'Voltar para o timer',
              AppColors.mu,
            ),
          ],
        ),
      ),
    );

    if (escolha == null || !mounted) return;

    // Interrupção: coleta o motivo (opcional, sem julgamento) antes de concluir
    String? motivo;
    if (escolha == 'interrompido') {
      motivo = await _dialogMotivoInterrupcao(registro);
    }
    await _concluir(registro, escolha, motivoInterrupcao: motivo);
  }

  // Micro-reflexão inline "O que aconteceu?" — nunca punitiva.
  Future<String?> _dialogMotivoInterrupcao(
      Map<String, dynamic> registro) async {
    final inicio =
        DateTime.tryParse(registro['iniciado_em'] ?? '')?.toLocal();
    final dec = inicio != null
        ? DateTime.now().difference(inicio)
        : Duration.zero;
    String? selecionado;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          const motivos = [
            ('fome', 'Fome intensa'),
            ('social', 'Situação social'),
            ('estresse', 'Estresse'),
            ('quis', 'Quis mesmo 🙂'),
          ];
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: AppColors.bord,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Center(
                    child: Text('💛', style: TextStyle(fontSize: 28))),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '${dec.inHours}h já fazem diferença',
                    style: AppTextStyles.title.copyWith(
                      fontSize: 18, color: AppColors.gold),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Seu corpo ficou sem insulina por ${dec.inHours} horas. '
                    'Isso é progresso real. Sem pressão.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(height: 1.4),
                  ),
                ),
                const SizedBox(height: 18),
                Text('O que aconteceu? (opcional)',
                    style: AppTextStyles.bodySm
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...motivos.map((m) {
                  final sel = selecionado == m.$1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setSheet(() => selecionado = sel ? null : m.$1);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.gold.withOpacity(0.1)
                              : AppColors.surf,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusBtn),
                          border: Border.all(
                            color: sel ? AppColors.gold : AppColors.bord,
                            width: sel ? 1.2 : 0.8,
                          ),
                        ),
                        child: Center(
                          child: Text(m.$2,
                              style: AppTextStyles.bodySm.copyWith(
                                color: sel ? AppColors.gold : AppColors.tx,
                                fontWeight: sel
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              )),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, selecionado),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bg,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusBtn),
                      ),
                    ),
                    child: const Text('Continuar',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _opcaoEncerrar(BuildContext ctx, String? valor, String emoji,
      String titulo, String subtitulo, Color cor) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, valor),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
          border: Border.all(color: cor.withOpacity(0.3), width: 0.8),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: AppTextStyles.bodySm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cor,
                      )),
                  Text(subtitulo, style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _concluir(Map<String, dynamic> registro, String status,
      {String? motivoInterrupcao}) async {
    // Humor + reflexão opcionais no encerramento
    final resultado = await _dialogHumorReflexao(status);
    if (resultado == null) return; // usuário cancelou

    try {
      await JejumApiService.finalizar(
        registro['id'] as String,
        status: status,
        humorFim: resultado.humor,
        reflexao: resultado.reflexao,
        motivoInterrupcao: motivoInterrupcao,
      );
      await JejumNotificationService.encerrar();

      if (!mounted) return;
      ref.invalidate(jejumAtivoProvider(widget.membroId));

      if (status == 'completo') {
        // Celebração com Sweet + partículas
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => UnicornCelebration(
            title: 'Jejum concluído! 🎉',
            subtitle: 'Seu corpo e sua mente agradecem. Que orgulho!',
            onContinue: () => Navigator.pop(ctx),
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao finalizar: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  Future<({int? humor, String? reflexao})?> _dialogHumorReflexao(
      String status) async {
    int? humor;
    final reflexaoCtrl = TextEditingController();
    const emojis = ['😞', '😕', '😐', '🙂', '😄'];

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          ),
          title: Text(
            status == 'completo' ? 'Como você está? ✨' : 'Como você está? 💜',
            style: const TextStyle(color: AppColors.tx, fontSize: 17),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (i) {
                  final selecionado = humor == i + 1;
                  return GestureDetector(
                    onTap: () => setSt(() => humor = i + 1),
                    child: AnimatedScale(
                      scale: selecionado ? 1.3 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Opacity(
                        opacity: humor == null || selecionado ? 1 : 0.35,
                        child: Text(emojis[i],
                            style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reflexaoCtrl,
                maxLines: 3,
                style: AppTextStyles.bodySm,
                decoration: InputDecoration(
                  hintText: 'Quer registrar uma reflexão? (opcional)',
                  hintStyle: AppTextStyles.caption,
                  filled: true,
                  fillColor: AppColors.surf,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Voltar', style: AppTextStyles.caption),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar',
                  style: TextStyle(
                      color: AppColors.acc, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true) return null;
    return (
      humor: humor,
      reflexao: reflexaoCtrl.text.trim().isEmpty ? null : reflexaoCtrl.text.trim(),
    );
  }

  // ── Formatação ────────────────────────────────────────────────────────────

  String _formatarDuracao(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _fmtHoras(double h) =>
      h.truncateToDouble() == h ? '${h.toInt()}h' : '${h}h';

  // "Hoje, 20:50" / "Amanhã, 12:50" / "Ontem, 20:50" relativo ao dia de hoje.
  String _fmtDataHora(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final hoje = DateTime.now();
    final diaDt = DateTime(dt.year, dt.month, dt.day);
    final diaHoje = DateTime(hoje.year, hoje.month, hoje.day);
    final difDias = diaDt.difference(diaHoje).inDays;
    final label = switch (difDias) {
      0 => 'Hoje',
      1 => 'Amanhã',
      -1 => 'Ontem',
      _ => '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}',
    };
    return '$label, $hh:$mm';
  }

  // Card "O jejum começa / O jejum termina" (abaixo do anel).
  Widget _buildComecaTermina(
      Map<String, dynamic> registro, DateTime inicio, double? metaHoras) {
    final termina = metaHoras != null
        ? inicio.add(Duration(minutes: (metaHoras * 60).round()))
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePad),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Começa (editável)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('O jejum começa', style: AppTextStyles.caption),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _editarInicio(registro, inicio),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            _fmtDataHora(inicio),
                            style: AppTextStyles.bodySm.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.tx,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_rounded,
                            size: 13, color: AppColors.acc),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1, height: 34,
              color: AppColors.bord,
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
            // Termina
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('O jejum termina', style: AppTextStyles.caption),
                  const SizedBox(height: 4),
                  Text(
                    termina != null ? _fmtDataHora(termina) : 'em aberto',
                    style: AppTextStyles.bodySm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: termina != null ? AppColors.acc : AppColors.mu,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Abre time picker para corrigir o início; valida e salva no backend.
  Future<void> _editarInicio(
      Map<String, dynamic> registro, DateTime inicioAtual) async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(inicioAtual),
      helpText: 'Quando o jejum começou?',
    );
    if (picked == null || !mounted) return;

    // Monta a data: hoje com a hora escolhida; se ficou no futuro, é de ontem.
    final agora = DateTime.now();
    var novo = DateTime(
        agora.year, agora.month, agora.day, picked.hour, picked.minute);
    if (novo.isAfter(agora)) {
      novo = novo.subtract(const Duration(days: 1));
    }

    try {
      await JejumApiService.ajustarInicio(registro['id'] as String, novo);
      ref.invalidate(jejumAtivoProvider(widget.membroId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Início ajustado ✓'),
        backgroundColor: AppColors.grn,
        duration: Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e'.replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.org,
      ));
    }
  }

  // Card de hidratação — aparece a cada bloco de 2h de jejum.
  Widget _buildHidratacaoContextual(Duration decorrido) {
    final horas = decorrido.inHours;
    if (horas < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePad, 0, AppSpacing.pagePad, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.blu.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.blu.withOpacity(0.3), width: 0.8),
        ),
        child: Row(
          children: [
            const Text('💧', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hora de hidratar',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.blu,
                        fontWeight: FontWeight.bold,
                      )),
                  Text('${horas}h de jejum · beba 500ml agora',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('500ml registrados 💧'),
                    backgroundColor: AppColors.blu,
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.blu.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.blu.withOpacity(0.3)),
                ),
                child: Text('+500ml',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.blu,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tempoAteFase(Duration decorrido, FaseMetabolica fase) {
    final minRestantes =
        (fase.inicioHoras * 60 - decorrido.inMinutes).round();
    if (minRestantes >= 60) {
      final h = minRestantes ~/ 60;
      final m = minRestantes % 60;
      return m > 0 ? '${h}h${m}min' : '${h}h';
    }
    return '${minRestantes}min';
  }
}

// ─── Painter do anel de progresso ────────────────────────────────────────────

class _AnelJejumPainter extends CustomPainter {
  final double? progresso; // null = jejum livre (anel cheio, pulsante)
  final Color cor;

  _AnelJejumPainter({required this.progresso, required this.cor});

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final raio = size.width / 2 - 12;

    final trilha = Paint()
      ..color = AppColors.bord
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(centro, raio, trilha);

    final arco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: [cor.withOpacity(0.5), cor],
        transform: const GradientRotation(-pi / 2),
      ).createShader(Rect.fromCircle(center: centro, radius: raio));

    final varredura = (progresso ?? 1.0) * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: raio),
      -pi / 2,
      varredura,
      false,
      arco,
    );
  }

  @override
  bool shouldRepaint(_AnelJejumPainter old) =>
      old.progresso != progresso || old.cor != cor;
}
