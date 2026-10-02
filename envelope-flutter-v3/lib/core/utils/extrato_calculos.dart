/// Funções puras de cálculo do extrato — extraídas para facilitar testes.
library;

class ExtratoCalculos {
  /// Agrega uma lista de transações e retorna os totais e gastos por envelope.
  static ExtratoTotais calcular(List<Map<String, dynamic>> rows) {
    double totalReceita = 0, totalDespesa = 0, totalAbast = 0;
    final porEnvelope = <String, double>{};

    for (final t in rows) {
      final valor = (t['valor'] as num?)?.toDouble() ?? 0;
      final tipo  = t['tipo'] as String? ?? '';
      final env   = ((t['envelopes'] as Map?)?['nome_envelope'] as String?) ?? '';

      if (tipo == 'receita')      totalReceita += valor;
      if (tipo == 'despesa') {
        totalDespesa += valor;
        if (env.isNotEmpty) porEnvelope[env] = (porEnvelope[env] ?? 0) + valor;
      }
      if (tipo == 'abastecimento') totalAbast += valor;
    }

    return ExtratoTotais(
      totalReceita: totalReceita,
      totalDespesa: totalDespesa,
      totalAbast: totalAbast,
      porEnvelope: porEnvelope,
    );
  }

  /// Percentual das despesas em relação à receita. Retorna 0 se receita = 0.
  static double pctComprometido(double receita, double despesa) {
    if (receita <= 0) return 0;
    return despesa / receita * 100;
  }

  /// Status financeiro: 'ok', 'atencao' ou 'alerta'.
  static String statusFinanceiro(double receita, double despesa) {
    final saldo = receita - despesa;
    if (saldo < 0) return 'alerta';
    if (receita > 0 && saldo / receita < 0.2) return 'atencao';
    return 'ok';
  }

  /// Top N envelopes ordenados por maior gasto.
  static List<MapEntry<String, double>> topEnvelopes(
    Map<String, double> porEnvelope, {
    int n = 5,
  }) {
    final lista = porEnvelope.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return lista.take(n).toList();
  }

  /// Calcula o último dia do mês para uma string 'yyyy-MM'.
  static String ultimoDiaDoMes(String mes) {
    final parts = mes.split('-');
    final ano   = int.parse(parts[0]);
    final mNum  = int.parse(parts[1]);
    final ultimo = DateTime(ano, mNum + 1, 0).day;
    return '$mes-${ultimo.toString().padLeft(2, '0')}';
  }
}

class ExtratoTotais {
  final double totalReceita;
  final double totalDespesa;
  final double totalAbast;
  final Map<String, double> porEnvelope;

  const ExtratoTotais({
    required this.totalReceita,
    required this.totalDespesa,
    required this.totalAbast,
    required this.porEnvelope,
  });

  double get saldo => totalReceita - totalDespesa;
}
