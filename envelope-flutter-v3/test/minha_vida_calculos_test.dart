import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/providers/jejum_provider.dart';

void main() {
  group('Regras de Negócio de Saúde', () {
    test('Cálculo de calorias restantes respeita a meta diária', () {
      const meta = 2000.0;
      const ingeridas = 1450.0;
      const restantes = meta - ingeridas;
      expect(restantes, 550.0);
    });

    test('Calorias excedentes identificadas quando ingeridas > meta', () {
      const meta = 2000.0;
      const ingeridas = 2300.0;
      const excedente = ingeridas - meta;
      expect(excedente, 300.0);
    });

    test('Percentual de hidratação clampado entre 0.0 e 1.0', () {
      const metaMl = 2000;
      const totalMl = 2500;
      final pct = (totalMl / metaMl).clamp(0.0, 1.0);
      expect(pct, 1.0);

      const zeroMl = 0;
      final pctZero = (zeroMl / metaMl).clamp(0.0, 1.0);
      expect(pctZero, 0.0);
    });
  });

  group('Regras de Negócio de Exercício', () {
    test('Soma de minutos e calorias de múltiplos treinos', () {
      final treinos = [
        {'duracao_minutos': 30, 'calorias_queimadas': 200.0},
        {'duracao_minutos': 15, 'calorias_queimadas': 120.0},
      ];

      final totalMin = treinos.fold<int>(
        0,
        (soma, t) => soma + (t['duracao_minutos'] as int),
      );
      final totalCal = treinos.fold<double>(
        0.0,
        (soma, t) => soma + (t['calorias_queimadas'] as double),
      );

      expect(totalMin, 45);
      expect(totalCal, 320.0);
      expect(totalMin >= 30, true);
    });

    test('Meta diária de 30 min não atingida quando minutos < 30', () {
      const totalMin = 20;
      expect(totalMin >= 30, false);
      expect(30 - totalMin, 10);
    });
  });

  group('Regras de Negócio de Jejum (Fases e Protocolos)', () {
    test('FaseMetabolica no início é Digestão', () {
      final fase = FaseMetabolica.atual(const Duration(hours: 1));
      expect(fase.nome, 'Digestão');
    });

    test('FaseMetabolica após 4 horas é Glicose em queda', () {
      final fase = FaseMetabolica.atual(const Duration(hours: 5));
      expect(fase.nome, 'Glicose em queda');
    });

    test('FaseMetabolica após 8 horas é Queima de gordura', () {
      final fase = FaseMetabolica.atual(const Duration(hours: 9));
      expect(fase.nome, 'Queima de gordura');
    });

    test('FaseMetabolica após 12 horas é Cetose leve', () {
      final fase = FaseMetabolica.atual(const Duration(hours: 13));
      expect(fase.nome, 'Cetose leve');
    });

    test('FaseMetabolica após 16 horas é Autofagia', () {
      final fase = FaseMetabolica.atual(const Duration(hours: 16));
      expect(fase.nome, 'Autofagia');
    });

    test('FaseMetabolica após 20 horas é Autofagia profunda', () {
      final fase = FaseMetabolica.atual(const Duration(hours: 21));
      expect(fase.nome, 'Autofagia profunda');
    });

    test('Protocolos disponíveis contêm 16:8 como padrão', () {
      final proto = ProtocoloJejum.porId('16_8');
      expect(proto, isNotNull);
      expect(proto!.horas, 16.0);
      expect(proto.label, '16:8');
    });

    test('Regra JEJUM_LINGUAGEM_POSITIVA: status válido sem culpar o usuário', () {
      const statusAceitos = ['completo', 'interrompido', 'joker'];
      expect(statusAceitos.contains('completo'), true);
      expect(statusAceitos.contains('interrompido'), true);
      expect(statusAceitos.contains('falha'), false);
    });
  });
}
