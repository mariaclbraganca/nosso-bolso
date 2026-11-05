import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/providers/transacoes_provider.dart';

void main() {
  test('Extrato: despesas incluem contas fixas pagas, sem a fatura do cartão', () async {
    final txs = <Map<String, dynamic>>[
      {'tipo': 'receita', 'valor': 3000.0, 'data': '2026-10-05'},
      {'tipo': 'despesa', 'valor': 1000.0, 'data': '2026-10-10'},
      {'tipo': 'despesa_fixa', 'valor': 800.0, 'data': '2026-10-07', 'descricao': 'Aluguel (fixo 2026-10)'},
      {'tipo': 'despesa_fixa', 'valor': 7000.0, 'data': '2026-10-07', 'descricao': 'Fatura Aruã (fixo 2026-10)'},
      {'tipo': 'despesa', 'valor': 50.0, 'data': '2026-11-02'}, // outro mês
    ];
    final c = ProviderContainer(overrides: [transacoesStreamProvider.overrideWith((ref) => Stream.value(txs))]);
    addTearDown(c.dispose);
    await c.read(transacoesStreamProvider.future);
    final s = c.read(statsPorMesProvider('2026-10'));
    expect(s.totalReceita, 3000);
    expect(s.totalDespesa, 1800); // 1000 nos envelopes + 800 de aluguel; a fatura fica de fora
    expect(s.saldo, 1200);
  });
}
