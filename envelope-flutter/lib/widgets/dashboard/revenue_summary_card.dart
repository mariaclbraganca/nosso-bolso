import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/transacoes_provider.dart';
import '../../theme/app_theme.dart';

/// Card de receitas do mês com dados REAIS do provider
class RevenueSummaryCard extends ConsumerWidget {
  const RevenueSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transacoes = ref.watch(transacoesComDetalhesProvider);

    // Somar receitas reais
    double totalReceitas = 0;
    final Map<String, double> receitaPorUsuario = {};
    for (var t in transacoes) {
      if (t['tipo'] == 'receita') {
        final val = (t['valor'] as num).toDouble();
        totalReceitas += val;
        final nome = t['usuarios']?['nome'] ?? '?';
        receitaPorUsuario[nome] = (receitaPorUsuario[nome] ?? 0) + val;
      }
    }

    final fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final fmtS = NumberFormat.simpleCurrency(locale: 'pt_BR', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.grn.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grn.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('RECEITAS DO MÊS', style: TextStyle(fontSize: 11, color: AppColors.grn, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              Text(fmt.format(totalReceitas), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.grn)),
            ],
          ),
          if (receitaPorUsuario.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: receitaPorUsuario.entries.map((e) {
                final color = AppColors.corDoUsuario(e.key);
                final abbr = e.key.length >= 2 ? e.key.substring(0, 2).toUpperCase() : '??';
                return _receitaAvatar(abbr, color, e.value, e.key, fmtS);
              }).toList(),
            ),
          ],
          if (totalReceitas == 0) ...[
            const SizedBox(height: 8),
            const Text('Nenhuma receita registrada', style: TextStyle(fontSize: 11, color: AppColors.mu)),
          ],
        ],
      ),
    );
  }

  Widget _receitaAvatar(String abbr, Color color, double val, String nome, NumberFormat fmt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.grn.withOpacity(0.12), borderRadius: BorderRadius.circular(50)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 9, backgroundColor: color.withOpacity(0.2), child: Text(abbr, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: color))),
          const SizedBox(width: 5),
          Text('${nome.split(' ')[0]} ${fmt.format(val)}', style: const TextStyle(fontSize: 11, color: AppColors.grn, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
