import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/screens/planos/contas_tab.dart';

void main() {
  final luz = {
    'familia_id': 'f1', 'nome': 'Luz', 'valor': 180.0, 'categoria': 'energia',
    'vencimento': '2026-01-31', 'recorrente': true,
  };

  test('lança o próximo mês limitando ao último dia', () {
    final p = proximoBoletoRecorrente(luz, const [])!;
    expect(p['vencimento'], '2026-02-28');
    expect(p['recorrente'], isTrue);
    expect(p['valor'], 180.0);
  });

  test('não duplica e ignora não recorrentes', () {
    expect(proximoBoletoRecorrente(luz, const [{'nome': 'Luz'}]), isNull);
    expect(proximoBoletoRecorrente({...luz, 'recorrente': false}, const []), isNull);
  });

  test('virada de ano', () {
    expect(proximoBoletoRecorrente({...luz, 'vencimento': '2026-12-10'}, const [])!['vencimento'], '2027-01-10');
  });

  test('fixos e boletos numa lista: pendentes primeiro, por dia', () {
    final l = juntarContas(
      [
        {'id': 'f1', 'nome': 'Aluguel', 'dia_vencimento': 10, 'pago': false},
        {'id': 'f2', 'nome': 'Unimed', 'dia_vencimento': 5, 'pago': true},
      ],
      [
        {'_id': 'b1', 'nome': 'Luz', 'vencimento': '2026-10-03', 'pago': false},
        {'_id': 'b2', 'nome': 'Água', 'vencimento': '2026-10-20', 'pago': false},
      ],
    );
    expect(l.map((c) => c['nome']), ['Luz', 'Aluguel', 'Água', 'Unimed']);
    expect(l.first['origem'], 'boleto');
    expect(l[1]['origem'], 'fixo');
  });
}
