import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/plano/plano_mes.dart';

/// Gabarito: os mesmos números do protótipo aprovado (outubro/2026).
void main() {
  final receitas = <Map<String, dynamic>>[
    {'nome': 'Salário', 'valor': 5491.00, 'tipo': 'dinheiro'},
    {'nome': 'Vale alimentação', 'valor': 750.00, 'tipo': 'vale'},
    {'nome': 'Aluguel da casa', 'valor': 1150.00, 'tipo': 'eventual', 'recebido': false},
  ];
  final contasOut = <Map<String, dynamic>>[
    for (final (n, v) in const [
      ('Aluguel do apartamento', 2148.43), ('Unimed', 800.87), ('Condomínio', 600.00), ('Faculdade', 586.00),
      ('Cartão Alanna', 284.08), ('MEI', 174.10), ('Internet', 94.99), ('Água', 18.00),
    ])
      {'nome': n, 'valor': v, 'recorrente': true},
    {'nome': 'Resto da fatura Nubank', 'valor': 1688.08, 'recorrente': false},
    {'nome': 'IPVA 10/10', 'valor': 288.76, 'recorrente': false},
  ];
  final compromissos = <Map<String, dynamic>>[
    for (final (d, v, a, t) in const [
      ('Auto Center', 506.95, 2, 3), ('Doutor Pet', 415.00, 6, 6), ('Totoclinicave', 362.00, 3, 5),
      ('NuViagens', 302.72, 6, 6), ('Crool', 164.80, 7, 10), ('EBW NuViagens', 124.61, 6, 6),
      ('Tag Óculos', 90.00, 2, 2), ('TikTok', 65.95, 2, 12), ('Brocker', 59.80, 4, 5), ('Mercado Livre', 42.95, 2, 2),
    ])
      {'descricao': d, 'valor': v, 'mes_fatura': '2026-11', 'parcela_atual': a, 'total_parcelas': t},
    for (final (d, v) in const [('Claude', 113.85), ('YouTube', 53.90), ('Nu Vida', 37.46)])
      {'descricao': d, 'valor': v, 'mes_fatura': '2026-11'},
  ];
  final envelopes = <Map<String, dynamic>>[
    for (final (id, v) in const [
      ('mercado', 1300), ('combustivel', 500), ('lazer', 400), ('farmacia', 150),
      ('vestuario', 150), ('pets', 100), ('celular', 90), ('casa', 32),
    ])
      {'id': id, 'valor_planejado': v},
  ];
  const comprasOut = <CompraMes>[
    (valor: 40, envelopeId: 'mercado', forma: 'credito'),
    (valor: 16, envelopeId: 'combustivel', forma: 'credito'),
  ];

  LimiteMes outubro({
    List<Map<String, dynamic>>? rec,
    List<CompraMes> compras = comprasOut,
    List<Map<String, dynamic>>? comp,
  }) =>
      LimiteMes(
        mes: '2026-10',
        receitas: rec ?? receitas,
        contasDoMes: contasOut,
        compromissos: comp ?? compromissos,
        envelopes: envelopes,
        compras: compras,
      );

  test('limite e disponível de outubro', () {
    final l = outubro();
    expect(l.provisaoContas, closeTo(4706.47, 0.001));
    expect(l.lancamentosFuturos, closeTo(2339.99, 0.001));
    expect(l.limite, closeTo(-1555.46, 0.001));
    expect(l.disponivel, closeTo(-1611.46, 0.001));
    expect(l.faturaEmFormacao, closeTo(2395.99, 0.001));
    expect(l.totalOrcado, 2722);
    expect(l.saldoADistribuir, closeTo(-4277.46, 0.001));
  });

  test('receita eventual entra no caixa do mês, não no limite do salário', () {
    final aluguel = {'nome': 'Aluguel da casa', 'valor': 1150.0, 'tipo': 'eventual', 'recebido': true, 'destino': 'mes'};
    final noMes = outubro(rec: [...receitas.take(2), aluguel]);
    expect(noMes.limite, closeTo(-1555.46, 0.001));
    expect(noMes.dinheiroDoMes, 1150);
    final l = outubro(rec: [...receitas.take(2), {...aluguel, 'destino': 'reserva'}]);
    expect(l.limite, closeTo(-1555.46, 0.001));
    expect(l.dinheiroDoMes, 0);
    expect(l.guardadoNaReserva, 1150);
  });

  group('outubro real (protótipo v8 e banco)', () {
    // Contas de outubro como estão em gastos_fixos.
    final contasReais = <Map<String, dynamic>>[
      {'nome': 'Fatura Aruã', 'valor': 7058.46, 'valor_pago': 5370.38, 'recorrente': false},
      for (final (n, v) in const [
        ('Aluguel apartamento', 2148.43), ('Faculdade', 586.00), ('Água', 18.00), ('Unimed', 800.87),
        ('Cartão Alanna', 284.08), ('MEI', 174.10), ('Internet', 96.77), ('Energia (estimativa)', 400.00),
        ('Gás (estimativa)', 65.00), ('Condomínio (estimativa)', 600.00),
      ])
        {'nome': n, 'valor': v, 'recorrente': true, 'pago': false},
    ];
    LimiteMes real({List<Map<String, dynamic>>? rec, List<Map<String, dynamic>>? contas, List<CompraMes> compras = comprasOut}) =>
        LimiteMes(
          mes: '2026-10',
          receitas: rec ?? receitas,
          contasDoMes: contas ?? contasReais,
          compromissos: compromissos,
          envelopes: envelopes,
          compras: compras,
          dinheiroAnterior: 5370.38,
        );

    test('card e orçamento', () {
      final l = real();
      expect(l.provisaoContas, closeTo(5173.25, 0.001));
      expect(l.limite, closeTo(-2022.24, 0.001)); // disponível para planejar
      expect(l.resultadoPrevisto, closeTo(-4744.24, 0.001));
      expect(l.podeGastar, closeTo(2666, 0.001));
      expect(l.selo, SeloMes.dependeDaReserva);
    });

    test('contas de outubro: fatura cheia com pagamento parcial', () {
      final l = real();
      expect(l.totalContas, closeTo(12231.71, 0.001));
      expect(l.totalPago, closeTo(5370.38, 0.001));
      expect(l.faltaPagar, closeTo(6861.33, 0.001));
      expect(l.cobertoPelaReserva, 0);
      expect(l.faltaCaixa, closeTo(6861.33, 0.001));
      expect(l.vaiSairDaReserva, closeTo(6861.33 + 4744.24, 0.001));
    });

    test('a fatura em duas linhas (como está hoje) dá o mesmo total', () {
      final dividida = [
        {'nome': 'Fatura Aruã – parte paga', 'valor': 5370.38, 'pago': true},
        {'nome': 'Fatura Aruã – restante', 'valor': 1688.08, 'pago': false},
        ...contasReais.skip(1),
      ];
      final l = real(contas: dividida);
      expect(l.totalContas, closeTo(12231.71, 0.001));
      expect(l.totalPago, closeTo(5370.38, 0.001));
    });

    test('pagar o aluguel do apartamento: sai da reserva o que passou do salário', () {
      final contas = [
        for (final c in contasReais) c['nome'] == 'Aluguel apartamento' ? {...c, 'pago': true} : c,
      ];
      final l = real(contas: contas);
      expect(l.cobertoPelaReserva, closeTo(2148.43, 0.001));
      expect(l.aindaFaltaSair, closeTo(6861.33 + 4744.24 - 2148.43, 0.001));
    });

    test('aluguel da casa recebido reduz o que sai da reserva', () {
      final aluguel = {'nome': 'Aluguel da casa', 'valor': 1150.0, 'tipo': 'eventual', 'recebido': true, 'destino': 'mes'};
      final l = real(rec: [...receitas.take(2), aluguel]);
      expect(l.limite, closeTo(-2022.24, 0.001));
      expect(l.faltaCaixa, closeTo(5711.33, 0.001));
    });

    test('receita eventual paga primeiro as contas do mês; só a sobra entra no orçamento', () {
      final aluguel = {'nome': 'Aluguel da casa', 'valor': 1150.0, 'tipo': 'eventual', 'recebido': true, 'destino': 'mes'};
      final l = real(rec: [...receitas.take(2), aluguel]);
      expect(l.eventuaisNasContas, 1150); // outubro ainda precisa de 6.861,33
      expect(l.eventuaisNoCiclo, 0);
      expect(l.limite, closeTo(-2022.24, 0.001));
      // Contas do mês de R$ 6.000: faltam 629,62 além do salário; o resto do aluguel vai para o orçamento
      final s = real(rec: [...receitas.take(2), aluguel], contas: [{'nome': 'Contas', 'valor': 6000.0}]);
      expect(s.eventuaisNasContas, closeTo(629.62, 0.001));
      expect(s.eventuaisNoCiclo, closeTo(520.38, 0.001));
      expect(s.limite, closeTo(5491 - 0 - 2339.99 + 520.38, 0.001)); // sem contas recorrentes
      expect(s.faltaCaixa, 0);
    });

    test('Pix sai do caixa na hora; crédito não', () {
      final l = real(compras: [...comprasOut, (valor: 30, envelopeId: 'lazer', forma: 'pix')]);
      expect(l.comprasAVista, 30);
      expect(l.faltaCaixa, closeTo(6891.33, 0.001));
      expect(l.podeGastar, closeTo(2636, 0.001));
    });

    test('selos', () {
      final estourou = real(compras: [(valor: 3000, envelopeId: 'mercado', forma: 'credito')]);
      expect(estourou.selo, SeloMes.acimaDoOrcamento);
      final folgado = LimiteMes(
        mes: '2026-10',
        receitas: [{'valor': 9000.0, 'tipo': 'dinheiro'}],
        contasDoMes: [{'valor': 1000.0, 'recorrente': true, 'pago': true}],
        compromissos: const [],
        envelopes: envelopes,
        compras: comprasOut,
        dinheiroAnterior: 1000,
      );
      expect(folgado.selo, SeloMes.cobertoPeloSalario);
      expect(folgado.resultadoProjetado, closeTo(9000 - 1000 - 2722, 0.001));
    });
  });

  test('pendente de envelope já desconta do disponível; VA separado', () {
    final l = outubro(compras: [
      ...comprasOut,
      (valor: 100, envelopeId: null, forma: 'credito'),
      (valor: 80, envelopeId: 'mercado', forma: 'va'),
    ]);
    expect(l.pendenteDeEnvelope, 100);
    expect(l.disponivel, closeTo(-1711.46, 0.001));
    expect(l.disponivelVa, 670);
    expect(l.realizadoDe(envelopes.first), 40); // VA não entra no envelope do cartão
  });

  test('compra parcelada 3.000 em 7x', () {
    expect(valorParcela(3000, 7), 428.57);
    final c = compromissoDaParcelada(familiaId: 'f', descricao: 'TV', valorTotal: 3000, parcelas: 7, mes: '2026-10');
    final l = outubro(
      compras: [...comprasOut, (valor: 428.57, envelopeId: 'pets', forma: 'credito')],
      comp: [...compromissos, c],
    );
    expect(l.disponivel, closeTo(-2040.03, 0.001));
    expect(l.disponivelDe(envelopes[5]), closeTo(-328.57, 0.001));
    expect(itemNaFatura(c, '2026-11'), isNull); // a 1ª é compra do mês
    expect(itemNaFatura(c, '2026-12')!.parcela, 2);
    expect(itemNaFatura(c, '2027-05')!.parcela, 7);
    expect(itemNaFatura(c, '2027-06'), isNull);
  });

  test('próximos meses, economia e déficit', () {
    final l = outubro();
    expect(l.proximosMeses(1).single.limite, closeTo(-580.18, 0.001)); // novembro
    expect(l.economiaEmEnvelopes, closeTo(2722 - 56, 0.001));
    expect(l.resultadoProjetado, closeTo(-4277.46, 0.001));
    expect(l.deficitReserva, closeTo(4277.46, 0.001));
  });
}
