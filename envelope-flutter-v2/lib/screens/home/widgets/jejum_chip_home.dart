import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/jejum_provider.dart';
import '../../minha_vida/jejum/jejum_timer_screen.dart';

class JejumChipHome extends ConsumerWidget {
  final String membroId;
  final String familiaId;

  const JejumChipHome({
    super.key,
    required this.membroId,
    required this.familiaId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ativoAsync = ref.watch(jejumAtivoProvider(membroId));

    return ativoAsync.when(
      data: (registro) {
        if (registro == null) return const SizedBox.shrink();

        final inicioStr = registro['iniciado_em'] as String?;
        if (inicioStr == null) return const SizedBox.shrink();

        final inicio = DateTime.tryParse(inicioStr)?.toLocal();
        if (inicio == null) return const SizedBox.shrink();

        final decorrido = DateTime.now().difference(inicio);
        final fase = FaseMetabolica.atual(decorrido);

        final horas = decorrido.inHours;
        final minutos = decorrido.inMinutes.remainder(60);
        final tempoDecorrido =
            '${horas}h ${minutos.toString().padLeft(2, '0')}min';

        final metaHoras = (registro['meta_horas'] as num?)?.toDouble();
        String subtexto;
        if (metaHoras != null) {
          final metaDuration = Duration(
              minutes: (metaHoras * 60).round());
          final restante = metaDuration - decorrido;
          if (restante.isNegative) {
            subtexto = 'Fase: ${fase.nome} · Meta atingida!';
          } else {
            final hr = restante.inHours;
            final mn = restante.inMinutes.remainder(60);
            subtexto =
                'Fase: ${fase.nome} · ${hr}h ${mn.toString().padLeft(2, '0')}min restante';
          }
        } else {
          subtexto = 'Fase: ${fase.nome}';
        }

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JejumTimerScreen(
                membroId: membroId,
                familiaId: familiaId,
                registroInicial: registro,
              ),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(
                AppSpacing.pagePad, 0, AppSpacing.pagePad, AppSpacing.cardGap),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.acc.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.acc.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jejum ativo · $tempoDecorrido',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.acc,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtexto,
                        style:
                            AppTextStyles.caption.copyWith(color: AppColors.mu),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppColors.mu, size: 14),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
