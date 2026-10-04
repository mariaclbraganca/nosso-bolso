import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/utils/moeda.dart';

void main() {
  test('campo de valor em reais: 60 é R\$ 60,00; centavos depois da vírgula', () {
    String n(String s) => ReaisInputFormatter.normalizar(s);
    expect(n('60'), '60');
    expect(parseMoeda(n('60')), 60);
    expect(n('60,5'), '60,5');
    expect(n('60,509'), '60,50');
    expect(n('60.5'), '60,5'); // teclado com ponto
    expect(n('1.300,00'), '1300,00'); // valor já formatado ao editar
    expect(parseMoeda(n('1.300,00')), 1300);
    expect(n(',5'), '0,5');
    expect(n('007'), '7');
    expect(n(''), '');
  });
}
