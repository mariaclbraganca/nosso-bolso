import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/screens/home/home_screen.dart';

void main() {
  test('avisa só uma vez por envelope e de novo se voltar a ficar negativo', () {
    final avisados = <String>{};
    List<String> ids(List<Map<String, dynamic>> l) => [for (final e in l) e['id'] as String];

    expect(ids(novosNegativos(avisados, [
      {'id': 'a', 'saldo_atual': -10},
      {'id': 'b', 'saldo_atual': 50},
    ])), ['a']);
    // Mesmo estado: nada novo.
    expect(novosNegativos(avisados, [{'id': 'a', 'saldo_atual': -30}]), isEmpty);
    // Voltou ao positivo e ficou negativo de novo: avisa.
    novosNegativos(avisados, [{'id': 'a', 'saldo_atual': 5}]);
    expect(ids(novosNegativos(avisados, [{'id': 'a', 'saldo_atual': -1}])), ['a']);
  });
}
