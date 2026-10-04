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
}
