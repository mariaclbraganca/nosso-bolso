import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/insights_provider.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';

/// Relatório semanal do Astrix: nota geral, notas por área, destaques,
/// alertas e a dica da semana (finanças + alimentação + exercício).
class InsightsAstrixScreen extends ConsumerWidget {
  const InsightsAstrixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório da semana'),
        actions: [
          IconButton(
            tooltip: 'Gerar de novo',
            onPressed: () => ref.invalidate(astrixInsightsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ref.watch(astrixInsightsProvider).when(
            loading: () => const UnicornCarregando(type: UnicornType.astrix, texto: 'Montando seu relatório…'),
            error: (e, _) => UnicornErro(
              mensagem: 'Não consegui gerar o relatório agora.',
              onTentar: () => ref.invalidate(astrixInsightsProvider),
            ),
            data: (d) => d.isEmpty
                ? const UnicornVazio(
                    titulo: 'Ainda sem relatório',
                    texto: 'Use o app por alguns dias e o Astrix monta um resumo da sua semana.',
                  )
                : RelatorioAstrix(dados: d),
          ),
    );
  }
}

List<Map<String, dynamic>> _lista(Object? v) =>
    ((v as List?) ?? const []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();

class RelatorioAstrix extends StatelessWidget {
  const RelatorioAstrix({super.key, required this.dados});
  final Map<String, dynamic> dados;

  @override
  Widget build(BuildContext context) {
    final nota = (dados['score_geral'] as num?)?.toInt() ?? 70;
    final destaques = _lista(dados['destaques']);
    final alertas = _lista(dados['alertas']);
    final dica = dados['dica_semana'] as String? ?? '';
    final areas = [
      ('Finanças', (dados['financeiro_score'] as num?)?.toInt()),
      ('Alimentação', (dados['nutricao_score'] as num?)?.toInt()),
      ('Exercício', (dados['exercicio_score'] as num?)?.toInt()),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const UnicornWidget(type: UnicornType.astrix, size: 72, mood: UnicornMood.focus),
            const SizedBox(width: NBSpacing.s),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: UnicornFala(
                  type: UnicornType.astrix,
                  texto: dados['saudacao'] as String? ?? 'Olá! Aqui vai a sua semana.',
                  maxWidth: double.infinity,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: NBSpacing.l),
        CartaoNB(
          child: Column(
            children: [
              Text('NOTA DA SEMANA', style: NBText.eyebrow),
              Text('$nota', style: NBText.saldo.copyWith(color: _cor(nota))),
              Text('de 100', style: NBText.legenda),
              const SizedBox(height: NBSpacing.m),
              for (final (nome, n) in areas)
                if (n != null)
                  Padding(
                    padding: const EdgeInsets.only(top: NBSpacing.s),
                    child: Row(
                      children: [
                        SizedBox(width: 92, child: Text(nome, style: NBText.legenda)),
                        Expanded(child: BarraProgresso(fracao: n / 100, cor: _cor(n))),
                        SizedBox(width: 36, child: Text('$n', style: NBText.rotulo, textAlign: TextAlign.right)),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        if (destaques.isNotEmpty) ...[
          const SizedBox(height: NBSpacing.l),
          Text('Destaques', style: NBText.secao),
          for (final i in destaques) _Item(i: i),
        ],
        if (alertas.isNotEmpty) ...[
          const SizedBox(height: NBSpacing.l),
          Text('Pontos de atenção', style: NBText.secao),
          for (final i in alertas) _Item(i: i, alerta: true),
        ],
        if (dica.isNotEmpty) ...[
          const SizedBox(height: NBSpacing.l),
          PainelIA(titulo: 'Dica da semana', texto: dica),
        ],
      ],
    );
  }

  static Color _cor(int n) => n >= 75 ? NBColors.verde : n >= 50 ? NBColors.ambarTexto : NBColors.estouro;
}

class _Item extends StatelessWidget {
  const _Item({required this.i, this.alerta = false});
  final Map<String, dynamic> i;
  final bool alerta;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: NBSpacing.s),
        child: CartaoNB(
          cor: alerta ? NBColors.ambarClaro : NBColors.cartao,
          borda: alerta ? NBColors.ambarClaro : NBColors.linha,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(i['emoji'] as String? ?? (alerta ? '⚠️' : '✨'), style: const TextStyle(fontSize: 20)),
              const SizedBox(width: NBSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (i['titulo'] != null) Text(i['titulo'] as String, style: NBText.rotulo.copyWith(fontSize: 14)),
                    Text(i['texto'] as String? ?? '', style: NBText.corpo.copyWith(fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
