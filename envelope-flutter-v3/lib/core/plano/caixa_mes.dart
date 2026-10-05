/// Caixa do mês: as contas que vencem neste mês × o dinheiro que entrou para
/// pagá-las (a parte do salário anterior reservada para elas + receitas
/// eventuais recebidas). O que faltar sai da reserva.
library;

double _n(Object? v) => (v as num?)?.toDouble() ?? 0;
double _max0(double v) => v > 0 ? v : 0;

class CaixaDoMes {
  const CaixaDoMes({
    required this.contas,
    required this.comprasAVista,
    required this.dinheiroAnterior,
    required this.receitasRecebidas,
  });

  /// Fixos e boletos com vencimento no mês.
  final List<Map<String, dynamic>> contas;

  /// Compras que saem da conta na hora (Pix, débito, dinheiro).
  final double comprasAVista;

  /// Parte do salário do mês anterior que ficou para as contas deste mês.
  final double dinheiroAnterior;

  /// Receitas eventuais recebidas no mês (destino "orçamento do mês").
  final double receitasRecebidas;

  /// Quitada vale o valor cheio; senão, o que já foi pago em partes.
  static double pagoDe(Map<String, dynamic> c) =>
      c['pago'] == true ? _n(c['valor']) : (c['valor_pago'] as num?)?.toDouble() ?? 0;

  double get totalContas => contas.fold(0.0, (s, c) => s + _n(c['valor']));
  double get totalPago => contas.fold(0.0, (s, c) => s + pagoDe(c));
  double get faltaPagar => totalContas - totalPago;

  double get dinheiroDoMes => dinheiroAnterior + receitasRecebidas;

  /// Quanto o mês precisa além da parte do salário anterior (antes das receitas).
  double get _necessidade => _max0(totalContas + comprasAVista - dinheiroAnterior);

  /// Parte das receitas recebidas usada nas contas deste mês (o resto vai para
  /// o ciclo do salário).
  double get receitasUsadas => receitasRecebidas < _necessidade ? receitasRecebidas : _necessidade;

  /// Quanto o mês inteiro tira da reserva (pago ou ainda a pagar).
  double get faltaNoMes => _max0(totalContas + comprasAVista - dinheiroDoMes);

  /// O que já saiu da reserva para pagar as contas.
  double get cobertoPelaReserva => _max0(totalPago + comprasAVista - dinheiroDoMes);

  /// O que ainda vai sair da reserva para terminar de pagar as contas do mês.
  double get aindaSaiNoMes => _max0(faltaNoMes - cobertoPelaReserva);
}
