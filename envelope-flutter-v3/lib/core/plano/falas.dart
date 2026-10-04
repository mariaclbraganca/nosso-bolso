/// Falas do time: uma por vez, só quando há algo útil a dizer (null = ninguém
/// fala). Finanças: Geronimo alerta, Astrix orienta, Sweet comemora.
/// Alimentação, jejum e exercícios: só Sweet e Happy, sem dado financeiro.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/unicorn_team.dart';
import '../../ui/theme/nb_theme.dart' show brl;
import 'plano_mes.dart';

/// O que tocar na fala leva a fazer.
enum AcaoFala { nenhuma, transferir, confirmarCompras, contas }

typedef Fala = ({UnicornType quem, UnicornMood humor, String texto, AcaoFala acao});

Fala _f(UnicornType quem, UnicornMood humor, String texto, [AcaoFala acao = AcaoFala.nenhuma]) =>
    (quem: quem, humor: humor, texto: texto, acao: acao);

const _meses = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
const _semana = ['na segunda', 'na terça', 'na quarta', 'na quinta', 'na sexta', 'no sábado', 'no domingo'];

String _pct(double f) => '${(f * 100).round()}%';

/// "hoje", "amanhã" ou "na terça (07/10)".
String quandoVence(DateTime hoje, int dia) {
  final d = DateTime(hoje.year, hoje.month, dia);
  final dd = '${dia.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}';
  final diff = d.difference(DateTime(hoje.year, hoje.month, hoje.day)).inDays;
  return switch (diff) { 0 => 'hoje', 1 => 'amanhã ($dd)', _ => '${_semana[d.weekday - 1]} ($dd)' };
}

/// Fala do Início de Finanças, em ordem de prioridade.
Fala? falaDoInicio({
  required LimiteMes l,
  required List<Map<String, dynamic>> contas,
  required int pendentes,
  required DateTime hoje,
}) {
  final mesDeHoje = '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}';
  final ehMesAtual = l.mes == mesDeHoje;

  // 1. Geronimo: envelope acima do orçado
  final estourados = [
    for (final e in l.envelopes)
      if (l.orcadoDe(e) > 0 && l.disponivelDe(e) < 0) e,
  ];
  if (estourados.length == 1) {
    final e = estourados.first;
    return _f(UnicornType.geronimo, UnicornMood.chaos,
        '${e['nome_envelope'] ?? 'Um envelope'} passou ${brl(-l.disponivelDe(e))} do orçado. Toque para transferir de outro envelope.',
        AcaoFala.transferir);
  }
  if (estourados.length > 1) {
    return _f(UnicornType.geronimo, UnicornMood.chaos,
        '${estourados.length} envelopes passaram do orçado. Toque para transferir entre eles.', AcaoFala.transferir);
  }

  // 2. Geronimo: conta que vence em até 2 dias
  if (ehMesAtual) {
    double falta(Map<String, dynamic> c) => ((c['valor'] as num?)?.toDouble() ?? 0) - LimiteMes.pagoDe(c);
    final vencendo = [
      for (final c in contas)
        if (c['pago'] != true && c['dia_vencimento'] is int && falta(c) > 0.005)
          if ((c['dia_vencimento'] as int) >= hoje.day && (c['dia_vencimento'] as int) <= hoje.day + 2) c,
    ]..sort((a, b) => (a['dia_vencimento'] as int).compareTo(b['dia_vencimento'] as int));
    if (vencendo.isNotEmpty) {
      final dia = vencendo.first['dia_vencimento'] as int;
      final doDia = vencendo.where((c) => c['dia_vencimento'] == dia).toList();
      final nomes = doDia.map((c) => c['nome'] as String? ?? 'Conta').toList();
      final quem = nomes.length == 1
          ? '${nomes.first} vence'
          : '${nomes.take(nomes.length - 1).join(', ')} e ${nomes.last} vencem';
      final total = doDia.fold(0.0, (s, c) => s + falta(c));
      return _f(UnicornType.geronimo, UnicornMood.thinking, '$quem ${quandoVence(hoje, dia)}: ${brl(total)}.', AcaoFala.contas);
    }
  }

  // 3. Astrix: compras capturadas sem envelope
  if (pendentes > 0) {
    return _f(
      UnicornType.astrix,
      UnicornMood.wave,
      pendentes == 1 ? '1 compra está sem envelope. Toque para confirmar.' : '$pendentes compras estão sem envelope. Toque para confirmar.',
      AcaoFala.confirmarCompras,
    );
  }

  // 4. Astrix: gasto acima do ritmo do mês
  if (ehMesAtual && l.totalOrcado > 0) {
    final usado = (l.comprasDoMes + l.pendenteDeEnvelope) / l.totalOrcado;
    final tempo = hoje.day / DateTime(hoje.year, hoje.month + 1, 0).day;
    if (usado > tempo + 0.10) {
      return _f(UnicornType.astrix, UnicornMood.thinking,
          'Já foi ${_pct(usado)} do orçamento e o mês está em ${_pct(tempo)}. Vale segurar o ritmo.');
    }
  }

  // 5. Sweet: conquistas
  if (l.totalContas > 0 && l.faltaPagar <= 0.005) {
    return _f(UnicornType.sweet, UnicornMood.celebrate,
        'Todas as contas de ${_meses[int.parse(l.mes.substring(5, 7)) - 1]} estão pagas. Que orgulho!');
  }
  if (l.selo == SeloMes.cobertoPeloSalario && l.resultadoProjetado > 0) {
    return _f(UnicornType.sweet, UnicornMood.celebrate,
        'O mês está coberto pelo salário, com sobra de ${brl(l.resultadoProjetado)}.');
  }
  return null;
}

/// Depois de lançar uma compra.
Fala falaDaCompra({required LimiteMes? l, Map<String, dynamic>? envelope, required double valor, required String forma}) {
  if (l == null) return _f(UnicornType.astrix, UnicornMood.wave, 'Compra lançada.');
  if (forma == 'va') {
    final resta = l.disponivelVa - valor;
    return resta < 0
        ? _f(UnicornType.geronimo, UnicornMood.chaos, 'O vale-alimentação passou ${brl(-resta)} do disponível.')
        : _f(UnicornType.astrix, UnicornMood.wave, 'Lançado no VA. Restam ${brl(resta)} no vale-alimentação.');
  }
  if (envelope == null) return _f(UnicornType.astrix, UnicornMood.wave, 'Compra lançada.');
  final nome = envelope['nome_envelope'] as String? ?? 'o envelope';
  final resta = l.disponivelDe(envelope) - valor;
  return resta < 0
      ? _f(UnicornType.geronimo, UnicornMood.chaos,
          '$nome passou ${brl(-resta)} do orçado. Dá para transferir de outro envelope em Envelopes.', AcaoFala.transferir)
      : _f(UnicornType.astrix, UnicornMood.wave, 'Dentro do orçado: ainda cabem ${brl(resta)} em $nome.');
}

/// Depois de lançar uma receita.
Fala falaDaReceita(double valor, String destino) => destino == 'reserva'
    ? _f(UnicornType.sweet, UnicornMood.love, '${brl(valor)} guardados na reserva. Ótima decisão!')
    : _f(UnicornType.sweet, UnicornMood.celebrate, 'Receita de ${brl(valor)} recebida! Isso reduz o que sai da reserva.');

// ── Alimentação, jejum e exercícios (só Sweet e Happy) ──────────────────

Fala falaDaAlimentacao({required double kcal, required double metaKcal, required double proteina, required double metaProteina}) {
  if (metaProteina > 0 && proteina >= metaProteina) {
    return _f(UnicornType.sweet, UnicornMood.celebrate, 'Meta de proteína batida hoje. Seu corpo agradece!');
  }
  if (kcal <= 0) return _f(UnicornType.happy, UnicornMood.focus, 'Que tal registrar a primeira refeição do dia?');
  final faltaProt = (metaProteina - proteina).round();
  if (metaProteina > 0 && faltaProt > 0) {
    return _f(UnicornType.happy, UnicornMood.focus, 'Faltam $faltaProt g de proteína para a meta de hoje.');
  }
  return _f(UnicornType.happy, UnicornMood.focus, 'Comida boa alimenta o corpo e a mente!');
}

Fala falaDoJejum({required bool ativo, required Duration decorrido, required double metaHoras}) {
  if (!ativo) return _f(UnicornType.sweet, UnicornMood.love, 'Seu corpo sabe se renovar. Quando quiser, é só iniciar.');
  final meta = Duration(minutes: (metaHoras * 60).round());
  if (decorrido >= meta) {
    return _f(UnicornType.sweet, UnicornMood.celebrate, 'Meta de ${metaHoras.round()}h alcançada! Pode concluir quando quiser.');
  }
  final falta = meta - decorrido;
  return _f(UnicornType.happy, UnicornMood.focus,
      'Faltam ${falta.inHours}h${(falta.inMinutes % 60).toString().padLeft(2, '0')} para a meta. Que tal um copo de água?');
}

Fala falaDoExercicio({required int minSemana, int metaSemana = 150}) => minSemana >= metaSemana
    ? _f(UnicornType.sweet, UnicornMood.celebrate, 'Meta da semana batida: $minSemana min de movimento!')
    : _f(UnicornType.happy, UnicornMood.focus,
        'Faltam ${metaSemana - minSemana} min para a meta da semana. Uma caminhada ajuda.');

/// Mostra a fala no balão do time.
void falar(WidgetRef ref, Fala f) => ref.falarComo(f.quem, f.texto, f.humor);
