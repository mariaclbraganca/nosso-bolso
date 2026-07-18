import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../providers/transacoes_provider.dart';
import '../../providers/envelopes_provider.dart';
import '../../providers/mes_provider.dart';
import '../../providers/insights_provider.dart';
import '../../widgets/shared/error_state.dart';

/// Widget embeddable para a aba Relatórios — sem Scaffold.
class RelatoriosBody extends ConsumerWidget {
  const RelatoriosBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _RelatoriosConteudo();
  }
}

class _RelatoriosConteudo extends ConsumerWidget {
  const _RelatoriosConteudo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesAtualProvider);
    final transacoes = ref.watch(transacoesComDetalhesProvider);
    final envelopesAsync = ref.watch(envelopesProvider);
    final stats = ref.watch(totalStatsProvider);
    final statsAtual = ref.watch(statsPorMesProvider(mes));
    final insightsAsync = ref.watch(insightsProvider(mes));

    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final fmtShort = NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$');

    final despesas = transacoes.where((t) => t['tipo'] == 'despesa').toList();

    // Top 5 gastos
    final topGastos = [...despesas]
      ..sort((a, b) {
        final va = (a['valor'] as num?)?.toDouble() ?? 0;
        final vb = (b['valor'] as num?)?.toDouble() ?? 0;
        return vb.compareTo(va);
      });
    final top5 = topGastos.take(5).toList();

    // Gastos por usuário
    final Map<String, double> gastosPorUsuario = {};
    for (final t in despesas) {
      final nome = (t['usuarios']?['nome'] as String?) ?? '?';
      final val = (t['valor'] as num?)?.toDouble() ?? 0;
      gastosPorUsuario[nome] = (gastosPorUsuario[nome] ?? 0) + val;
    }

    // Gastos por envelope (para pizza)
    final Map<String, double> gastosPorEnvelope = {};
    for (final t in despesas) {
      final nome = (t['envelopes']?['nome_envelope'] as String?) ?? 'Sem envelope';
      final val = (t['valor'] as num?)?.toDouble() ?? 0;
      gastosPorEnvelope[nome] = (gastosPorEnvelope[nome] ?? 0) + val;
    }

    // Insights locais
    final List<_InsightLocal> insights = [];
    final envelopes = envelopesAsync.value ?? [];
    for (final env in envelopes) {
      final saldo = (env['saldo_atual'] as num?)?.toDouble() ?? 0;
      if (saldo < 0) {
        final nome = env['nome_envelope'] as String? ?? 'envelope';
        insights.add(_InsightLocal(
          cor: AppColors.red,
          icone: Icons.warning_amber_rounded,
          texto: 'Envelope "$nome" está negativo (${fmt.format(saldo)})',
        ));
      }
    }
    if (gastosPorUsuario.isNotEmpty) {
      final topUser = gastosPorUsuario.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      insights.add(_InsightLocal(
        cor: AppColors.org,
        icone: Icons.person_outline,
        texto: '${topUser.key} foi quem mais gastou: ${fmt.format(topUser.value)}',
      ));
    }
    if (statsAtual.totalDespesa > 0 && statsAtual.totalReceita > 0) {
      final pct = (statsAtual.totalDespesa / statsAtual.totalReceita) * 100;
      if (pct > 90) {
        insights.add(_InsightLocal(
          cor: AppColors.gold,
          icone: Icons.trending_up,
          texto: 'Gastos chegaram a ${pct.toStringAsFixed(0)}% da receita — atenção!',
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePad, AppSpacing.sectionGap,
        AppSpacing.pagePad, 120,
      ),
      children: [
        // ── KPI Cards ─────────────────────────────────────────────────────────
        _SectionLabel('Resumo do Mês'),
        const SizedBox(height: AppSpacing.cardGap),
        Row(
          children: [
            Expanded(child: _KpiCard(
              label: 'Receita',
              valor: statsAtual.totalReceita,
              cor: AppColors.grn,
              icone: Icons.arrow_downward_rounded,
            )),
            const SizedBox(width: AppSpacing.cardGap),
            Expanded(child: _KpiCard(
              label: 'Gasto',
              valor: statsAtual.totalDespesa,
              cor: AppColors.red,
              icone: Icons.arrow_upward_rounded,
            )),
            const SizedBox(width: AppSpacing.cardGap),
            Expanded(child: _KpiCard(
              label: 'Saldo',
              valor: stats['available'] ?? 0,
              cor: AppColors.acc,
              icone: Icons.account_balance_wallet_outlined,
            )),
          ],
        ),

        const SizedBox(height: AppSpacing.sectionGap),

        // ── Gráfico Pizza por Envelope ────────────────────────────────────────
        if (gastosPorEnvelope.isNotEmpty) ...[
          _SectionLabel('Gastos por Envelope'),
          const SizedBox(height: AppSpacing.cardGap),
          _CardContainer(
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: _PieChartEnvelopes(gastosPorEnvelope: gastosPorEnvelope),
                ),
                const SizedBox(height: AppSpacing.cardGap),
                _PieLegend(gastosPorEnvelope: gastosPorEnvelope, fmt: fmtShort),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
        ],

        // ── Barras por usuário ────────────────────────────────────────────────
        if (gastosPorUsuario.isNotEmpty) ...[
          _SectionLabel('Gastos por Membro'),
          const SizedBox(height: AppSpacing.cardGap),
          _CardContainer(
            child: _BarrasUsuario(
              gastosPorUsuario: gastosPorUsuario,
              fmt: fmt,
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
        ],

        // ── Comparativo mês anterior ──────────────────────────────────────────
        _SectionLabel('Comparativo com Mês Anterior'),
        const SizedBox(height: AppSpacing.cardGap),
        _ComparativoMes(mesAtual: mes),
        const SizedBox(height: AppSpacing.sectionGap),

        // ── Histórico 6 meses ─────────────────────────────────────────────────
        _SectionLabel('Histórico — Últimos 6 Meses'),
        const SizedBox(height: AppSpacing.cardGap),
        _CardContainer(
          child: _TendenciaChart(mesAtual: mes),
        ),

        const SizedBox(height: AppSpacing.sectionGap),

        // ── Comparação Budget por Envelope ────────────────────────────────────
        if (envelopes.isNotEmpty) ...[
          _SectionLabel('Budget por Envelope'),
          const SizedBox(height: AppSpacing.cardGap),
          ...envelopes.map((env) {
            final planejado = (env['valor_planejado'] as num?)?.toDouble() ?? 0;
            final saldo = (env['saldo_atual'] as num?)?.toDouble() ?? 0;
            final gasto = planejado - saldo;
            final pct = planejado > 0 ? (gasto / planejado).clamp(0.0, 1.2) : 0.0;
            final nome = env['nome_envelope'] as String? ?? '';
            final emoji = env['emoji'] as String? ?? '💰';

            Color barColor;
            if (pct <= 0.6) barColor = AppColors.grn;
            else if (pct <= 0.9) barColor = AppColors.org;
            else barColor = AppColors.red;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
              child: _CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(nome, style: AppTextStyles.bodySm)),
                        Text(
                          '${fmt.format(gasto.clamp(0, double.infinity))} / ${fmt.format(planejado)}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: AppColors.bord,
                        valueColor: AlwaysStoppedAnimation(barColor),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(pct * 100).toStringAsFixed(0)}% utilizado',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.cardGap),
        ],

        // ── Top 5 Gastos ──────────────────────────────────────────────────────
        if (top5.isNotEmpty) ...[
          _SectionLabel('Top 5 Maiores Gastos'),
          const SizedBox(height: AppSpacing.cardGap),
          _CardContainer(
            child: Column(
              children: top5.asMap().entries.map((entry) {
                final i = entry.key;
                final t = entry.value;
                final val = (t['valor'] as num?)?.toDouble() ?? 0;
                final desc = t['descricao'] as String? ?? '—';
                final envNome = (t['envelopes']?['nome_envelope'] as String?) ?? '';
                final envEmoji = (t['envelopes']?['emoji'] as String?) ?? '💰';

                return Column(
                  children: [
                    if (i > 0) const Divider(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(envEmoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(desc, style: AppTextStyles.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(envNome, style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        Text(fmt.format(val),
                          style: AppTextStyles.monoSm.copyWith(color: AppColors.red)),
                      ],
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
        ],

        // ── Sugestões Automáticas ─────────────────────────────────────────────
        _SectionLabel('Sugestões'),
        const SizedBox(height: AppSpacing.cardGap),
        ...insights.map((ins) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.itemGap),
          child: _InsightCard(insight: ins),
        )),

        // Insights da IA
        insightsAsync.when(
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.itemGap),
                Row(
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text('Insights da IA',
                      style: AppTextStyles.caption.copyWith(color: AppColors.gold)),
                  ],
                ),
                const SizedBox(height: AppSpacing.itemGap),
                ...list.map((ins) {
                  final texto = ins is Map
                      ? (ins['descricao']?.toString() ?? ins.toString())
                      : ins.toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.itemGap),
                    child: _InsightCard(
                      insight: _InsightLocal(
                        cor: AppColors.pur,
                        icone: Icons.auto_awesome,
                        texto: texto,
                      ),
                    ),
                  );
                }),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.pur,
                ),
              ),
            ),
          ),
          error: (_, __) => ErrorState(
            mensagem: 'Não foi possível carregar os insights.',
            onRetry: () => ref.invalidate(insightsProvider(mes)),
          ),
        ),

        const SizedBox(height: AppSpacing.sectionGap),
      ],
    );
  }
}

// ─── KPI Card ─────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final double valor;
  final Color cor;
  final IconData icone;

  const _KpiCard({
    required this.label,
    required this.valor,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: cor.withOpacity(0.2), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cor, size: 16),
          const SizedBox(height: 6),
          Text(fmt.format(valor),
            style: AppTextStyles.monoSm.copyWith(color: cor, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

// ─── Gráfico Pizza ────────────────────────────────────────────────────────────

const _pieColors = [
  AppColors.acc,
  AppColors.org,
  AppColors.red,
  AppColors.blu,
  AppColors.pur,
  AppColors.gold,
  AppColors.grn,
];

class _PieChartEnvelopes extends StatelessWidget {
  final Map<String, double> gastosPorEnvelope;

  const _PieChartEnvelopes({required this.gastosPorEnvelope});

  @override
  Widget build(BuildContext context) {
    final entries = gastosPorEnvelope.entries.toList();
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    if (total == 0) return const SizedBox.shrink();

    final sections = entries.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final pct = e.value / total;
      return PieChartSectionData(
        value: e.value,
        color: _pieColors[i % _pieColors.length],
        radius: 60,
        title: pct > 0.08 ? '${(pct * 100).toStringAsFixed(0)}%' : '',
        titleStyle: AppTextStyles.caption.copyWith(
          color: AppColors.bg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _PieLegend extends StatelessWidget {
  final Map<String, double> gastosPorEnvelope;
  final NumberFormat fmt;

  const _PieLegend({required this.gastosPorEnvelope, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final entries = gastosPorEnvelope.entries.toList();
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: entries.asMap().entries.map((entry) {
        final i = entry.key;
        final e = entry.value;
        final cor = _pieColors[i % _pieColors.length];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              '${e.key} ${fmt.format(e.value)}',
              style: AppTextStyles.caption,
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ─── Barras por Usuário ───────────────────────────────────────────────────────

class _BarrasUsuario extends StatelessWidget {
  final Map<String, double> gastosPorUsuario;
  final NumberFormat fmt;

  const _BarrasUsuario({
    required this.gastosPorUsuario,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final entries = gastosPorUsuario.entries.toList();
    final maxVal = entries.fold<double>(0, (m, e) => e.value > m ? e.value : m);

    return Column(
      children: entries.asMap().entries.map((entry) {
        final e = entry.value;
        final pct = maxVal > 0 ? (e.value / maxVal).clamp(0.0, 1.0) : 0.0;
        final cor = AppColors.corDoUsuario(e.key);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key, style: AppTextStyles.bodySm),
                  Text(fmt.format(e.value),
                    style: AppTextStyles.monoSm.copyWith(color: cor, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: AppColors.bord,
                  valueColor: AlwaysStoppedAnimation(cor),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Tendência Mensal (LineChart) ─────────────────────────────────────────────

// ── Comparativo mês anterior ──────────────────────────────────────────────────

class _ComparativoMes extends ConsumerWidget {
  final String mesAtual;
  const _ComparativoMes({required this.mesAtual});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ant  = mesAnterior(mesAtual);
    final cur  = ref.watch(statsPorMesProvider(mesAtual));
    final prev = ref.watch(statsPorMesProvider(ant));
    final fmt  = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final antLabel = mesLabel(ant);

    return Row(children: [
      Expanded(child: _ComparativoCard(
        label: 'Receita',
        atual: cur.totalReceita,
        anterior: prev.totalReceita,
        corPositivo: AppColors.grn,
        fmt: fmt,
        antLabel: antLabel,
      )),
      const SizedBox(width: AppSpacing.cardGap),
      Expanded(child: _ComparativoCard(
        label: 'Despesas',
        atual: cur.totalDespesa,
        anterior: prev.totalDespesa,
        corPositivo: AppColors.red,
        fmt: fmt,
        antLabel: antLabel,
        inverterSinal: true,
      )),
      const SizedBox(width: AppSpacing.cardGap),
      Expanded(child: _ComparativoCard(
        label: 'Saldo',
        atual: cur.saldo,
        anterior: prev.saldo,
        corPositivo: AppColors.acc,
        fmt: fmt,
        antLabel: antLabel,
      )),
    ]);
  }
}

class _ComparativoCard extends StatelessWidget {
  final String label;
  final double atual;
  final double anterior;
  final Color corPositivo;
  final NumberFormat fmt;
  final String antLabel;
  final bool inverterSinal;

  const _ComparativoCard({
    required this.label,
    required this.atual,
    required this.anterior,
    required this.corPositivo,
    required this.fmt,
    required this.antLabel,
    this.inverterSinal = false,
  });

  @override
  Widget build(BuildContext context) {
    final diff = anterior != 0 ? ((atual - anterior) / anterior.abs() * 100) : 0.0;
    final subiu = inverterSinal ? diff < 0 : diff > 0;
    final corDiff = diff == 0
        ? AppColors.mu
        : subiu ? AppColors.grn : AppColors.red;
    final sinal = diff > 0 ? '+' : '';
    final icone = diff == 0
        ? Icons.remove_rounded
        : diff > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.mu)),
        const SizedBox(height: 6),
        Text(
          fmt.format(atual),
          style: AppTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.bold, color: corPositivo,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Row(children: [
          Icon(icone, size: 12, color: corDiff),
          const SizedBox(width: 2),
          Expanded(child: Text(
            '$sinal${diff.toStringAsFixed(0)}% vs $antLabel',
            style: AppTextStyles.caption.copyWith(color: corDiff, fontSize: 9),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )),
        ]),
      ]),
    );
  }
}

// ── Tendência Mensal (linha) ───────────────────────────────────────────────────

class _TendenciaChart extends ConsumerWidget {
  final String mesAtual;
  const _TendenciaChart({required this.mesAtual});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meses = <String>[];
    var m = mesAtual;
    for (int i = 0; i < 6; i++) {
      meses.insert(0, m);
      m = mesAnterior(m);
    }

    final receitaSpots = <FlSpot>[];
    final despesaSpots = <FlSpot>[];
    final saldoSpots   = <FlSpot>[];

    for (int i = 0; i < meses.length; i++) {
      final stats = ref.watch(statsPorMesProvider(meses[i]));
      receitaSpots.add(FlSpot(i.toDouble(), stats.totalReceita));
      despesaSpots.add(FlSpot(i.toDouble(), stats.totalDespesa));
      saldoSpots.add(FlSpot(i.toDouble(), stats.saldo));
    }

    final labels = meses.map((mes) => mesLabel(mes)).toList();
    final fmt = NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Legenda
      Row(children: [
        _LegendaDot(cor: AppColors.grn, label: 'Receita'),
        const SizedBox(width: 16),
        _LegendaDot(cor: AppColors.red, label: 'Despesa'),
        const SizedBox(width: 16),
        _LegendaDot(cor: AppColors.acc, label: 'Saldo'),
      ]),
      const SizedBox(height: 16),

      SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(
                color: AppColors.bord, strokeWidth: 0.5,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (val, _) {
                    final idx = val.toInt();
                    if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        labels[idx].substring(0, 3),
                        style: AppTextStyles.caption.copyWith(fontSize: 9),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.surf,
                tooltipRoundedRadius: 8,
                getTooltipItems: (spots) => spots.map((s) {
                  final cores = [AppColors.grn, AppColors.red, AppColors.acc];
                  final nomes = ['Receita', 'Despesa', 'Saldo'];
                  final idx = s.barIndex.clamp(0, 2);
                  return LineTooltipItem(
                    '${nomes[idx]}\n${fmt.format(s.y)}',
                    AppTextStyles.caption.copyWith(color: cores[idx], fontSize: 10),
                  );
                }).toList(),
              ),
            ),
            lineBarsData: [
              _buildLine(receitaSpots, AppColors.grn),
              _buildLine(despesaSpots, AppColors.red),
              _buildLine(saldoSpots,   AppColors.acc, dashed: true),
            ],
          ),
        ),
      ),

      const SizedBox(height: 16),

      // Mini tabela com valores do mês atual vs anterior
      _TabelaResumoMeses(
        meses: meses,
        receitaSpots: receitaSpots,
        despesaSpots: despesaSpots,
        saldoSpots: saldoSpots,
        labels: labels,
        fmt: fmt,
      ),
    ]);
  }

  LineChartBarData _buildLine(List<FlSpot> spots, Color cor, {bool dashed = false}) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: cor,
      barWidth: dashed ? 1.5 : 2,
      dashArray: dashed ? [4, 4] : null,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
          radius: 3,
          color: cor,
          strokeWidth: 1.5,
          strokeColor: AppColors.bg,
        ),
      ),
      belowBarData: BarAreaData(
        show: !dashed,
        color: cor.withOpacity(0.06),
      ),
    );
  }
}

class _TabelaResumoMeses extends StatelessWidget {
  final List<String> meses;
  final List<FlSpot> receitaSpots;
  final List<FlSpot> despesaSpots;
  final List<FlSpot> saldoSpots;
  final List<String> labels;
  final NumberFormat fmt;

  const _TabelaResumoMeses({
    required this.meses,
    required this.receitaSpots,
    required this.despesaSpots,
    required this.saldoSpots,
    required this.labels,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    // Mostra os 3 meses mais recentes
    final n = meses.length;
    final inicio = (n - 3).clamp(0, n);
    final indices = List.generate(n - inicio, (i) => inicio + i);

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(2),
      },
      children: [
        TableRow(children: [
          _cell('Mês', header: true),
          _cell('Receita', header: true, cor: AppColors.grn),
          _cell('Despesa', header: true, cor: AppColors.red),
          _cell('Saldo', header: true, cor: AppColors.acc),
        ]),
        ...indices.map((i) => TableRow(children: [
          _cell(labels[i].substring(0, 3)),
          _cell(fmt.format(receitaSpots[i].y), cor: AppColors.grn),
          _cell(fmt.format(despesaSpots[i].y), cor: AppColors.red),
          _cell(
            fmt.format(saldoSpots[i].y),
            cor: saldoSpots[i].y >= 0 ? AppColors.acc : AppColors.red,
          ),
        ])),
      ],
    );
  }

  Widget _cell(String text, {bool header = false, Color? cor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
    child: Text(
      text,
      style: AppTextStyles.caption.copyWith(
        fontSize: header ? 9 : 9,
        fontWeight: header ? FontWeight.bold : FontWeight.normal,
        color: cor ?? (header ? AppColors.mu : AppColors.tx),
      ),
      textAlign: TextAlign.center,
    ),
  );
}

class _LegendaDot extends StatelessWidget {
  final Color cor;
  final String label;
  const _LegendaDot({required this.cor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

// ─── Insight Card ─────────────────────────────────────────────────────────────

class _InsightLocal {
  final Color cor;
  final IconData icone;
  final String texto;

  const _InsightLocal({
    required this.cor,
    required this.icone,
    required this.texto,
  });
}

class _InsightCard extends StatelessWidget {
  final _InsightLocal insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: insight.cor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: insight.cor.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(insight.icone, color: insight.cor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(insight.texto, style: AppTextStyles.bodySm),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers reutilizáveis ────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String texto;
  const _SectionLabel(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(texto, style: AppTextStyles.titleSm);
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;
  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: child,
    );
  }
}
