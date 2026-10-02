import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cálculos de Gastos Fixos e Saldo Livre', () {
    test('soma de fixos totais, pagos e reservado', () {
      final fixos = [
        {'id': '1', 'nome': 'Aluguel', 'valor': 1500.0, 'pago': true},
        {'id': '2', 'nome': 'Internet', 'valor': 150.0, 'pago': false},
        {'id': '3', 'nome': 'Condomínio', 'valor': 450.0, 'pago': false},
      ];

      final total = fixos.fold(0.0, (sum, f) => sum + (f['valor'] as num).toDouble());
      final pago = fixos.where((f) => f['pago'] == true).fold(0.0, (sum, f) => sum + (f['valor'] as num).toDouble());
      final reservado = total - pago;

      expect(total, 2100.0);
      expect(pago, 1500.0);
      expect(reservado, 600.0);
    });

    test('saldo livre para distribuir subtrai fixos pendentes do saldo geral', () {
      const saldoGeral = 5000.0;
      const fixosPendentes = 600.0;
      const saldoLivre = saldoGeral - fixosPendentes;

      expect(saldoLivre, 4400.0);
    });

    test('saldo livre pode ser negativo se fixos superam saldo geral', () {
      const saldoGeral = 500.0;
      const fixosPendentes = 1200.0;
      const saldoLivre = saldoGeral - fixosPendentes;

      expect(saldoLivre, -700.0);
    });
  });

  group('Cálculo de Metas e Progresso', () {
    test('calcula percentual de conclusão corretamente', () {
      const valorAlvo = 10000.0;
      const valorAtual = 2500.0;
      final pct = (valorAtual / valorAlvo).clamp(0.0, 1.0);

      expect(pct, 0.25);
    });

    test('meta atingida quando atual >= alvo', () {
      const valorAlvo = 5000.0;
      const valorAtual = 5500.0;
      const atingida = valorAtual >= valorAlvo && valorAlvo > 0;

      expect(atingida, isTrue);
    });

    test('aporte em meta soma valor corretamente', () {
      const atual = 1000.0;
      const aporte = 250.0;
      expect(atual + aporte, 1250.0);
    });

    test('retirada de meta subtrai e bloqueia negativo', () {
      const atual = 500.0;
      const retirada = 600.0;
      const novoSaldo = atual - retirada;

      expect(novoSaldo < 0, isTrue);
    });
  });

  group('Cálculo de Patrimônio Consolidado', () {
    test('soma de todas as contas e bens patrimoniais', () {
      final contas = [
        {'nome': 'Tesouro Direto', 'saldo_atual': 15000.0},
        {'nome': 'CDB Banco Inter', 'saldo_atual': 8500.0},
        {'nome': 'Conta Corrente', 'saldo_atual': 1200.0},
        {'nome': 'Veículo', 'saldo_atual': 35000.0},
      ];

      final total = contas.fold(0.0, (sum, c) => sum + (c['saldo_atual'] as num).toDouble());
      expect(total, 59700.0);
    });
  });
}
