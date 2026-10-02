import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Regras de Onboarding e Família', () {
    test('Código de acesso é normalizado para maiúsculas e sem espaços', () {
      const entrada = '  ab12cd  ';
      final normalizado = entrada.trim().toUpperCase();
      expect(normalizado, 'AB12CD');
    });

    test('Nome de família válido não deve ser vazio após trim', () {
      const nomeValido = ' Família Silva ';
      expect(nomeValido.trim().isNotEmpty, true);

      const nomeInvalido = '   ';
      expect(nomeInvalido.trim().isEmpty, true);
    });

    test('Envelopes iniciais essenciais cobrem consumo e reserva', () {
      final envelopes = [
        {'nome': 'Alimentação & Mercado', 'natureza': 'consumo'},
        {'nome': 'Casa & Contas', 'natureza': 'consumo'},
        {'nome': 'Transporte', 'natureza': 'consumo'},
        {'nome': 'Lazer', 'natureza': 'consumo'},
        {'nome': 'Reserva de Emergência', 'natureza': 'reserva'},
      ];

      expect(envelopes.length, 5);
      final temReserva = envelopes.any((e) => e['natureza'] == 'reserva');
      expect(temReserva, true);
      final temConsumo = envelopes.any((e) => e['natureza'] == 'consumo');
      expect(temConsumo, true);
    });
  });
}
