import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/transacoes_provider.dart';

class UserSpendingBars extends ConsumerWidget {
  const UserSpendingBars({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transacoes = ref.watch(transacoesComDetalhesProvider);

    // Calcular gastos reais por usuário
    final Map<String, double> gastosPorUsuario = {};
    for (var t in transacoes) {
      if (t['tipo'] == 'despesa') {
        final nome = t['usuarios']?['nome'] ?? '?';
        gastosPorUsuario[nome] = (gastosPorUsuario[nome] ?? 0) + (t['valor'] as num).toDouble();
      }
    }

    // Ordenar do maior para o menor
    final sorted = gastosPorUsuario.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.isNotEmpty ? sorted.first.value : 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gastos por pessoa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            if (sorted.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('Sem gastos neste mês', style: TextStyle(color: AppColors.mu, fontSize: 12))),
              ),
            ...sorted.map((entry) {
              final color = AppColors.corDoUsuario(entry.key);
              final abbr = entry.key.length >= 2 ? entry.key.substring(0, 2).toUpperCase() : '??';
              return _buildUserBar(entry.key, entry.value, maxVal, color, abbr);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBar(String name, double val, double maxVal, Color color, String abbr) {
    final pct = (val / maxVal).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: color.withOpacity(0.15),
                    child: Text(abbr, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color)),
                  ),
                  const SizedBox(width: 8),
                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
              Text(NumberFormat.simpleCurrency(locale: 'pt_BR').format(val), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: AppColors.bord, color: color),
          ),
        ],
      ),
    );
  }
}
