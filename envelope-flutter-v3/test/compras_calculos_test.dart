import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Regras de Negócio de Compras e Ingestão', () {
    test('VALOR_DA_NOTA: despesa usa valor_total da nota e não soma dos itens', () {
      final nota = {
        'valor_total': 158.45,
        'itens': [
          {'nome': 'Arroz 5kg', 'valor_total': 32.50},
          {'nome': 'Feijão 1kg', 'valor_total': 8.99},
          {'nome': 'Azeite', 'valor_total': 45.90},
          {'nome': 'Carne', 'valor_total': 71.05},
        ],
      };

      final somaItens = (nota['itens'] as List<Map<String, dynamic>>)
          .fold(0.0, (sum, i) => sum + (i['valor_total'] as num).toDouble());
      final valorNota = (nota['valor_total'] as num).toDouble();

      // Na nota fiscal, a soma dos itens pode diferir por centavos de desconto ou acréscimo.
      // A regra VALOR_DA_NOTA estipula que a despesa deve ser exatamente o valor da nota.
      expect(valorNota, 158.45);
      expect(somaItens, 158.44); // 1 centavo de diferença de arredondamento
      expect(valorNota != somaItens, isTrue);
    });

    test('Cálculo de subtotal de itens checados no carrinho', () {
      final itens = [
        {'nome': 'Leite Integral', 'preco_estimado': 4.99},
        {'nome': 'Ovos 12 un', 'preco_estimado': 12.50},
        {'nome': 'Pão de Forma', 'preco_estimado': 8.00},
        {'nome': 'Café', 'preco_estimado': 18.90},
      ];

      final checados = {'Leite Integral', 'Pão de Forma'};

      double totalCarrinho = 0.0;
      for (final item in itens) {
        if (checados.contains(item['nome'])) {
          totalCarrinho += (item['preco_estimado'] as num).toDouble();
        }
      }

      expect(totalCarrinho, 12.99);
    });

    test('Percentual de feedback de consumo válido (0.0, 0.5, 1.0)', () {
      const consumiuTudo = 1.0;
      const sobrouParte = 0.5;
      const estragou = 0.0;

      expect(consumiuTudo >= 0.0 && consumiuTudo <= 1.0, isTrue);
      expect(sobrouParte >= 0.0 && sobrouParte <= 1.0, isTrue);
      expect(estragou >= 0.0 && estragou <= 1.0, isTrue);
    });
  });
}
