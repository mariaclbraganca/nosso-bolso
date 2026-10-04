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

/// Uma compra do mês, já normalizada (transação confirmada ou captura pendente).
/// [envelopeId] null = pendente de envelope. [forma]: 'credito', 'pix', 'debito',
/// 'dinheiro' ou 'va'.
typedef CompraMes = ({double valor, String? envelopeId, String forma});

/// Situação do mês no card do Início: verde, amarelo ou vermelho.
enum SeloMes { cobertoPeloSalario, dependeDaReserva, acimaDoOrcamento }

/// O que importa no dia a dia: quanto ainda dá para gastar no mês.
///
/// O salário do último dia útil do mês paga a fatura que vence dia 7 do mês
/// seguinte (compras deste mês + parcelas e assinaturas) e as contas do mês
/// seguinte. Por isso o limite de compras é o salário menos esses compromissos.
/// O vale-alimentação tem conta própria e acumula a sobra.
class LimiteMes {
  LimiteMes({
    required this.mes,
    required this.receitas,
    required this.contasDoMes,
    required this.compromissos,
    required this.envelopes,
    required this.compras,
    this.vaSobraAnterior = 0,
    this.dinheiroAnterior = 0,
  });

  final String mes;

  /// entradas_previstas do mês. tipo: 'dinheiro' (garantida, conta pelo
  /// previsto), 'vale' (VA) ou 'eventual' (só conta quando recebida e com
  /// destino 'mes').
  final List<Map<String, dynamic>> receitas;

  /// Fixos e boletos com vencimento no mês; as recorrentes viram a provisão
  /// do mês seguinte.
  final List<Map<String, dynamic>> contasDoMes;
  final List<Map<String, dynamic>> compromissos;

  /// Envelopes pagos com cartão ou Pix (sem o de VA e sem os de reserva).
  final List<Map<String, dynamic>> envelopes;
  final List<CompraMes> compras;
  final double vaSobraAnterior;

  /// Parte do salário do mês anterior que ficou para as contas deste mês.
  final double dinheiroAnterior;

  static double _recebido(Map<String, dynamic> r) => (r['valor_recebido'] as num?)?.toDouble() ?? _n(r['valor']);

  double get salario => receitas
      .where((r) => (r['tipo'] ?? 'dinheiro') == 'dinheiro')
      .fold(0.0, (s, r) => s + (r['recebido'] == true ? _recebido(r) : _n(r['valor'])));

  /// Nome das receitas garantidas, como cadastradas (ex.: "Salário SENAI").
  String get nomeSalario {
    final nomes = {
      for (final r in receitas)
        if ((r['tipo'] ?? 'dinheiro') == 'dinheiro') ((r['nome'] as String?)?.trim().isNotEmpty ?? false) ? r['nome'] as String : 'Salário',
    };
    return nomes.isEmpty ? 'Salário' : nomes.join(' + ');
  }

  Iterable<Map<String, dynamic>> get _eventuaisRecebidas =>
      receitas.where((r) => r['tipo'] == 'eventual' && r['recebido'] == true);

  double get eventuais => _eventuaisRecebidas.where((r) => r['destino'] != 'reserva').fold(0.0, (s, r) => s + _recebido(r));
  double get guardadoNaReserva =>
      _eventuaisRecebidas.where((r) => r['destino'] == 'reserva').fold(0.0, (s, r) => s + _recebido(r));

  List<Map<String, dynamic>> get contasProximoMes => [for (final c in contasDoMes) if (c['recorrente'] == true) c];
  double get provisaoContas => contasProximoMes.fold(0.0, (s, c) => s + _n(c['valor']));

  String get mesFatura => somarMeses(mes, 1);
  double get lancamentosFuturos => comprometidoNaFatura(compromissos, mesFatura);

  /// Disponível para planejar: só o garantido. Receitas eventuais entram no
  /// caixa do mês (reduzem o que sai da reserva), não no ciclo do salário.
  double get limite => salario - provisaoContas - lancamentosFuturos;

  Iterable<CompraMes> get _semVa => compras.where((c) => c.forma != 'va');
  double get comprasDoMes => _semVa.where((c) => c.envelopeId != null).fold(0.0, (s, c) => s + c.valor);
  double get pendenteDeEnvelope => _semVa.where((c) => c.envelopeId == null).fold(0.0, (s, c) => s + c.valor);
  double get disponivel => limite - comprasDoMes - pendenteDeEnvelope;

  double get comprasNoCredito => compras.where((c) => c.forma == 'credito').fold(0.0, (s, c) => s + c.valor);
  double get faturaEmFormacao => lancamentosFuturos + comprasNoCredito;

  double get vaMensal => receitas.where((r) => r['tipo'] == 'vale').fold(0.0, (s, r) => s + _n(r['valor']));
  double get limiteVa => vaMensal + vaSobraAnterior;
  double get gastoVa => compras.where((c) => c.forma == 'va').fold(0.0, (s, c) => s + c.valor);
  double get disponivelVa => limiteVa - gastoVa;

  double orcadoDe(Map<String, dynamic> env) => _n(env['valor_planejado']);
  double realizadoDe(Map<String, dynamic> env) =>
      _semVa.where((c) => c.envelopeId == env['id']).fold(0.0, (s, c) => s + c.valor);
  double disponivelDe(Map<String, dynamic> env) => orcadoDe(env) - realizadoDe(env);

  double get totalOrcado => envelopes.fold(0.0, (s, e) => s + orcadoDe(e));
  double get saldoADistribuir => limite - totalOrcado;
  double get resultadoPrevisto => limite - totalOrcado;
  double get resultadoProjetado =>
      limite -
      envelopes.fold(0.0, (s, e) => s + (realizadoDe(e) > orcadoDe(e) ? realizadoDe(e) : orcadoDe(e))) -
      pendenteDeEnvelope;
  double get deficitReserva => resultadoProjetado < 0 ? -resultadoProjetado : 0;

  /// Pode gastar ainda: o orçado nos envelopes menos o que já foi gasto.
  double get podeGastar => totalOrcado - comprasDoMes - pendenteDeEnvelope;

  // ── Caixa do mês: contas que vencem agora × dinheiro que entrou ──
  /// Quitada vale o valor cheio; senão, o que já foi pago em partes.
  static double pagoDe(Map<String, dynamic> c) =>
      c['pago'] == true ? _n(c['valor']) : (c['valor_pago'] as num?)?.toDouble() ?? 0;

  double get totalContas => contasDoMes.fold(0.0, (s, c) => s + _n(c['valor']));
  double get totalPago => contasDoMes.fold(0.0, (s, c) => s + pagoDe(c));
  double get faltaPagar => totalContas - totalPago;

  /// Compras que saem da conta na hora (Pix, débito, dinheiro).
  double get comprasAVista =>
      compras.where((c) => c.forma != 'credito' && c.forma != 'va').fold(0.0, (s, c) => s + c.valor);
  double get dinheiroDoMes => dinheiroAnterior + eventuais;

  double get cobertoPelaReserva => _max0(totalPago + comprasAVista - dinheiroDoMes);
  double get faltaCaixa => _max0(totalContas + comprasAVista - dinheiroDoMes);

  /// Até o próximo salário: contas sem dinheiro + falta no ciclo do salário.
  double get vaiSairDaReserva => faltaCaixa + deficitReserva;
  double get aindaFaltaSair => _max0(vaiSairDaReserva - cobertoPelaReserva);

  /// O que ainda vai sair da reserva para fechar as contas deste mês.
  double get faltaSairNoMes => _max0(faltaCaixa - cobertoPelaReserva);

  SeloMes get selo => podeGastar < 0
      ? SeloMes.acimaDoOrcamento
      : vaiSairDaReserva > 0
          ? SeloMes.dependeDaReserva
          : SeloMes.cobertoPeloSalario;

  static double _max0(double v) => v > 0 ? v : 0;
  double get economiaEmEnvelopes =>
      envelopes.fold(0.0, (s, e) => s + (disponivelDe(e) > 0 ? disponivelDe(e) : 0));

  /// Limite dos próximos meses: salário garantido − mesma provisão − parcelas
  /// que ainda faltam (sem receitas eventuais).
  List<({String mes, double limite})> proximosMeses(int n) => [
        for (var k = 1; k <= n; k++)
          (
            mes: somarMeses(mes, k),
            limite: salario - provisaoContas - comprometidoNaFatura(compromissos, somarMeses(mes, k + 1)),
          ),
      ];
}

/// Parcelas 2..n de uma compra parcelada viram lançamentos futuros: a 1ª é
/// compra do mês; a 2ª cai na fatura de [mes]+2 (a fatura de [mes]+1 traz a 1ª).
Map<String, dynamic> compromissoDaParcelada({
  required String familiaId,
  required String descricao,
  required double valorTotal,
  required int parcelas,
  required String mes,
}) =>
    {
      'familia_id': familiaId,
      'descricao': descricao,
      'valor': valorParcela(valorTotal, parcelas),
      'mes_fatura': somarMeses(mes, 2),
      'parcela_atual': 2,
      'total_parcelas': parcelas,
    };

double valorParcela(double total, int parcelas) => (total / parcelas * 100).roundToDouble() / 100;
