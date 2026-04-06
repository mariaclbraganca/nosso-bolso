import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/envelopes_provider.dart';
import '../providers/transacoes_provider.dart';
import '../providers/mes_provider.dart';
import '../providers/insights_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/relatorios/stat_card_row.dart';
import '../widgets/relatorios/envelope_pie_chart_card.dart';
import '../widgets/relatorios/user_spending_bars.dart';
import '../widgets/relatorios/budget_comparison_chart.dart';
import '../widgets/relatorios/spending_trend_chart.dart';
import '../widgets/relatorios/top_expenses_card.dart';

class RelatoriosScreen extends ConsumerWidget {
  const RelatoriosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envelopesAsync = ref.watch(envelopesProvider);
    final mesAtu = ref.watch(mesAtualProvider);

    return envelopesAsync.when(
      data: (envelopes) {
        final transacoes = ref.watch(transacoesComDetalhesProvider);
        final mesAntVal = mesAnterior(mesAtu);
        final statsAtu = ref.watch(statsPorMesProvider(mesAtu));
        final statsAnt = ref.watch(statsPorMesProvider(mesAntVal));

        double totRec = statsAtu.totalReceita;
        double totDesp = statsAtu.totalDespesa;

        double? pctRec;
        if (statsAnt.totalReceita > 0) {
          pctRec = ((totRec - statsAnt.totalReceita) / statsAnt.totalReceita) * 100;
        }

        double? pctDesp;
        if (statsAnt.totalDespesa > 0) {
          pctDesp = ((totDesp - statsAnt.totalDespesa) / statsAnt.totalDespesa) * 100;
        }

        final totGasto = envelopes.fold<double>(0, (s, e) {
          final gasto = (e['valor_planejado'] as num).toDouble() - (e['saldo_atual'] as num).toDouble();
          return s + (gasto > 0 ? gasto : 0);
        });

        final sugestoesLocais = _gerarSugestoes(envelopes, transacoes, totRec, totDesp, statsAnt);
        final insightsIAData = ref.watch(insightsProvider(mesAtu)).value ?? [];
        
        final todasSugestoes = [
          ...sugestoesLocais,
          ...insightsIAData.map((ins) => _buildSugestao(
            ins['emoji'] ?? '💡', 
            ins['titulo']?.contains('Alerta') == true ? AppColors.red : AppColors.grn, 
            "${ins['titulo']}: ${ins['texto']}"
          )),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RELATÓRIOS', style: TextStyle(fontSize: 11, color: AppColors.mu, letterSpacing: 0.5)),
                Text(mesLabelLongo(mesAtu), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            children: [
              StatCardRow(
                totRec: totRec, 
                totGasto: totDesp,
                pctRec: pctRec,
                pctGasto: pctDesp,
              ),
              const SizedBox(height: 14),

              // 🍩 Pizza por envelope (layout protótipo: horizontal)
              EnvelopePieChartCard(envelopes: envelopes, totGasto: totGasto),
              const SizedBox(height: 12),

              // 👥 Gastos por pessoa
              const UserSpendingBars(),
              const SizedBox(height: 12),

              // 📈 Evolução de gastos no mês (NOVO)
              const SpendingTrendChart(),
              const SizedBox(height: 12),

              // 📊 Planejado vs Gasto (NOVO)
              BudgetComparisonChart(envelopes: envelopes),
              const SizedBox(height: 12),

              // 🏆 Top 5 maiores gastos (NOVO)
              const TopExpensesCard(),
              const SizedBox(height: 20),

              // 💡 Sugestões inteligentes
              if (todasSugestoes.isNotEmpty) ...[
                const Text('💡 Sugestões', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...todasSugestoes,
              ],
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('CARREGANDO...')),
        body: const Center(child: CircularProgressIndicator(color: AppColors.acc)),
      ),
      error: (e, stack) => Scaffold(
        body: Center(child: Text('Erro ao carregar gráficos: $e', style: const TextStyle(color: AppColors.red))),
      ),
    );
  }

  List<Widget> _gerarSugestoes(
    List<Map<String, dynamic>> envelopes,
    List<Map<String, dynamic>> transacoes,
    double totRec,
    double totDesp,
    MesStats statsAnt,
  ) {
    final List<Widget> result = [];

    // Comparação com mês anterior (SPEC-09)
    if (statsAnt.totalDespesa > 0) {
      if (totDesp > statsAnt.totalDespesa * 1.1) {
        result.add(_buildSugestao('📈', AppColors.red, 'Seus gastos subiram mais de 10% em relação ao mês passado. Hora de revisar os envelopes!'));
      } else if (totDesp < statsAnt.totalDespesa * 0.9) {
        result.add(_buildSugestao('🎉', AppColors.grn, 'Parabéns! Você está gastando 10% menos que no mês passado. Continue assim!'));
      }
    }

    // Envelopes negativos
    for (var e in envelopes) {
      final saldo = (e['saldo_atual'] as num).toDouble();
      final saldoAnt = (e['saldo_anterior'] as num?)?.toDouble() ?? 0.0;
      
      if (saldo < 0) {
        result.add(_buildSugestao('🚨', AppColors.dred, '${e['emoji'] ?? '📦'} ${e['nome_envelope']} está negativo em R\$ ${saldo.abs().toStringAsFixed(2)}.'));
      } else if (saldo > saldoAnt) {
        result.add(_buildSugestao('💰', AppColors.grn, '${e['emoji'] ?? '📦'} ${e['nome_envelope']} está com saldo maior que no mês passado.'));
      }
    }

    // Envelopes quase vazios (< 20%)
    for (var e in envelopes) {
      final saldo = (e['saldo_atual'] as num).toDouble();
      final plan = (e['valor_planejado'] as num).toDouble();
      if (plan > 0 && saldo >= 0 && saldo / plan <= 0.2) {
        result.add(_buildSugestao('⚠️', AppColors.org, '${e['emoji'] ?? '📦'} ${e['nome_envelope']} quase vazio — R\$ ${saldo.toStringAsFixed(2)} restantes.'));
      }
    }

    // Quem mais gastou
    final Map<String, double> gastoUser = {};
    for (var t in transacoes) {
      if (t['tipo'] == 'despesa') {
        final nome = t['usuarios']?['nome'] ?? '?';
        gastoUser[nome] = (gastoUser[nome] ?? 0) + (t['valor'] as num).toDouble();
      }
    }
    if (gastoUser.isNotEmpty && totDesp > 0) {
      final top = gastoUser.entries.reduce((a, b) => a.value > b.value ? a : b);
      final pct = (top.value / totDesp * 100).round();
      result.add(_buildSugestao('👤', AppColors.org, '${top.key} representou $pct% dos gastos (R\$ ${top.value.toStringAsFixed(0)}).'));
    }

    // Margem apertada
    if (totRec > 0 && totDesp > totRec * 0.8) {
      final pct = (totDesp / totRec * 100).round();
      result.add(_buildSugestao('💡', AppColors.org, 'Gastos em $pct% da receita. Margem apertada.'));
    }

    if (result.isEmpty) {
      result.add(_buildSugestao('✅', AppColors.grn, 'Tudo certo! Nenhum envelope em risco neste mês.'));
    }

    return result;
  }

  Widget _buildSugestao(String icon, Color color, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.5))),
        ],
      ),
    );
  }
}
