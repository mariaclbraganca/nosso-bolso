import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../services/jejum_api_service.dart';

/// Sheet do protocolo Personalizado: duração da meta + modalidade.
/// Modalidades: Com meta (timer com alvo) ou Livre (cronômetro aberto).
class JejumPersonalizadoSheet extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;

  const JejumPersonalizadoSheet({
    super.key,
    required this.membroId,
    required this.familiaId,
  });

  @override
  ConsumerState<JejumPersonalizadoSheet> createState() =>
      _JejumPersonalizadoSheetState();
}

class _JejumPersonalizadoSheetState
    extends ConsumerState<JejumPersonalizadoSheet> {
  String _modalidade = 'com_meta';
  double _horas = 14;
  bool _salvando = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.bord,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Jejum personalizado',
              style: AppTextStyles.title.copyWith(fontSize: 18)),
          const SizedBox(height: 20),

          // ── Modalidade ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _cardModalidade(
                  'com_meta', '🎯', 'Com meta',
                  'Você define quantas horas quer alcançar',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _cardModalidade(
                  'livre', '🕊️', 'Livre',
                  'Cronômetro aberto — finalize quando sentir',
                ),
              ),
            ],
          ),

          // ── Duração (só com meta) ─────────────────────────────────
          if (_modalidade == 'com_meta') ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Duração da meta', style: AppTextStyles.bodySm),
                Text(
                  '${_horas.toStringAsFixed(_horas.truncateToDouble() == _horas ? 0 : 1)}h',
                  style: AppTextStyles.mono.copyWith(color: AppColors.pur),
                ),
              ],
            ),
            Slider(
              value: _horas,
              min: 10,
              max: 36,
              divisions: 52,
              activeColor: AppColors.pur,
              inactiveColor: AppColors.bord,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _horas = v);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('10h', style: AppTextStyles.caption),
                Text('36h', style: AppTextStyles.caption),
              ],
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _salvando ? null : _salvar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pur,
                foregroundColor: AppColors.bg,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                ),
              ),
              child: _salvando
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.bg,
                      ),
                    )
                  : const Text('Salvar protocolo',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardModalidade(
      String valor, String emoji, String titulo, String descricao) {
    final selecionado = _modalidade == valor;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _modalidade = valor);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selecionado ? AppColors.pur.withOpacity(0.1) : AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
          border: Border.all(
            color: selecionado ? AppColors.pur.withOpacity(0.6) : AppColors.bord,
            width: selecionado ? 1.2 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(titulo,
                style: AppTextStyles.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selecionado ? AppColors.pur : AppColors.tx,
                )),
            const SizedBox(height: 4),
            Text(descricao,
                textAlign: TextAlign.center, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await JejumApiService.salvarConfig(widget.membroId, {
        'familia_id': widget.familiaId,
        'protocolo': 'personalizado',
        'modalidade': _modalidade,
        if (_modalidade == 'com_meta') 'duracao_horas': _horas,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }
}
