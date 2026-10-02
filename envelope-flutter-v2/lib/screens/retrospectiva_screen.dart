import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/fechamento_provider.dart';

import '../widgets/retrospectiva_empty_state.dart';

/// RETROSPECTIVA DO MÊS — a consciência do ciclo.
///
/// Mostra: quanto entrou, quanto saiu, e o resultado. Se o mês fechou devendo,
/// mostra "cobrimos por fora para honrar as contas" — a consciência que a
/// família usa para ajustar comportamento. NUNCA mostra a reserva de emergência
/// (que é íntima e não vive no app).
class RetrospectivaScreen extends ConsumerStatefulWidget {
  final String mes; // 'YYYY-MM'
  const RetrospectivaScreen({super.key, required this.mes});

  @override
  ConsumerState<RetrospectivaScreen> createState() => _RetrospectivaScreenState();
}

class _RetrospectivaScreenState extends ConsumerState<RetrospectivaScreen> {
  late String _mesAtual;

  @override
  void initState() {
    super.initState();
    _mesAtual = widget.mes;
  }

  void _mudarMes(int delta) {
    final partes = _mesAtual.split('-');
    if (partes.length != 2) return;
    final ano = int.tryParse(partes[0]) ?? DateTime.now().year;
    final mes = int.tryParse(partes[1]) ?? DateTime.now().month;
    final novaData = DateTime(ano, mes + delta, 1);
    setState(() {
      _mesAtual = DateFormat('yyyy-MM').format(novaData);
    });
  }

  String _nomeMes(String m) {
    const meses = ['', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    final partes = m.split('-');
    if (partes.length != 2) return m;
    final mi = int.tryParse(partes[1]) ?? 0;
    return '${mi < meses.length ? meses[mi] : m}/${partes[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final async = ref.watch(retrospectivaProvider(_mesAtual));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Retrospectiva · ${_nomeMes(_mesAtual)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Mês anterior',
            onPressed: () => _mudarMes(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Próximo mês',
            onPressed: () => _mudarMes(1),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acc)),
        error: (e, _) => RetrospectivaEmptyState(
          error: e,
          onMesAnterior: () => _mudarMes(-1),
        ),
        data: (d) {
          if (d.isEmpty) {
            return const Center(child: Text('Sem dados para este mês.', style: TextStyle(color: AppColors.mu)));
          }
          final receita = (d['receita_total'] as num?)?.toDouble() ?? 0;
          final consumo = (d['total_consumo'] as num?)?.toDouble() ?? 0;
          final compromisso = (d['total_compromisso'] as num?)?.toDouble() ?? 0;
          final resultado = (d['resultado_mes'] as num?)?.toDouble() ?? 0;
          final coberto = (d['coberto_por_fora'] as num?)?.toDouble() ?? 0;
          final ficouDevendo = resultado < 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RetrospectivaResultadoCard(
                resultado: resultado,
                coberto: coberto,
                fmt: fmt,
              ),
              const SizedBox(height: 20),

              // Detalhamento
              _linha('💰 Entrou (receita)', receita, fmt, AppColors.grn),
              const Divider(color: AppColors.bord),
              _linha('🛒 Gastos do dia a dia', -consumo, fmt, AppColors.tx),
              const Divider(color: AppColors.bord),
              _linha('📋 Contas fixas e parcelas', -compromisso, fmt, AppColors.tx),
              const Divider(color: AppColors.bord, thickness: 1.5),
              _linha('= Resultado do mês', resultado, fmt, ficouDevendo ? AppColors.red : AppColors.grn, bold: true),

              const SizedBox(height: 24),
              if (ficouDevendo)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    '💡 Para o próximo mês fechar no azul, dá pra olhar os envelopes que '
                    'mais pesaram e ajustar as metas. Cada real que sobra vira reserva '
                    'de volta — e menos aperto no fim do mês.',
                    style: TextStyle(fontSize: 12, color: AppColors.mu, height: 1.5),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _linha(String label, double valor, NumberFormat fmt, Color cor, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: bold ? 15 : 13, color: AppColors.tx, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(fmt.format(valor), style: TextStyle(fontSize: bold ? 16 : 14, color: cor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
