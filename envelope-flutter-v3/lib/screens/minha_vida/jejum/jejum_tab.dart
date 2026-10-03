import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nosso_bolso_v3/core/providers/jejum_provider.dart';
import 'package:nosso_bolso_v3/core/services/jejum_api_service.dart';
import 'package:nosso_bolso_v3/core/services/jejum_notification_service.dart';
import 'package:nosso_bolso_v3/screens/sheets/comum.dart';
import 'package:nosso_bolso_v3/ui/components/nb_components.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';
import 'package:nosso_bolso_v3/ui/unicorn/unicorn.dart';
import 'widgets/jejum_config_sheet.dart';
import 'widgets/jejum_conclusao_sheet.dart';
import 'widgets/jejum_timer_display.dart';
import 'widgets/jejum_extras.dart';
import 'jejum_historico_view.dart';
import 'jejum_insights_view.dart';
import 'jejum_together_screen.dart';

class JejumTab extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;

  const JejumTab({
    super.key,
    required this.membroId,
    required this.familiaId,
  });

  @override
  ConsumerState<JejumTab> createState() => _JejumTabState();
}

class _JejumTabState extends ConsumerState<JejumTab> {
  Timer? _timer;
  bool _iniciando = false;
  int _aba = 0; // 0 hoje, 1 histórico, 2 insights
  String? _notificacaoDoRegistro; // evita reagendar a cada rebuild

  /// Notificação fixa com o tempo + marcos (12h, 16h, janela). Usa a config
  /// de notificação e a janela do usuário, como no timer da v2.
  void _ligarNotificacoes(Map<String, dynamic> registro, Map<String, dynamic> config) {
    final id = registro['id']?.toString();
    if (id == null || id == _notificacaoDoRegistro) return;
    _notificacaoDoRegistro = id;
    JejumNotificationService.iniciar({
      ...registro,
      if (config['notif_config'] != null) 'notif_config': config['notif_config'],
      if (config['janela_fim'] != null) 'janela_fim': config['janela_fim'],
    });
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _iniciarJejum(double metaHoras) async {
    setState(() => _iniciando = true);
    try {
      final registro = await JejumApiService.iniciar(
        usuarioId: widget.membroId,
        familiaId: widget.familiaId,
        metaHoras: metaHoras,
      );
      final args = (membroId: widget.membroId, familiaId: widget.familiaId);
      _ligarNotificacoes(registro, ref.read(jejumConfigProvider(args)).valueOrNull ?? const {});
      avisar('Jejum iniciado com foco e leveza! ✨');
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _iniciando = false);
    }
  }

  void _abrirConfig(String protoAtual, Map<String, dynamic> config) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NBColors.papel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => JejumConfigSheet(
        usuarioId: widget.membroId,
        familiaId: widget.familiaId,
        protocoloAtual: protoAtual,
        config: config,
      ),
    );
  }

  Future<void> _usarSugestao(Map<String, dynamic> s) async {
    try {
      final proto = ProtocoloJejum.porId(s['protocolo'] as String? ?? '');
      await JejumApiService.salvarConfig(widget.membroId, {
        'protocolo': s['protocolo'],
        if (proto?.horas != null) 'duracao_horas': proto!.horas,
        if (s['janela_inicio'] != null) 'janela_inicio': s['janela_inicio'],
        if (s['janela_fim'] != null) 'janela_fim': s['janela_fim'],
      });
      ref.invalidate(jejumConfigProvider);
      avisar('Protocolo definido. Quando quiser, é só iniciar. ✨');
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    }
  }

  void _abrirConclusao(String regId, Duration decorrido, double metaHoras) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NBColors.papel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => JejumConclusaoSheet(
        registroId: regId,
        decorrido: decorrido,
        metaHoras: metaHoras,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Segmentado<int>(
            opcoes: const {0: 'Hoje', 1: 'Histórico', 2: 'Insights'},
            valor: _aba,
            onChanged: (v) => setState(() => _aba = v),
          ),
        ),
        Expanded(
          child: switch (_aba) {
            1 => JejumHistoricoView(membroId: widget.membroId),
            2 => JejumInsightsView(membroId: widget.membroId),
            _ => _hoje(context),
          },
        ),
      ],
    );
  }

  Widget _hoje(BuildContext context) {
    final args = (membroId: widget.membroId, familiaId: widget.familiaId);
    final configAsync = ref.watch(jejumConfigProvider(args));
    final ativoAsync = ref.watch(jejumAtivoProvider(widget.membroId));

    final config = configAsync.asData?.value ?? {};
    final protoId = config['protocolo'] as String? ?? '16_8';
    final proto = ProtocoloJejum.porId(protoId) ?? ProtocoloJejum.todos.first;

    final seqAtual = (config['sequencia_atual'] as num?)?.toInt() ?? 0;
    final jokersMes = (config['joker_days_mes'] as num?)?.toInt() ?? 0;
    final jokersUsados = (config['jokers_usados'] as num?)?.toInt() ?? 0;
    final jokers = (jokersMes - jokersUsados).clamp(0, jokersMes);

    final ativo = ativoAsync.asData?.value;
    final semHistorico = ((ref.watch(jejumHistoricoProvider(widget.membroId)).valueOrNull?['registros'] as List?) ?? const [1]).isEmpty;
    if (ativo != null) {
      _ligarNotificacoes(ativo, config);
    } else if (ativoAsync.hasValue) {
      _notificacaoDoRegistro = null;
    }
    final metaHoras = (ativo?['meta_horas'] as num?)?.toDouble() ??
        (config['duracao_horas'] as num?)?.toDouble() ??
        proto.horas ??
        16.0;
    Duration decorrido = Duration.zero;
    if (ativo != null && ativo['iniciado_em'] != null) {
      final inicio = DateTime.tryParse(ativo['iniciado_em'].toString())?.toLocal();
      if (inicio != null) {
        decorrido = DateTime.now().difference(inicio);
        if (decorrido.isNegative) decorrido = Duration.zero;
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // ── Card de Sequência e Jokers ──
        CartaoNB(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sua Sequência', style: NBText.legenda),
                    const SizedBox(height: 4),
                    Text(
                      '🔥 $seqAtual ${seqAtual == 1 ? "dia" : "dias"}',
                      style: NBText.valorCartao.copyWith(color: NBColors.ambarTexto),
                    ),
                    const SizedBox(height: 2),
                    Text('🃏 $jokers folgas disponíveis', style: NBText.legenda),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _abrirConfig(protoId, config),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: Text(proto.label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NBColors.lavanda,
                  side: const BorderSide(color: NBColors.lavanda),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (ativo == null && ativoAsync.hasValue && semHistorico) ...[
          JejumOnboardingCard(membroId: widget.membroId, onUsar: _usarSugestao),
          const SizedBox(height: 20),
        ],

        // ── Timer Circular ──
        CartaoNB(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                JejumTimerDisplay(
                  decorrido: decorrido,
                  metaHoras: metaHoras,
                  ativo: ativo != null,
                ),
                if (ativo != null) ...[
                  const SizedBox(height: 12),
                  if (textoProximaFase(decorrido) case final prox?)
                    Text(prox, style: NBText.legenda, textAlign: TextAlign.center),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () => abrirSheet(context, JejumFasesSheet(decorrido: decorrido)),
                        icon: const Icon(Icons.timeline_rounded, size: 18),
                        label: const Text('Fases'),
                      ),
                      TextButton.icon(
                        onPressed: () => ajustarInicioJejum(context, ref, ativo, widget.membroId),
                        icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                        label: const Text('Ajustar início'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                if (ativo != null)
                  BotaoPrincipal(
                    rotulo: 'Concluir Jejum ✨',
                    onPressed: () => _abrirConclusao(
                      ativo['id']?.toString() ?? '',
                      decorrido,
                      metaHoras,
                    ),
                  )
                else
                  BotaoPrincipal(
                    rotulo: 'Iniciar Jejum Agora ⏱️',
                    carregando: _iniciando,
                    onPressed: () => _iniciarJejum(metaHoras),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Fast Together ──
        CartaoNB(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => JejumTogetherScreen(membroId: widget.membroId, familiaId: widget.familiaId),
          )),
          child: Row(
            children: [
              const Text('👭', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Jejuar em dupla', style: NBText.rotulo),
                    Text(
                      switch (ref.watch(jejumTogetherProvider(args)).valueOrNull) {
                        {'parceiro': {'nome': final String nome}} => 'Você e $nome',
                        _ => 'Convide alguém da família',
                      },
                      style: NBText.legenda,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: NBColors.tintaSuave),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Mensagem de carinho Sweet ──
        const Row(
          children: [
            UnicornWidget(type: UnicornType.sweet, size: 40, mood: UnicornMood.love),
            SizedBox(width: 8),
            Expanded(
              child: UnicornFala(
                type: UnicornType.sweet,
                texto: 'Seu corpo sabe se renovar. Respeite seus limites sempre.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
