import 'package:flutter/material.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';

/// Meses até a meta com juros compostos mensais + aporte fixo.
/// 0 = já atingiu; null = não chega em 50 anos.
int? mesesAteMeta({required double saldo, required double meta, required double rendimentoPct, required double aporte}) {
  if (saldo >= meta) return 0;
  if (aporte <= 0 && rendimentoPct <= 0) return null;
  final r = rendimentoPct / 100;
  var s = saldo;
  for (var i = 1; i <= 600; i++) {
    s = s * (1 + r) + aporte;
    if (s >= meta) return i;
  }
  return null;
}

String textoPrazo(int? meses) {
  if (meses == null) return 'Sem aporte não chega lá';
  if (meses == 0) return 'Meta atingida! 🎉';
  if (meses < 12) return '$meses ${meses == 1 ? 'mês' : 'meses'}';
  final anos = meses ~/ 12, resto = meses % 12;
  final a = '$anos ${anos == 1 ? 'ano' : 'anos'}';
  return resto == 0 ? a : '$a e $resto ${resto == 1 ? 'mês' : 'meses'}';
}

/// Conta com meta de saldo: progresso, slider de aporte mensal e quando chega.
class PatrimonioMetaCard extends StatefulWidget {
  const PatrimonioMetaCard({super.key, required this.conta, required this.saldoLivre});
  final Map<String, dynamic> conta;
  final double saldoLivre;

  @override
  State<PatrimonioMetaCard> createState() => _PatrimonioMetaCardState();
}

class _PatrimonioMetaCardState extends State<PatrimonioMetaCard> {
  late double _aporte;

  double get _saldo => (widget.conta['saldo_atual'] as num?)?.toDouble() ?? 0;
  double get _meta => (widget.conta['meta_saldo'] as num?)?.toDouble() ?? 0;
  double get _rend => (widget.conta['rendimento_mensal'] as num?)?.toDouble() ?? 0;
  double get _max => (widget.saldoLivre * 0.8).clamp(200.0, 10000.0);

  @override
  void initState() {
    super.initState();
    _aporte = (widget.saldoLivre * 0.2).clamp(50.0, _max);
  }

  @override
  Widget build(BuildContext context) {
    final fracao = _meta > 0 ? (_saldo / _meta).clamp(0.0, 1.0) : 0.0;
    final meses = mesesAteMeta(saldo: _saldo, meta: _meta, rendimentoPct: _rend, aporte: _aporte);
    final semAporte = mesesAteMeta(saldo: _saldo, meta: _meta, rendimentoPct: _rend, aporte: 0);
    final agora = DateTime.now();
    final chegada = meses == null || meses == 0 ? null : DateTime(agora.year, agora.month + meses);
    const nomesMes = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

    return CartaoNB(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.conta['emoji'] as String? ?? '🎯', style: const TextStyle(fontSize: 20)),
              const SizedBox(width: NBSpacing.s),
              Expanded(child: Text(widget.conta['nome'] as String? ?? '', style: NBText.rotulo)),
              Text('${brl(_saldo)} de ${brl(_meta)}', style: NBText.legenda),
            ],
          ),
          const SizedBox(height: NBSpacing.s),
          BarraProgresso(fracao: fracao, cor: fracao >= 0.9 ? NBColors.verde : NBColors.reserva),
          if (meses != 0) ...[
            const SizedBox(height: NBSpacing.m),
            Row(
              children: [
                Expanded(child: Text('Aporte mensal', style: NBText.legenda)),
                Text(brl(_aporte), style: NBText.rotulo.copyWith(color: NBColors.reserva)),
              ],
            ),
            Slider(
              value: _aporte.clamp(0, _max),
              min: 0,
              max: _max,
              divisions: (_max / 50).round(),
              onChanged: (v) => setState(() => _aporte = v),
            ),
          ],
          Row(
            children: [
              const Text('📅 ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Text(
                  textoPrazo(meses) + (chegada == null ? '' : ' · ${nomesMes[chegada.month - 1]}/${chegada.year}'),
                  style: NBText.rotulo.copyWith(color: meses == 0 ? NBColors.verde : NBColors.tinta),
                ),
              ),
            ],
          ),
          if (meses != null && meses > 0 && (semAporte == null || semAporte > meses) && _aporte > 0)
            Text(
              semAporte == null
                  ? 'Só com o rendimento a meta não chega. O aporte faz a diferença.'
                  : 'Aportando ${brl(_aporte)}/mês você chega ${semAporte - meses} meses antes.',
              style: NBText.legenda.copyWith(color: NBColors.verde),
            ),
        ],
      ),
    );
  }
}
