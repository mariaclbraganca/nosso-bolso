import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/plano/fatura_cartao.dart';

void main() {
  test('ciclo da fatura: do dia 30 do mês anterior ao dia 30', () {
    expect(cicloDaFatura('2026-10'), (ini: '2026-09-30', fim: '2026-10-30'));
    expect(cicloDaFatura('2026-03'), (ini: '2026-02-28', fim: '2026-03-30'));
    expect(cicloDaFatura('2026-01'), (ini: '2025-12-30', fim: '2026-01-30'));
  });

  test('fatura que vence em novembro soma as compras do ciclo e as parcelas', () {
    final compras = <CompraCredito>[
      (data: '2026-09-30', valor: 20.0), // entra (primeiro dia do ciclo)
      (data: '2026-09-29', valor: 99.0), // fatura anterior
      (data: '2026-10-15', valor: 100.0),
      (data: '2026-10-30', valor: 50.0), // entra (último dia do ciclo)
      (data: '2026-10-31', valor: 70.0), // próxima fatura
    ];
    final compromissos = <Map<String, dynamic>>[
      {'descricao': 'Assinatura', 'valor': 30.0, 'mes_fatura': '2026-11'},
      {'descricao': 'Parcela', 'valor': 40.0, 'mes_fatura': '2026-12', 'parcela_atual': 2, 'total_parcelas': 3},
    ];
    expect(faturaQueVenceEm('2026-11', compras, compromissos), 20 + 100 + 50 + 30);
  });

  test('sem compras nem compromissos a fatura é zero', () {
    expect(faturaQueVenceEm('2026-11', const [], const []), 0);
  });
}
