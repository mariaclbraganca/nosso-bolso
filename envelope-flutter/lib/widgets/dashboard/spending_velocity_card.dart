import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/transacoes_provider.dart';
import '../../theme/app_theme.dart';

/// Card de velocidade de gastos com projeção mensal
class SpendingVelocityCard extends ConsumerWidget {
  const SpendingVelocityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transacoes = ref.watch(transacoesComDetalhesProvider);
    final now = DateTime.now();
    final diaAtual = now.day;

    // Calcular gastos do mês atual
    double totalGastoMes = 0;
    for (var t in transacoes) {
      if (t['tipo'] == 'despesa') {
        totalGastoMes += (t['valor'] as num).toDouble();
      }
    }

    // Média diária e projeção
    final mediaDiaria = diaAtual > 0 ? totalGastoMes / diaAtual : 0.0;
    final diasNoMes = DateTime(now.year, now.month + 1, 0).day;
    final projecao = mediaDiaria * diasNoMes;
    final diasRestantes = diasNoMes - diaAtual;

    final fmt = NumberFormat.simpleCurrency(locale: 'pt_BR', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blu.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.blu.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📊', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Text('RITMO DE GASTOS', style: TextStyle(fontSize: 11, color: AppColors.blu, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fmt.format(mediaDiaria), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.tx)),
                    const Text('média/dia', style: TextStyle(fontSize: 10, color: AppColors.mu)),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.bord),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fmt.format(projecao), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.org)),
                      const Text('projeção mês', style: TextStyle(fontSize: 10, color: AppColors.mu)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$diasRestantes dias restantes neste mês',
            style: const TextStyle(fontSize: 11, color: AppColors.mu),
          ),
        ],
      ),
    );
  }
}
