import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/utils/extrato_calculos.dart';

void main() {
  // ── Helpers ──────────────────────────────────────────────────────────────
  Map<String, dynamic> receita(double v) => {'tipo': 'receita', 'valor': v, 'envelopes': null};
  Map<String, dynamic> despesa(double v, String env) => {
    'tipo': 'despesa', 'valor': v,
    'envelopes': {'nome_envelope': env},
  };
  Map<String, dynamic> aporte(double v) => {'tipo': 'abastecimento', 'valor': v, 'envelopes': null};

  // ── calcular() ────────────────────────────────────────────────────────────
  group('ExtratoCalculos.calcular', () {
    test('lista vazia retorna zeros', () {
      final t = ExtratoCalculos.calcular([]);
      expect(t.totalReceita, 0);
      expect(t.totalDespesa, 0);
      expect(t.totalAbast,   0);
      expect(t.saldo,        0);
      expect(t.porEnvelope,  isEmpty);
    });

    test('soma receitas corretamente', () {
      final t = ExtratoCalculos.calcular([receita(1000), receita(500)]);
      expect(t.totalReceita, 1500);
      expect(t.totalDespesa, 0);
    });

    test('soma despesas e agrupa por envelope', () {
      final t = ExtratoCalculos.calcular([
        despesa(200, 'Alimentação'),
        despesa(100, 'Alimentação'),
        despesa(300, 'Transporte'),
      ]);
      expect(t.totalDespesa, 600);
      expect(t.porEnvelope['Alimentação'], 300);
      expect(t.porEnvelope['Transporte'],  300);
    });

    test('soma aportes separado de despesas', () {
      final t = ExtratoCalculos.calcular([aporte(400), despesa(100, 'X')]);
      expect(t.totalAbast,   400);
      expect(t.totalDespesa, 100);
    });

    test('saldo = receita - despesa', () {
      final t = ExtratoCalculos.calcular([receita(2000), despesa(800, 'A'), despesa(300, 'B')]);
      expect(t.saldo, 900);
    });

    test('saldo negativo quando despesas superam receita', () {
      final t = ExtratoCalculos.calcular([receita(500), despesa(800, 'A')]);
      expect(t.saldo, -300);
    });

    test('despesa sem envelope não entra em porEnvelope', () {
      final t = ExtratoCalculos.calcular([
        {'tipo': 'despesa', 'valor': 100, 'envelopes': null},
      ]);
      expect(t.totalDespesa, 100);
      expect(t.porEnvelope,  isEmpty);
    });

    test('valor null é tratado como zero', () {
      final t = ExtratoCalculos.calcular([
        {'tipo': 'receita', 'valor': null, 'envelopes': null},
      ]);
      expect(t.totalReceita, 0);
    });

    test('tipo desconhecido é ignorado', () {
      final t = ExtratoCalculos.calcular([
        {'tipo': 'outro', 'valor': 999, 'envelopes': null},
      ]);
      expect(t.totalReceita, 0);
      expect(t.totalDespesa, 0);
      expect(t.totalAbast,   0);
    });
  });

  // ── pctComprometido() ─────────────────────────────────────────────────────
  group('ExtratoCalculos.pctComprometido', () {
    test('50% quando despesa é metade da receita', () {
      expect(ExtratoCalculos.pctComprometido(2000, 1000), 50);
    });

    test('100% quando despesa = receita', () {
      expect(ExtratoCalculos.pctComprometido(1000, 1000), 100);
    });

    test('retorna 0 quando receita é zero', () {
      expect(ExtratoCalculos.pctComprometido(0, 500), 0);
    });

    test('pode passar de 100% com saldo negativo', () {
      expect(ExtratoCalculos.pctComprometido(1000, 1500), 150);
    });
  });

  // ── statusFinanceiro() ────────────────────────────────────────────────────
  group('ExtratoCalculos.statusFinanceiro', () {
    test('ok quando saldo >= 20% da receita', () {
      expect(ExtratoCalculos.statusFinanceiro(1000, 700), 'ok');
    });

    test('atencao quando saldo < 20% da receita', () {
      expect(ExtratoCalculos.statusFinanceiro(1000, 850), 'atencao');
    });

    test('alerta quando saldo é negativo', () {
      expect(ExtratoCalculos.statusFinanceiro(1000, 1200), 'alerta');
    });

    test('ok quando receita e despesa são zero', () {
      expect(ExtratoCalculos.statusFinanceiro(0, 0), 'ok');
    });

    test('alerta tem prioridade sobre atencao', () {
      expect(ExtratoCalculos.statusFinanceiro(500, 600), 'alerta');
    });
  });

  // ── topEnvelopes() ────────────────────────────────────────────────────────
  group('ExtratoCalculos.topEnvelopes', () {
    test('retorna ordenado do maior para o menor', () {
      final top = ExtratoCalculos.topEnvelopes({
        'A': 100, 'B': 500, 'C': 300,
      });
      expect(top[0].key, 'B');
      expect(top[1].key, 'C');
      expect(top[2].key, 'A');
    });

    test('limita ao n solicitado', () {
      final top = ExtratoCalculos.topEnvelopes(
        {'A': 1, 'B': 2, 'C': 3, 'D': 4, 'E': 5, 'F': 6},
        n: 3,
      );
      expect(top.length, 3);
    });

    test('retorna todos quando há menos que n', () {
      final top = ExtratoCalculos.topEnvelopes({'A': 10, 'B': 20}, n: 5);
      expect(top.length, 2);
    });

    test('lista vazia retorna vazio', () {
      expect(ExtratoCalculos.topEnvelopes({}), isEmpty);
    });
  });

  // ── ultimoDiaDoMes() ──────────────────────────────────────────────────────
  group('ExtratoCalculos.ultimoDiaDoMes', () {
    test('janeiro tem 31 dias', () {
      expect(ExtratoCalculos.ultimoDiaDoMes('2024-01'), '2024-01-31');
    });

    test('fevereiro 2024 tem 29 dias (bissexto)', () {
      expect(ExtratoCalculos.ultimoDiaDoMes('2024-02'), '2024-02-29');
    });

    test('fevereiro 2025 tem 28 dias', () {
      expect(ExtratoCalculos.ultimoDiaDoMes('2025-02'), '2025-02-28');
    });

    test('abril tem 30 dias', () {
      expect(ExtratoCalculos.ultimoDiaDoMes('2024-04'), '2024-04-30');
    });

    test('dezembro tem 31 dias', () {
      expect(ExtratoCalculos.ultimoDiaDoMes('2024-12'), '2024-12-31');
    });
  });
}
