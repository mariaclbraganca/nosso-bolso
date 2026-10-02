import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';

/// Card interativo para simular tempo restante da meta com slider de aporte
class MetaCard extends StatefulWidget {
  final Map<String, dynamic> conta;
  final double saldoLivreDisponivel;
  const MetaCard({super.key, required this.conta, required this.saldoLivreDisponivel});

  @override
  State<MetaCard> createState() => _MetaCardState();
}

class _MetaCardState extends State<MetaCard> {
  late double _aporte;
  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _aporte = (widget.saldoLivreDisponivel * 0.2).clamp(50.0, 5000.0);
  }

  double get _saldo => (widget.conta['saldo_atual'] as num?)?.toDouble() ?? 0;
  double get _meta => (widget.conta['meta_saldo'] as num?)?.toDouble() ?? 0;
  double get _rendMensal => (widget.conta['rendimento_mensal'] as num?)?.toDouble() ?? 0;
  double get _progresso => _meta > 0 ? (_saldo / _meta).clamp(0.0, 1.0) : 0;
  double get _falta => (_meta - _saldo).clamp(0.0, double.infinity);

  int _calcularMeses(double aporte) {
    if (_falta <= 0) return 0;
    if (aporte <= 0 && _rendMensal <= 0) return 9999;
    double saldo = _saldo;
    final r = _rendMensal / 100;
    for (var i = 1; i <= 600; i++) {
      saldo = saldo * (1 + r) + aporte;
      if (saldo >= _meta) return i;
    }
    return 9999;
  }

  String _formatarPrazo(int meses) {
    if (meses == 0) return 'Meta atingida! 🎉';
    if (meses >= 9999) return 'Nunca (aporte insuficiente)';
    if (meses < 12) return '$meses ${meses == 1 ? 'mês' : 'meses'}';
    final anos = meses ~/ 12;
    final resto = meses % 12;
    if (resto == 0) return '$anos ${anos == 1 ? 'ano' : 'anos'}';
    return '$anos ${anos == 1 ? 'ano' : 'anos'} e $resto ${resto == 1 ? 'mês' : 'meses'}';
  }

  DateTime? _dataChegada(int meses) {
    if (meses <= 0 || meses >= 9999) return null;
    final now = DateTime.now();
    var mes = now.month + meses;
    var ano = now.year + (mes - 1) ~/ 12;
    mes = ((mes - 1) % 12) + 1;
    return DateTime(ano, mes);
  }

  @override
  Widget build(BuildContext context) {
    final nome = widget.conta['nome'] as String? ?? '';
    final emoji = widget.conta['emoji'] as String? ?? '🎯';
    final mesesAtual = _calcularMeses(_aporte);
    final dataChegada = _dataChegada(mesesAtual);
    final mesesSemAporte = _calcularMeses(0);
    final ganhoEmMeses = mesesSemAporte - mesesAtual;
    final corProgresso = _progresso >= 0.9 ? AppColors.grn : _progresso >= 0.5 ? AppColors.acc : AppColors.gold;
    final maxSlider = (widget.saldoLivreDisponivel * 0.8).clamp(200.0, 10000.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nome, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                Text('${(_progresso * 100).toStringAsFixed(0)}% da meta', style: AppTextStyles.caption.copyWith(color: corProgresso)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmt.format(_saldo), style: AppTextStyles.monoSm.copyWith(color: AppColors.tx)),
              Text('de ${_fmt.format(_meta)}', style: AppTextStyles.caption.copyWith(fontSize: 10)),
            ]),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: _progresso, backgroundColor: AppColors.bord, color: corProgresso, minHeight: 6),
          ),
          if (_falta > 0) ...[
            const SizedBox(height: 16),
            _buildPrazoEstimado(mesesAtual, dataChegada, ganhoEmMeses),
            const SizedBox(height: 14),
            _buildSliderAporte(maxSlider),
          ] else ...[
            const SizedBox(height: 10),
            _buildMetaAtingida(),
          ],
        ],
      ),
    );
  }

  Widget _buildPrazoEstimado(int mesesAtual, DateTime? dataChegada, int ganhoEmMeses) {
    const meses = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.acc.withOpacity(0.07),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.acc.withOpacity(0.15)),
      ),
      child: Row(children: [
        const Text('📅', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_formatarPrazo(mesesAtual), style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.acc)),
            if (dataChegada != null)
              Text('Chegada em ${meses[dataChegada.month - 1]}/${dataChegada.year}', style: AppTextStyles.caption),
            if (ganhoEmMeses > 0 && _aporte > 0)
              Text('Aportando ${_fmt.format(_aporte)}/mês economiza $ganhoEmMeses ${ganhoEmMeses == 1 ? 'mês' : 'meses'}', style: AppTextStyles.caption.copyWith(color: AppColors.grn, height: 1.4)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Faltam', style: AppTextStyles.caption),
          Text(_fmt.format(_falta), style: AppTextStyles.monoSm.copyWith(color: AppColors.org)),
        ]),
      ]),
    );
  }

  Widget _buildSliderAporte(double maxSlider) {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Aporte mensal', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
          Text(_fmt.format(_aporte), style: AppTextStyles.monoSm.copyWith(color: AppColors.acc, fontSize: 14)),
        ]),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.acc,
            inactiveTrackColor: AppColors.bord,
            thumbColor: AppColors.acc,
            overlayColor: AppColors.acc.withOpacity(0.12),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: _aporte.clamp(0, maxSlider),
            min: 0,
            max: maxSlider,
            divisions: 40,
            onChanged: (v) => setState(() => _aporte = v),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('R\$ 0', style: AppTextStyles.caption.copyWith(fontSize: 9)),
          Text('Saldo livre: ${_fmt.format(widget.saldoLivreDisponivel)}', style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.mu)),
        ]),
      ],
    );
  }

  Widget _buildMetaAtingida() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: AppColors.grn.withOpacity(0.1), borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
      child: Text('🎉 Meta atingida!', style: AppTextStyles.body.copyWith(color: AppColors.grn, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
    );
  }
}
