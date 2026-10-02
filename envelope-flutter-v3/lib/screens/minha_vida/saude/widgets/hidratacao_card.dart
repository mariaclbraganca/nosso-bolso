import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nosso_bolso_v3/core/providers/saude_provider.dart';
import 'package:nosso_bolso_v3/core/services/saude_api_service.dart';
import 'package:nosso_bolso_v3/screens/sheets/comum.dart';
import 'package:nosso_bolso_v3/ui/components/nb_components.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

class HidratacaoCard extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;
  final String data;

  const HidratacaoCard({
    super.key,
    required this.membroId,
    required this.familiaId,
    required this.data,
  });

  @override
  ConsumerState<HidratacaoCard> createState() => _HidratacaoCardState();
}

class _HidratacaoCardState extends ConsumerState<HidratacaoCard> {
  bool _salvando = false;

  Future<void> _adicionarAgua(int ml) async {
    if (_salvando) return;
    setState(() => _salvando = true);
    try {
      await SaudeApiService.registrarHidratacao(
        widget.membroId,
        widget.familiaId,
        volumeMl: ml,
        data: widget.data,
      );
      ref.invalidate(hidratacaoDiaProvider);
      ref.invalidate(extratoDiarioProvider);
      if (mounted) {
        avisar('💧 +${ml}ml de água registrados!');
      }
    } catch (e) {
      if (mounted) avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = (membroId: widget.membroId, data: widget.data);
    final hidraAsync = ref.watch(hidratacaoDiaProvider(args));

    final totalMl = hidraAsync.asData?.value['total_ml'] as int? ?? 0;
    final metaMl = hidraAsync.asData?.value['meta_ml'] as int? ?? 2000;
    final pct = (totalMl / (metaMl > 0 ? metaMl : 2000)).clamp(0.0, 1.0);

    return CartaoNB(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💧', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Hidratação do Dia', style: NBText.secao),
              ),
              Text(
                '$totalMl / ${metaMl}ml',
                style: NBText.corpo.copyWith(
                  fontWeight: FontWeight.bold,
                  color: NBColors.reserva,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: NBColors.afundado,
              valueColor: const AlwaysStoppedAnimation<Color>(NBColors.reserva),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _salvando ? null : () => _adicionarAgua(250),
                  icon: const Icon(Icons.local_drink_rounded, size: 16),
                  label: const Text('+250 ml'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NBColors.reserva,
                    side: const BorderSide(color: NBColors.reserva),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _salvando ? null : () => _adicionarAgua(500),
                  icon: const Icon(Icons.water_drop_rounded, size: 16),
                  label: const Text('+500 ml'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NBColors.reserva,
                    side: const BorderSide(color: NBColors.reserva),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
