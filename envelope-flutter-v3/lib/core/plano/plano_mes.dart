/// Plano do mês: planejado × realizado, em regime de competência.
///
/// O mês carrega o que é DELE:
///   entradas do mês
///   − contas do mês (fixos/boletos fora do cartão)
///   − o que já está comprometido no cartão (parcelas e assinaturas que caem
///     na fatura que vence no mês seguinte)
///   − o dia a dia (envelopes), pago no cartão, Pix ou VA.
/// A fatura que vence no mês paga o dia a dia do mês anterior, então ela NÃO
/// entra de novo aqui (seria contar duas vezes). Resto de fatura antiga, quando
/// existir, entra como conta avulsa do mês.
library;

double _n(Object? v) => (v as num?)?.toDouble() ?? 0;

/// 'YYYY-MM' + n meses.
String somarMeses(String mes, int n) {
  final total = int.parse(mes.substring(0, 4)) * 12 + int.parse(mes.substring(5, 7)) - 1 + n;
  return '${total ~/ 12}-${(total % 12 + 1).toString().padLeft(2, '0')}';
}

int mesesEntre(String de, String ate) =>
    (int.parse(ate.substring(0, 4)) - int.parse(de.substring(0, 4))) * 12 +
    int.parse(ate.substring(5, 7)) -
    int.parse(de.substring(5, 7));

/// Item do cartão que cai na fatura que vence em [mesFatura], com o número da
/// parcela daquele mês (null = assinatura). Null se não cai nessa fatura.
({String descricao, double valor, int? parcela, int? total})? itemNaFatura(
    Map<String, dynamic> c, String mesFatura) {
  final desloc = mesesEntre(c['mes_fatura'] as String, mesFatura);
  if (desloc < 0) return null;
  final atual = (c['parcela_atual'] as num?)?.toInt();
  final total = (c['total_parcelas'] as num?)?.toInt();
  if (atual != null && total != null && atual + desloc > total) return null;
  return (
    descricao: c['descricao'] as String? ?? '',
    valor: _n(c['valor']),
    parcela: atual == null ? null : atual + desloc,
    total: total,
  );
}

List<({String descricao, double valor, int? parcela, int? total})> itensDaFatura(
        List<Map<String, dynamic>> compromissos, String mesFatura) =>
    [
      for (final c in compromissos)
        if (itemNaFatura(c, mesFatura) case final item?) item,
    ];

double comprometidoNaFatura(List<Map<String, dynamic>> compromissos, String mesFatura) =>
    itensDaFatura(compromissos, mesFatura).fold(0.0, (s, i) => s + i.valor);

/// Uma linha previsto × realizado.
class Linha {
  const Linha(this.previsto, this.realizado);
  final double previsto;
  final double realizado;
}

class PlanoMes {
  PlanoMes({
    required this.mes,
    required this.entradas,
    required this.contas,
    required this.envelopes,
    required this.gastoPorEnvelope,
    required this.compromissos,
    this.gastoNoCartao = 0,
    this.resgatesReserva = 0,
  });

  final String mes;
  final List<Map<String, dynamic>> entradas;
  final List<Map<String, dynamic>> contas;
  final List<Map<String, dynamic>> envelopes;
  final Map<String, double> gastoPorEnvelope;
  final List<Map<String, dynamic>> compromissos;
  final double gastoNoCartao; // compras no crédito feitas neste mês
  final double resgatesReserva; // quanto já saiu da reserva neste mês

  static double valorRecebido(Map<String, dynamic> e) =>
      e['recebido'] == true ? (e['valor_recebido'] as num?)?.toDouble() ?? _n(e['valor']) : 0;

  Linha get totalEntradas => Linha(
        entradas.fold(0.0, (s, e) => s + _n(e['valor'])),
        entradas.fold(0.0, (s, e) => s + valorRecebido(e)),
      );

  Linha get totalContas => Linha(
        contas.fold(0.0, (s, c) => s + _n(c['valor'])),
        contas.where((c) => c['pago'] == true).fold(0.0, (s, c) => s + _n(c['valor'])),
      );

  /// Fatura que vence no mês seguinte: o que já está garantido nela.
  String get mesProximaFatura => somarMeses(mes, 1);
  double get cartaoComprometido => comprometidoNaFatura(compromissos, mesProximaFatura);
  double get proximaFaturaProjetada => cartaoComprometido + gastoNoCartao;

  double tetoDe(Map<String, dynamic> env) => _n(env['valor_planejado']);
  double gastoDe(Map<String, dynamic> env) => gastoPorEnvelope[env['id']] ?? 0;

  Linha get totalDiaADia => Linha(
        envelopes.fold(0.0, (s, e) => s + tetoDe(e)),
        envelopes.fold(0.0, (s, e) => s + gastoDe(e)),
      );

  /// Como o mês fecha se tudo sair como planejado.
  double get resultadoPrevisto =>
      totalEntradas.previsto - totalContas.previsto - cartaoComprometido - totalDiaADia.previsto;

  /// Como o mês fecha com o que já aconteceu: entrada recebida conta pelo valor
  /// real; envelope que estourou conta pelo gasto; o resto segue o planejado.
  double get resultadoProjetado {
    final entradasProj = entradas.fold(
        0.0, (s, e) => s + (e['recebido'] == true ? valorRecebido(e) : _n(e['valor'])));
    final diaADia = envelopes.fold(0.0, (s, e) {
      final g = gastoDe(e), t = tetoDe(e);
      return s + (g > t ? g : t);
    });
    return entradasProj - totalContas.previsto - cartaoComprometido - diaADia;
  }

  /// Quanto ainda precisa sair da reserva para fechar o mês (0 se sobra).
  double get faltaDaReserva {
    final falta = -resultadoProjetado - resgatesReserva;
    return falta > 0 ? falta : 0;
  }

  /// Próximos meses repetindo o que é recorrente (entradas e contas) e os
  /// mesmos tetos de envelope; o cartão segue as parcelas que faltam.
  List<({String mes, double resultado, double cartao})> projecao(int meses) {
    final entradasRec = entradas.where((e) => e['recorrente'] != false).fold(0.0, (s, e) => s + _n(e['valor']));
    final contasRec = contas.where((c) => c['recorrente'] == true).fold(0.0, (s, c) => s + _n(c['valor']));
    final teto = totalDiaADia.previsto;
    return [
      for (var i = 1; i <= meses; i++)
        () {
          final m = somarMeses(mes, i);
          final cartao = comprometidoNaFatura(compromissos, somarMeses(m, 1));
          return (mes: m, resultado: entradasRec - contasRec - cartao - teto, cartao: cartao);
        }(),
    ];
  }
}
