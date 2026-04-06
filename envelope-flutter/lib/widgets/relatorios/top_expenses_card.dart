import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/transacoes_provider.dart';
import '../../theme/app_theme.dart';

/// Card que mostra os 5 maiores gastos individuais do mês
class TopExpensesCard extends ConsumerWidget {
  const TopExpensesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transacoes = ref.watch(transacoesComDetalhesProvider);
    final fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');

    // Filtrar despesas e ordenar por valor
    final despesas = transacoes.where((t) => t['tipo'] == 'despesa').toList();
    despesas.sort((a, b) => (b['valor'] as num).compareTo(a['valor'] as num));
    final top5 = despesas.take(5).toList();

    if (top5.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top 5 maiores gastos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...top5.asMap().entries.map((entry) {
              final i = entry.key;
              final t = entry.value;
              final val = (t['valor'] as num).toDouble();
              final nome = t['usuarios']?['nome'] ?? '?';
              final desc = t['descricao'] ?? 'Gasto';
              final color = AppColors.corDoUsuario(nome);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.red)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(desc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                          Text(nome, style: TextStyle(fontSize: 10, color: color)),
                        ],
                      ),
                    ),
                    Text(fmt.format(val), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.red)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
