import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/plano/plano_mes.dart';

void main() {
  // Fatura que vence em 11/2026 tem a parcela 2/3 do Auto Center e a 6/12 do TikTok…
  final compromissos = <Map<String, dynamic>>[
    {'descricao': 'Auto Center', 'valor': 506.95, 'mes_fatura': '2026-11', 'parcela_atual': 2, 'total_parcelas': 3},
    {'descricao': 'TikTok', 'valor': 65.95, 'mes_fatura': '2026-11', 'parcela_atual': 2, 'total_parcelas': 12},
    {'descricao': 'Claude', 'valor': 113.85, 'mes_fatura': '2026-11', 'parcela_atual': null, 'total_parcelas': null},
  ];

  test('meses', () {
    expect(somarMeses('2026-11', 2), '2027-01');
    expect(somarMeses('2026-01', -1), '2025-12');
    expect(mesesEntre('2026-11', '2027-02'), 3);
  });

  test('o que cai em cada fatura', () {
    expect(comprometidoNaFatura(compromissos, '2026-10'), 0); // antes de começar
    expect(comprometidoNaFatura(compromissos, '2026-11'), closeTo(686.75, 0.001));
    expect(comprometidoNaFatura(compromissos, '2026-12'), closeTo(686.75, 0.001)); // 3/3
    expect(comprometidoNaFatura(compromissos, '2027-01'), closeTo(179.80, 0.001)); // Auto Center acabou
    final dez = itensDaFatura(compromissos, '2026-12');
    expect(dez.first.parcela, 3);
    expect(dez.last.parcela, isNull);
  });

  PlanoMes plano() => PlanoMes(
        mes: '2026-10',
        entradas: [
          {'nome': 'Salário', 'valor': 5491, 'recebido': false},
          {'nome': 'Aluguel casa', 'valor': 1150, 'recebido': true, 'valor_recebido': 1100},
          {'nome': 'Bônus', 'valor': 100, 'recorrente': false},
        ],
        contas: [
          {'nome': 'Aluguel apto', 'valor': 2148.43, 'pago': true, 'recorrente': true},
          {'nome': 'Resto fatura', 'valor': 1688.08, 'pago': false, 'recorrente': false},
        ],
        envelopes: [
          {'id': 'm', 'valor_planejado': 1300},
          {'id': 'c', 'valor_planejado': 400},
        ],
        gastoPorEnvelope: {'m': 1500, 'c': 100},
        compromissos: compromissos,
        gastoNoCartao: 900,
        resgatesReserva: 500,
      );

  test('previsto × realizado do mês', () {
    final p = plano();
    expect(p.totalEntradas.previsto, 6741);
    expect(p.totalEntradas.realizado, 1100);
    expect(p.totalContas.previsto, closeTo(3836.51, 0.001));
    expect(p.totalContas.realizado, closeTo(2148.43, 0.001));
    expect(p.cartaoComprometido, closeTo(686.75, 0.001));
    expect(p.proximaFaturaProjetada, closeTo(1586.75, 0.001));
    // 6741 − 3836,51 − 686,75 − 1700
    expect(p.resultadoPrevisto, closeTo(517.74, 0.001));
    // entradas: 5491 + 1100 + 100 ; dia a dia: 1500 (estourou) + 400
    expect(p.resultadoProjetado, closeTo(6691 - 3836.51 - 686.75 - 1900, 0.001));
    expect(p.faltaDaReserva, 0);
  });

  test('falta da reserva desconta o que já foi resgatado', () {
    final p = PlanoMes(
      mes: '2026-10',
      entradas: [{'nome': 'Salário', 'valor': 1000}],
      contas: [{'nome': 'Aluguel', 'valor': 3000}],
      envelopes: const [],
      gastoPorEnvelope: const {},
      compromissos: const [],
      resgatesReserva: 1500,
    );
    expect(p.faltaDaReserva, 500);
  });

  test('projeção usa só o recorrente e as parcelas que faltam', () {
    final proj = plano().projecao(3);
    expect(proj.map((p) => p.mes), ['2026-11', '2026-12', '2027-01']);
    // entradas recorrentes 6641 − contas recorrentes 2148,43 − teto 1700 − cartão
    expect(proj[0].cartao, closeTo(686.75, 0.001)); // fatura 12/2026
    expect(proj[1].cartao, closeTo(179.80, 0.001)); // fatura 01/2027
    expect(proj[1].resultado, closeTo(6641 - 2148.43 - 1700 - 179.80, 0.001));
  });
}
