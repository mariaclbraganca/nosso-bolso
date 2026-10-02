import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nosso_bolso_v3/core/providers/jejum_provider.dart';
import 'package:nosso_bolso_v3/core/services/jejum_api_service.dart';
import 'package:nosso_bolso_v3/screens/sheets/comum.dart';
import 'package:nosso_bolso_v3/ui/components/nb_components.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';
import 'package:nosso_bolso_v3/ui/unicorn/unicorn.dart';
import 'widgets/jejum_config_sheet.dart';
import 'widgets/jejum_conclusao_sheet.dart';
import 'widgets/jejum_timer_display.dart';

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
      await JejumApiService.iniciar(
        usuarioId: widget.membroId,
        familiaId: widget.familiaId,
        metaHoras: metaHoras,
      );
      avisar('Jejum iniciado com foco e leveza! ✨');
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _iniciando = false);
    }
  }

  void _abrirConfig(String protoAtual) {
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
      ),
    );
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
    final args = (membroId: widget.membroId, familiaId: widget.familiaId);
    final configAsync = ref.watch(jejumConfigProvider(args));
    final ativoAsync = ref.watch(jejumAtivoProvider(widget.membroId));

    final config = configAsync.asData?.value ?? {};
    final protoId = config['protocolo_padrao'] as String? ?? '16_8';
    final proto = ProtocoloJejum.porId(protoId) ?? ProtocoloJejum.todos.first;
    final metaHoras = proto.horas ?? 16.0;

    final seqAtual = config['sequencia_atual'] as int? ?? 0;
    final jokers = config['jokers_disponiveis'] as int? ?? 2;

    final ativo = ativoAsync.asData?.value;
    Duration decorrido = Duration.zero;
    if (ativo != null && ativo['inicio'] != null) {
      final inicio = DateTime.tryParse(ativo['inicio'].toString());
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
                onPressed: () => _abrirConfig(protoId),
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
