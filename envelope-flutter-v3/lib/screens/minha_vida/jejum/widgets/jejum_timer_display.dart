import 'package:flutter/material.dart';
import 'package:nosso_bolso_v3/core/providers/jejum_provider.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

class JejumTimerDisplay extends StatelessWidget {
  final Duration decorrido;
  final double metaHoras;
  final bool ativo;

  const JejumTimerDisplay({
    super.key,
    required this.decorrido,
    required this.metaHoras,
    required this.ativo,
  });

  @override
  Widget build(BuildContext context) {
    final metaSegundos = (metaHoras * 3600).clamp(1, 86400 * 3);
    final progresso = ativo
        ? (decorrido.inSeconds / metaSegundos).clamp(0.0, 1.0)
        : 0.0;

    final horas = decorrido.inHours.toString().padLeft(2, '0');
    final minutos = (decorrido.inMinutes % 60).toString().padLeft(2, '0');
    final segundos = (decorrido.inSeconds % 60).toString().padLeft(2, '0');

    final fase = FaseMetabolica.atual(decorrido);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: progresso,
              strokeWidth: 12,
              backgroundColor: NBColors.afundado,
              valueColor: AlwaysStoppedAnimation<Color>(
                ativo ? NBColors.lavanda : NBColors.tintaSuave,
              ),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ativo) ...[
                Text(
                  '${fase.emoji} ${fase.nome}',
                  style: NBText.legenda.copyWith(
                    color: NBColors.lavanda,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$horas:$minutos:$segundos',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                    color: NBColors.tinta,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Meta: ${metaHoras.toInt()}h',
                  style: NBText.legenda,
                ),
              ] else ...[
                const Text('⏱️', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text('Pronto para iniciar?', style: NBText.secao),
                const SizedBox(height: 4),
                Text(
                  'Meta: ${metaHoras.toInt()}h',
                  style: NBText.legenda,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
