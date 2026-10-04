import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/plano/falas.dart';
import 'package:nosso_bolso_v3/core/plano/plano_mes.dart';
import 'package:nosso_bolso_v3/core/providers/unicorn_team.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

void main() {
  final envelopes = <Map<String, dynamic>>[
    {'id': 'mercado', 'nome_envelope': 'Mercado', 'valor_planejado': 1300},
    {'id': 'lazer', 'nome_envelope': 'Lazer', 'valor_planejado': 400},
  ];
  final contas = <Map<String, dynamic>>[
    {'nome': 'Fatura Aruã', 'valor': 7058.46, 'valor_pago': 5370.38, 'pago': false, 'dia_vencimento': 7},
    {'nome': 'Aluguel apartamento', 'valor': 2148.43, 'pago': false, 'dia_vencimento': 7},
    {'nome': 'Faculdade', 'valor': 586.0, 'pago': false, 'dia_vencimento': 10},
  ];
  LimiteMes mes({List<CompraMes> compras = const [], List<Map<String, dynamic>>? c, double salario = 5491}) => LimiteMes(
        mes: '2026-10',
        receitas: [{'tipo': 'dinheiro', 'valor': salario}],
        contasDoMes: c ?? contas,
        compromissos: const [],
        envelopes: envelopes,
        compras: compras,
      );
  final seg5 = DateTime(2026, 10, 5); // segunda-feira

  test('Geronimo avisa as contas que vencem em até 2 dias, juntas pelo dia', () {
    final f = falaDoInicio(l: mes(), contas: contas, pendentes: 0, hoje: seg5)!;
    expect(f.quem, UnicornType.geronimo);
    expect(f.texto, 'Fatura Aruã e Aluguel apartamento vencem na quarta (07/10): ${brl(3836.51)}.');
    expect(f.acao, AcaoFala.contas);
  });

  test('envelope acima do orçado vem antes das contas', () {
    final f = falaDoInicio(
      l: mes(compras: const [(valor: 450, envelopeId: 'lazer', forma: 'credito')]),
      contas: contas,
      pendentes: 2,
      hoje: seg5,
    )!;
    expect(f.quem, UnicornType.geronimo);
    expect(f.texto, startsWith('Lazer passou ${brl(50)} do orçado'));
    expect(f.acao, AcaoFala.transferir);
  });

  test('Astrix: compras sem envelope e depois o ritmo do mês', () {
    final semContas = <Map<String, dynamic>>[];
    final p = falaDoInicio(l: mes(c: semContas), contas: semContas, pendentes: 2, hoje: seg5)!;
    expect(p.quem, UnicornType.astrix);
    expect(p.texto, '2 compras estão sem envelope. Toque para confirmar.');
    // 850 de 1.700 = 50% do orçamento no dia 5 (16% do mês)
    final r = falaDoInicio(
      l: mes(c: semContas, compras: const [(valor: 850, envelopeId: 'mercado', forma: 'credito')]),
      contas: semContas,
      pendentes: 0,
      hoje: seg5,
    )!;
    expect(r.texto, 'Já foi 50% do orçamento e o mês está em 16%. Vale segurar o ritmo.');
  });

  test('Sweet comemora; sem nada a dizer, ninguém fala', () {
    final pagas = [for (final c in contas) {...c, 'pago': true}];
    expect(falaDoInicio(l: mes(c: pagas), contas: pagas, pendentes: 0, hoje: seg5)!.quem, UnicornType.sweet);
    final semContas = <Map<String, dynamic>>[];
    final sobra = falaDoInicio(l: mes(c: semContas), contas: semContas, pendentes: 0, hoje: seg5)!;
    expect(sobra.texto, 'O mês está coberto pelo salário, com sobra de ${brl(5491 - 1700)}.');
    expect(falaDoInicio(l: mes(c: semContas, salario: 0), contas: semContas, pendentes: 0, hoje: seg5), isNull);
  });

  test('depois de lançar: Astrix dentro do orçado, Geronimo estourou, Sweet receita', () {
    final l = mes(compras: const [(valor: 300, envelopeId: 'lazer', forma: 'credito')]);
    expect(falaDaCompra(l: l, envelope: envelopes[1], valor: 50, forma: 'credito').texto,
        'Dentro do orçado: ainda cabem ${brl(50)} em Lazer.');
    final estourou = falaDaCompra(l: l, envelope: envelopes[1], valor: 150, forma: 'credito');
    expect(estourou.quem, UnicornType.geronimo);
    expect(estourou.texto, startsWith('Lazer passou ${brl(50)} do orçado'));
    expect(falaDaReceita(1150, 'mes').quem, UnicornType.sweet);
  });

  test('saúde: só Sweet e Happy', () {
    expect(falaDaAlimentacao(kcal: 900, metaKcal: 1800, proteina: 60, metaProteina: 110).texto,
        'Faltam 50 g de proteína para a meta de hoje.');
    expect(falaDaAlimentacao(kcal: 1500, metaKcal: 1800, proteina: 115, metaProteina: 110).quem, UnicornType.sweet);
    expect(falaDoJejum(ativo: true, decorrido: const Duration(hours: 13, minutes: 5), metaHoras: 16).texto,
        'Faltam 2h55 para a meta. Que tal um copo de água?');
    expect(falaDoJejum(ativo: true, decorrido: const Duration(hours: 16, minutes: 1), metaHoras: 16).quem, UnicornType.sweet);
    expect(falaDoExercicio(minSemana: 70).texto, 'Faltam 80 min para a meta da semana. Uma caminhada ajuda.');
    expect(falaDoExercicio(minSemana: 150).quem, UnicornType.sweet);
  });
}
