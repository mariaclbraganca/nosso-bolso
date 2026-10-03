import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/screens/minha_vida/saude/sugestao_jantar_screen.dart';

void main() {
  test('macros da sugestão vêm de macros_totais (a v2 lia o topo e mostrava 0)', () {
    final m = macrosDaSugestao({
      'nome': 'Frango com arroz',
      'macros_totais': {'calorias_kcal': 560, 'proteina_g': 42, 'carboidrato_g': 55, 'gordura_g': 14},
    });
    expect(m['calorias_kcal'], 560);
    expect(m['proteina_g'], 42);
    expect(macrosDaSugestao({'calorias_kcal': 300})['calorias_kcal'], 300);
  });
}
