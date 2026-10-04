import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/plano/falas.dart';
import '../../core/providers/insights_provider.dart';
import '../../core/providers/monitor_ia_provider.dart';
import '../../core/providers/unicorn_team.dart';
import '../../core/services/gemini_monitor_service.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';
import '../home/widgets/home_fala_time.dart';
import '../sheets/comum.dart';
import 'insights_astrix_screen.dart';

/// Relatório completo do Astrix: junta finanças, alimentação e exercícios.
/// Nunca roda sozinho — só quando alguém aperta "Gerar relatório agora".
class RelatorioCompletoScreen extends ConsumerStatefulWidget {
  const RelatorioCompletoScreen({super.key});

  @override
  ConsumerState<RelatorioCompletoScreen> createState() => _RelatorioCompletoScreenState();
}

class _RelatorioCompletoScreenState extends ConsumerState<RelatorioCompletoScreen> {
  bool _gerando = false;
  Map<String, dynamic>? _semana;
  MonitorAnalise? _financas;
  String? _erro;

  Future<void> _gerar() async {
    setState(() {
      _gerando = true;
      _erro = null;
    });
    try {
      final (semana, financas) = await (
        ref.refresh(astrixInsightsProvider.future),
        ref.refresh(monitorIAForcarProvider.future).then<MonitorAnalise?>((a) => a, onError: (_) => null),
      ).wait;
      if (mounted) {
        setState(() {
          _semana = semana;
          _financas = financas;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemErro(e));
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _financas;
    return Scaffold(
      appBar: AppBar(title: const Text('Relatório completo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
        children: [
          Text('Só é gerado quando você pede. Usa a IA (Gemini) com os dados dos últimos 7 dias.', style: NBText.legenda),
          const SizedBox(height: NBSpacing.m),
          BotaoPrincipal(
            rotulo: _semana == null ? 'Gerar relatório agora' : 'Gerar de novo',
            carregando: _gerando,
            onPressed: _gerando ? null : _gerar,
          ),
          const SizedBox(height: NBSpacing.l),
          if (_gerando) const UnicornCarregando(type: UnicornType.astrix, texto: 'Juntando finanças, alimentação e exercícios…'),
          if (_erro != null) UnicornErro(mensagem: _erro!, onTentar: _gerar),
          if (!_gerando && _semana != null) ...[
            const FalaDoTime(
              fala: (
                quem: UnicornType.astrix,
                humor: UnicornMood.wave,
                texto: 'Juntei finanças, alimentação e exercícios dos últimos 7 dias.',
                acao: AcaoFala.nenhuma,
              ),
            ),
            if (f != null) ...[
              CartaoNB(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('FINANÇAS', style: NBText.eyebrow),
                  const SizedBox(height: 4),
                  Text(f.resumo, style: NBText.corpo),
                  if (f.projecaoMes != null) ...[
                    const SizedBox(height: 6),
                    Text('Projeção: ${f.projecaoMes}', style: NBText.corpo.copyWith(fontSize: 14)),
                  ],
                  if (f.padraoDetectado != null) ...[
                    const SizedBox(height: 6),
                    Text('Padrão: ${f.padraoDetectado}', style: NBText.legenda),
                  ],
                  if (f.acoesRecomendadas.isNotEmpty) ...[
                    const SizedBox(height: NBSpacing.s),
                    Text('RECOMENDAÇÕES', style: NBText.eyebrow),
                    for (final a in f.acoesRecomendadas) Text('• $a', style: NBText.legenda.copyWith(color: NBColors.tinta)),
                  ],
                ]),
              ),
              const SizedBox(height: NBSpacing.l),
            ],
            RelatorioAstrix(dados: _semana!),
          ],
        ],
      ),
    );
  }
}
