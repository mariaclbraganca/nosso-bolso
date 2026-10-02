import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../screens/fechamento_dia/fechamento_dia_screen.dart';

/// Estado vazio ou de mês não fechado para a Retrospectiva
class RetrospectivaEmptyState extends StatelessWidget {
  final Object? error;
  final VoidCallback onMesAnterior;

  const RetrospectivaEmptyState({
    super.key,
    required this.error,
    required this.onMesAnterior,
  });

  @override
  Widget build(BuildContext context) {
    final is404 = error?.toString().contains('404') ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 56, color: AppColors.mu),
            const SizedBox(height: 16),
            Text(
              is404 ? 'Este mês ainda não foi fechado.' : 'Erro ao carregar retrospectiva',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.tx),
            ),
            const SizedBox(height: 8),
            Text(
              is404
                  ? 'A retrospectiva é gerada após o fechamento do ciclo. Você pode conferir os gastos diários ou navegar para meses anteriores.'
                  : '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.mu, height: 1.4),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onMesAnterior,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Mês anterior'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.acc,
                    side: const BorderSide(color: AppColors.acc),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FechamentoDiaScreen()),
                  ),
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: const Text('Fechamento do Dia'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.acc,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Card do resultado financeiro do mês (no azul ou no vermelho)
class RetrospectivaResultadoCard extends StatelessWidget {
  final double resultado;
  final double coberto;
  final NumberFormat fmt;

  const RetrospectivaResultadoCard({
    super.key,
    required this.resultado,
    required this.coberto,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final ficouDevendo = resultado < 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ficouDevendo
              ? [AppColors.red.withOpacity(0.18), AppColors.org.withOpacity(0.08)]
              : [AppColors.grn.withOpacity(0.18), AppColors.acc.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (ficouDevendo ? AppColors.red : AppColors.grn).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ficouDevendo ? 'O mês fechou no vermelho' : 'O mês fechou no azul',
            style: const TextStyle(fontSize: 13, color: AppColors.mu),
          ),
          const SizedBox(height: 6),
          Text(
            fmt.format(resultado),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: ficouDevendo ? AppColors.red : AppColors.grn,
              letterSpacing: -1,
            ),
          ),
          if (ficouDevendo) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Text('🛟 ', style: TextStyle(fontSize: 18)),
                  Expanded(
                    child: Text(
                      'Cobrimos ${fmt.format(coberto)} por fora para honrar as contas. '
                      'Foi o que precisou sair da reserva para fechar o mês.',
                      style: const TextStyle(fontSize: 12, color: AppColors.tx, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

