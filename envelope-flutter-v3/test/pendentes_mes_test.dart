import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/plano/plano_mes.dart';
import 'package:nosso_bolso_v3/core/providers/plano_provider.dart';

void main() {
  final pendentes = <Map<String, dynamic>>[
    {'supermercado': 'Supermercado Tatico', 'valor_total': 478.47, 'data_compra': '2026-10-29T00:00:00'},
    {'supermercado': 'Tabacaria', 'valor_total': 240.0, 'data_compra': '2026-10-29T00:00:00'},
    {'supermercado': 'Mercado novo', 'valor_total': 50.0, 'data_compra': '2026-11-03T00:00:00'},
    {'supermercado': 'Sem data', 'valor_total': 10.0},
  ];

  LimiteMes mes(String m) => LimiteMes(
        mes: m,
        receitas: const [{'tipo': 'dinheiro', 'valor': 5491.0}],
        contasDoMes: const [],
        compromissos: const [],
        envelopes: const [{'id': 'm', 'valor_planejado': 2460}],
        compras: comprasDoMes(const [], pendentes, const {}, mes: m),
      );

  test('pendência de outubro não entra no mês nem na fatura de novembro', () {
    final nov = mes('2026-11');
    expect(nov.pendenteDeEnvelope, 60.0); // só a de 03/11 e a sem data
    expect(nov.podeGastar, 2460 - 60.0);
    expect(nov.faturaEmFormacao, 60.0); // fatura aberta (vence em dezembro): só compras de novembro
  });

  test('a mesma pendência continua valendo em outubro', () {
    final out = mes('2026-10');
    expect(out.pendenteDeEnvelope, closeTo(478.47 + 240.0 + 10.0, 0.001));
    expect(out.faturaEmFormacao, closeTo(728.47, 0.001));
  });

  test('sem informar o mês, tudo conta (comportamento de antes)', () {
    final todas = comprasDoMes(const [], pendentes, const {});
    expect(todas.length, 4);
  });
}
