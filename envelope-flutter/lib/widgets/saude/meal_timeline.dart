import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Linha do tempo horizontal de refeições entre 06h e 22h.
class MealTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> refeicoes;

  const MealTimeline({super.key, required this.refeicoes});

  static const int _startH = 6;
  static const int _endH = 22;
  static const double _totalMinutes = (_endH - _startH) * 60;

  static const Map<String, String> _tipoEmoji = {
    'cafe_da_manha': '☕',
    'lanche_manha': '🍎',
    'almoco': '🍽',
    'lanche_tarde': '🍪',
    'jantar': '🌙',
    'ceia': '🌛',
  };

  double _posicao(String? horario) {
    if (horario == null) return 0.5;
    try {
      final parts = horario.split(':');
      final h = int.parse(parts[0]);
      final m = parts.length > 1 ? int.parse(parts[1]) : 0;
      final totalMin = (h - _startH) * 60 + m;
      return (totalMin / _totalMinutes).clamp(0.0, 1.0);
    } catch (_) {
      return 0.5;
    }
  }

  @override
  Widget build(BuildContext context) {
    final agora = TimeOfDay.now();
    final minutosAgora = (agora.hour - _startH) * 60 + agora.minute;
    final posAgora = (minutosAgora / _totalMinutes).clamp(0.0, 1.0);

    final validas = refeicoes
        .where((r) => r['deleted_at'] == null && r['is_jejum'] != true)
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LINHA DO TEMPO',
            style: TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (_, constraints) {
              final w = constraints.maxWidth;
              return SizedBox(
                height: 40,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // trilho
                    Positioned(
                      left: 0, right: 0,
                      top: 18,
                      child: Container(height: 2, color: AppColors.bord),
                    ),
                    // hora atual
                    if (agora.hour >= _startH && agora.hour <= _endH)
                      Positioned(
                        left: posAgora * w - 1,
                        top: 10,
                        child: Container(width: 2, height: 18, color: AppColors.grn.withOpacity(0.7)),
                      ),
                    // labels 06h / 10h / 14h / 18h / 22h
                    ...const [0.0, 0.25, 0.5, 0.75, 1.0].asMap().entries.map((e) {
                      final h = _startH + (e.value * (_endH - _startH)).round();
                      return Positioned(
                        left: (e.value * w - 10).clamp(0.0, w - 20),
                        bottom: 0,
                        child: Text('${h}h', style: const TextStyle(fontSize: 9, color: AppColors.mu)),
                      );
                    }),
                    // marcadores de refeições
                    ...validas.map((r) {
                      final horario = r['horario'] as String?
                          ?? (r['registrado_em'] as String?)?.substring(11, 16);
                      final pos = _posicao(horario);
                      final emoji = _tipoEmoji[r['tipo_refeicao'] as String? ?? ''] ?? '🍴';
                      return Positioned(
                        left: (pos * w - 10).clamp(0.0, w - 20),
                        top: 0,
                        child: Text(emoji, style: const TextStyle(fontSize: 18)),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
