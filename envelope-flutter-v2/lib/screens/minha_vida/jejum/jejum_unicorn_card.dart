import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/jejum_provider.dart';
import '../../../widgets/unicorn/unicorn_system.dart';

/// Card sempre presente no módulo Jejum: Sweet ou Happy com mensagem IA
/// (insight, carinho ou fato curioso sobre o momento do jejum).
/// REGRA: Geronimo e Astrix NUNCA aparecem aqui.
class JejumUnicornCard extends ConsumerWidget {
  final String membroId;

  const JejumUnicornCard({super.key, required this.membroId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(jejumInsightsProvider(membroId));
    final ativoAsync = ref.watch(jejumAtivoProvider(membroId));

    // Mensagem contextual: prioriza fase atual durante jejum ativo
    String texto;
    UnicornType tipo = UnicornType.happy;

    final ativo = ativoAsync.asData?.value;
    final insights = insightsAsync.asData?.value;

    if (ativo != null) {
      final inicio = DateTime.tryParse(ativo['iniciado_em'] ?? '')?.toLocal();
      final decorrido =
          inicio != null ? DateTime.now().difference(inicio) : Duration.zero;
      final fase = FaseMetabolica.atual(decorrido);
      texto = _mensagemFase(fase, decorrido);
      if (decorrido.inHours >= 12) tipo = UnicornType.sweet;
    } else if (insights?['mensagem_unicornio'] != null) {
      final msg = insights!['mensagem_unicornio'] as Map<String, dynamic>;
      texto = msg['texto'] as String? ?? _fallback;
      tipo = (msg['unicornio'] == 'sweet') ? UnicornType.sweet : UnicornType.happy;
    } else {
      texto = _fallback;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.pur.withOpacity(0.25), width: 0.8),
      ),
      child: Row(
        children: [
          UnicornWidget(type: tipo, size: 80),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: AppTextStyles.bodySm.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  static const _fallback =
      'Estou aqui com você! Qualquer hora que quiser começar, é só tocar em Iniciar. 🦄';

  String _mensagemFase(FaseMetabolica fase, Duration d) {
    final h = d.inHours;
    switch (fase.nome) {
      case 'Digestão':
        return 'Seu corpo ainda está digerindo. Beba água e relaxa — o processo já começou! 💧';
      case 'Glicose em queda':
        return '${h}h! A glicose está baixando e seu corpo se prepara para queimar gordura. Você está indo lindo! ${fase.emoji}';
      case 'Queima de gordura':
        return '${h}h de jejum! Agora é oficial: seu corpo está queimando gordura como fonte de energia. 🔥';
      case 'Cetose leve':
        return '${h}h — cetose leve! Muita gente sente clareza mental agora. Aproveita essa energia! ⚡';
      case 'Autofagia':
        return '${h}h! Autofagia ativada: suas células estão se renovando. Isso é autocuidado de verdade. ✨';
      default:
        return '${h}h — autofagia profunda! Você chegou longe demais. Orgulho define! 🌙';
    }
  }
}
