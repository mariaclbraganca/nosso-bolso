import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/monitor_ia_provider.dart';
import '../../../core/services/gemini_monitor_service.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';
import '../../config/insights_astrix_screen.dart';

Color corStatusMonitor(String s) => switch (s) {
      'alerta' => NBColors.estouro,
      'atencao' => NBColors.ambarTexto,
      _ => NBColors.verde,
    };

/// Monitor IA: o Astrix olha envelopes, fixos e patrimônio e resume o mês.
/// Fechado mostra o resumo; aberto, insights, projeção e o que fazer.
class HomeMonitorIA extends ConsumerStatefulWidget {
  const HomeMonitorIA({super.key});

  @override
  ConsumerState<HomeMonitorIA> createState() => _HomeMonitorIAState();
}

class _HomeMonitorIAState extends ConsumerState<HomeMonitorIA> {
  bool _aberto = false;
  bool _atualizando = false;

  Future<void> _atualizar() async {
    setState(() => _atualizando = true);
    try {
      final _ = await ref.refresh(monitorIAForcarProvider.future); // grava o cache novo
      ref.invalidate(monitorIAProvider);
    } catch (_) {
      // o card mostra o erro do provider principal
    } finally {
      if (mounted) setState(() => _atualizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(monitorIAProvider);
    // Sem chave de IA ou sem dados: o card some em vez de mostrar erro na Home.
    if (a.hasError && !a.isLoading) return const SizedBox.shrink();
    final analise = a.valueOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: NBSpacing.s),
      child: CartaoNB(
        borda: analise == null ? NBColors.linha : corStatusMonitor(analise.status).withValues(alpha: 0.4),
        onTap: analise == null ? null : () => setState(() => _aberto = !_aberto),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const UnicornWidget(type: UnicornType.astrix, size: 32, animate: false),
                const SizedBox(width: NBSpacing.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MONITOR DO ASTRIX', style: NBText.eyebrow),
                      Text(
                        analise?.titulo ?? 'Olhando os números do mês…',
                        style: NBText.rotulo.copyWith(color: analise == null ? NBColors.tintaSuave : corStatusMonitor(analise.status)),
                      ),
                    ],
                  ),
                ),
                if (analise != null)
                  Icon(_aberto ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: NBColors.tintaSuave),
              ],
            ),
            if (analise != null) ...[
              const SizedBox(height: NBSpacing.s),
              Text(analise.resumo, style: NBText.corpo.copyWith(fontSize: 14), maxLines: _aberto ? null : 2,
                  overflow: _aberto ? null : TextOverflow.ellipsis),
              if (_aberto) ..._detalhes(context, analise),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _detalhes(BuildContext context, MonitorAnalise a) => [
        if (a.projecaoMes != null) ...[
          const SizedBox(height: NBSpacing.m),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(NBSpacing.m),
            decoration: BoxDecoration(
              color: corStatusMonitor(a.status).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(NBRadius.cartao),
            ),
            child: Text('📈 ${a.projecaoMes}', style: NBText.corpo.copyWith(fontSize: 14)),
          ),
        ],
        for (final i in a.insights)
          Padding(
            padding: const EdgeInsets.only(top: NBSpacing.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  i.tipo == 'positivo' ? Icons.trending_down_rounded : i.tipo == 'negativo' ? Icons.trending_up_rounded : Icons.remove_rounded,
                  size: 18,
                  color: i.tipo == 'positivo' ? NBColors.verde : i.tipo == 'negativo' ? NBColors.estouro : NBColors.tintaSuave,
                ),
                const SizedBox(width: NBSpacing.s),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    if (i.categoria.isNotEmpty) TextSpan(text: '${i.categoria}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: i.mensagem),
                  ]), style: NBText.legenda.copyWith(color: NBColors.tinta)),
                ),
              ],
            ),
          ),
        if (a.padraoDetectado != null) ...[
          const SizedBox(height: NBSpacing.m),
          Text('Padrão: ${a.padraoDetectado}', style: NBText.legenda),
        ],
        if (a.acoesRecomendadas.isNotEmpty) ...[
          const SizedBox(height: NBSpacing.m),
          Text('O QUE FAZER', style: NBText.eyebrow),
          for (final acao in a.acoesRecomendadas)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $acao', style: NBText.legenda.copyWith(color: NBColors.tinta)),
            ),
        ],
        const SizedBox(height: NBSpacing.s),
        Row(
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InsightsAstrixScreen())),
              child: const Text('Relatório da semana'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _atualizando ? null : _atualizar,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(_atualizando ? 'Analisando…' : 'Atualizar'),
            ),
          ],
        ),
      ];
}
