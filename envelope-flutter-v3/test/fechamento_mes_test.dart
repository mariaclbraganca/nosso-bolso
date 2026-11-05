import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/plano/fechamento_mes.dart';
import 'package:nosso_bolso_v3/core/providers/orcamento_mes_provider.dart';

void main() {
  const fechou = '2026-12-05T10:00:00Z';

  test('gasto de novembro lançado depois do fechamento deixa o fechamento desatualizado', () {
    final txs = <Map<String, dynamic>>[
      {'data': '2026-11-28', 'created_at': '2026-12-06T09:00:00Z'}, // novembro, lançado depois
      {'data': '2026-11-10', 'created_at': '2026-11-10T09:00:00Z'}, // novembro, antes
      {'data': '2026-12-02', 'created_at': '2026-12-06T09:00:00Z'}, // dezembro: não é de novembro
      {'data': '2026-11-29', 'created_at': '2026-12-07T09:00:00Z', 'deleted_at': '2026-12-07T10:00:00Z'},
    ];
    expect(lancamentosDepoisDoFechamento('2026-11', fechou, txs), 1);
  });

  test('sem data de fechamento não há aviso', () {
    expect(lancamentosDepoisDoFechamento('2026-11', null, [{'data': '2026-11-01', 'created_at': '2026-12-06T09:00:00Z'}]), 0);
  });

  test('orçado do mês vence o do envelope; os outros ficam como estão', () {
    final envs = <Map<String, dynamic>>[
      {'id': 'a', 'valor_planejado': 500},
      {'id': 'b', 'valor_planejado': 100},
    ];
    final r = aplicarOrcadoDoMes(envs, {'a': 450.0});
    expect(r[0]['valor_planejado'], 450.0);
    expect(r[1]['valor_planejado'], 100);
    expect(envs[0]['valor_planejado'], 500); // não altera a lista original
  });
}
