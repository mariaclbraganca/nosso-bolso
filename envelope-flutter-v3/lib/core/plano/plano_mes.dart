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

export 'caixa_mes.dart';
export 'fatura_cartao.dart';

import 'caixa_mes.dart';
import 'fatura_cartao.dart';

double _n(Object? v) => (v as num?)?.toDouble() ?? 0;
double _max0(double v) => v > 0 ? v : 0;

/// Uma compra do mês, já normalizada (transação confirmada ou captura pendente).
/// [envelopeId] null = pendente de envelope. [forma]: 'credito', 'pix', 'debito',
/// 'dinheiro' ou 'va'.
typedef CompraMes = ({double valor, String? envelopeId, String forma});

/// Situação do mês no card do Início: verde, amarelo ou vermelho.
enum SeloMes { cobertoPeloSalario, dependeDaReserva, acimaDoOrcamento }

/// Ciclo do salário: o salário do fim do mês paga as compras do mês (fatura
/// do dia 7) e as contas do mês seguinte; o caixa do mês fica em [caixa].
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

  /// Valor disponível para planejar os envelopes: o garantido menos o que já
  /// está comprometido. Receita eventual recebida paga primeiro as contas deste
  /// mês; só o que sobrar delas entra aqui (nunca conta duas vezes).
  double get limite => salario + eventuaisNoCiclo - provisaoContas - lancamentosFuturos;

  /// Compromissos já travados: contas do mês seguinte + parcelas e assinaturas.
  double get comprometido => provisaoContas + lancamentosFuturos;

  /// Caixa do mês: contas que vencem agora × dinheiro que entrou para elas.
  late final CaixaDoMes caixa = CaixaDoMes(
    contas: contasDoMes,
    comprasAVista: compras.where((c) => c.forma != 'credito' && c.forma != 'va').fold(0.0, (s, c) => s + c.valor),
    dinheiroAnterior: dinheiroAnterior,
    receitasRecebidas: eventuais,
  );

  /// Receitas eventuais que sobraram depois das contas do mês (entram no ciclo).
  double get eventuaisNoCiclo => eventuais - caixa.receitasUsadas;

  /// Receitas eventuais previstas que ainda não caíram (só para mostrar).
  List<Map<String, dynamic>> get eventuaisAReceber =>
      [for (final r in receitas) if (r['tipo'] == 'eventual' && r['recebido'] != true) r];

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
  /// Falta dinheiro no ciclo do salário (sai da reserva no mês seguinte).
  double get faltaNoCiclo => _max0(-resultadoProjetado);

  /// Pode gastar ainda: o orçado nos envelopes menos o que já foi gasto.
  double get podeGastar => totalOrcado - comprasDoMes - pendenteDeEnvelope;

  /// Até o próximo salário: o que falta nas contas do mês + no ciclo.
  double get saiDaReservaAteOSalario => caixa.faltaNoMes + faltaNoCiclo;

  SeloMes get selo => podeGastar < 0
      ? SeloMes.acimaDoOrcamento
      : saiDaReservaAteOSalario > 0
          ? SeloMes.dependeDaReserva
          : SeloMes.cobertoPeloSalario;

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
