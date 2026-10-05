import 'package:flutter/material.dart';
import '../../../core/plano/plano_mes.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';

/// Média gasta por envelope nos 3 meses anteriores a [mes] (só despesas).
Map<String, double> mediaUltimosMeses(List<Map<String, dynamic>> transacoes, String mes) {
  final meses = {for (var k = 1; k <= 3; k++) somarMeses(mes, -k)};
  final soma = <String, double>{};
  for (final t in transacoes) {
    if (t['deleted_at'] != null || t['tipo'] != 'despesa' || t['envelope_id'] == null) continue;
    final d = t['data']?.toString() ?? '';
    if (d.length < 7 || !meses.contains(d.substring(0, 7))) continue;
    final id = t['envelope_id'] as String;
    soma[id] = (soma[id] ?? 0) + ((t['valor'] as num?)?.toDouble() ?? 0);
  }
  return {for (final e in soma.entries) e.key: e.value / 3};
}

/// Planejado nos envelopes × o que a família costuma gastar (média de 3 meses).
class PlanejadoXRealCard extends StatelessWidget {
  const PlanejadoXRealCard({
    super.key,
    required this.planejado,
    required this.mediaReal,
    required this.faltaNoMesSeguinte,
    required this.proximoMes,
    required this.onAjustar,
  });
  final double planejado;
  final double mediaReal;

  /// Falta no salário com o planejado de agora (0 se sobra).
  final double faltaNoMesSeguinte;
  final String proximoMes;
  final VoidCallback onAjustar;

  @override
  Widget build(BuildContext context) {
    final dif = planejado - mediaReal;
    final relevante = dif.abs() >= 50;
    final comHabito = faltaNoMesSeguinte - dif;
    final texto = !relevante
        ? 'O planejado está próximo do que vocês costumam gastar.'
        : dif > 0
            ? 'Vocês planejaram ${brl(dif)} a mais do que costumam gastar.'
                '${comHabito > 0 ? ' Mantendo o hábito, a falta de $proximoMes fica em ${brl(comHabito)}.' : ' Mantendo o hábito, sobra dinheiro em $proximoMes.'}'
            : 'Vocês planejaram ${brl(-dif)} a menos do que costumam gastar. '
                'Se o hábito continuar, a falta de $proximoMes pode chegar a ${brl(comHabito > 0 ? comHabito : 0)}.';
    return CartaoNB(
      borda: relevante ? NBColors.ambarBarra : NBColors.linha,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PLANEJADO × GASTO REAL', style: NBText.eyebrow),
        const SizedBox(height: 4),
        _linha('Planejado nos envelopes', planejado),
        _linha('Média real dos últimos 3 meses', mediaReal),
        const SizedBox(height: 4),
        Text(texto, style: NBText.corpo.copyWith(fontSize: 13.5)),
        if (relevante) ...[
          const SizedBox(height: NBSpacing.s),
          OutlinedButton(onPressed: onAjustar, child: const Text('Ajustar todos pela média')),
        ],
      ]),
    );
  }

  Widget _linha(String r, double v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(r, style: NBText.corpo.copyWith(fontSize: 14))),
          Text(brl(v), style: NBText.rotulo),
        ]),
      );
}

/// "R$ X acima da média" (âmbar) ou "abaixo da média" (verde).
class ChipMedia extends StatelessWidget {
  const ChipMedia({super.key, required this.planejado, required this.media});
  final double planejado;
  final double media;

  @override
  Widget build(BuildContext context) {
    final d = planejado - media;
    if (media <= 0 || d.abs() < 1) return const SizedBox.shrink();
    final acima = d > 0;
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: acima ? NBColors.ambarClaro : NBColors.verdeClaro,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '${brl(d.abs())} ${acima ? 'acima' : 'abaixo'} da média',
        style: NBText.legenda.copyWith(fontSize: 11, color: acima ? NBColors.ambarTexto : NBColors.verdeProfundo),
      ),
    );
  }
}

/// Envelopes de reserva: guardam um valor todo mês (não é gasto do mês).
class ReservasMensaisCard extends StatelessWidget {
  const ReservasMensaisCard({super.key, required this.reservas});
  final List<Map<String, dynamic>> reservas;

  @override
  Widget build(BuildContext context) {
    if (reservas.isEmpty) return const SizedBox.shrink();
    return CartaoNB(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('GUARDANDO TODO MÊS (RESERVAS)', style: NBText.eyebrow),
        for (final r in reservas)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(child: Text('${r['emoji'] ?? '📦'} ${r['nome_envelope'] ?? ''}', style: NBText.corpo.copyWith(fontSize: 14))),
              Text('${brl((r['valor_planejado'] as num?) ?? 0)} / mês', style: NBText.corpo.copyWith(fontSize: 14)),
            ]),
          ),
        Text('Não é gasto do mês: o valor acumula para quando precisar.', style: NBText.legenda),
      ]),
    );
  }
}
