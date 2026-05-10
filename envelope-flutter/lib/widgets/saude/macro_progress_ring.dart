import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class MacroProgressRing extends StatelessWidget {
  final double consumido;
  final double meta;
  final double size;

  const MacroProgressRing({
    super.key,
    required this.consumido,
    required this.meta,
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    final pct = meta > 0 ? (consumido / meta).clamp(0.0, 1.0) : 0.0;
    final sobrou = (meta - consumido).clamp(0, double.infinity);
    final isOver = consumido > meta;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(pct: pct, isOver: isOver),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${consumido.toInt()}',
                style: TextStyle(
                  fontSize: size * 0.18,
                  fontWeight: FontWeight.bold,
                  color: isOver ? AppColors.red : AppColors.tx,
                ),
              ),
              Text(
                'kcal',
                style: TextStyle(fontSize: size * 0.09, color: AppColors.mu),
              ),
              const SizedBox(height: 2),
              Text(
                isOver
                    ? '+${(consumido - meta).toInt()} acima'
                    : '${sobrou.toInt()} restam',
                style: TextStyle(
                  fontSize: size * 0.075,
                  color: isOver ? AppColors.red : AppColors.mu,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  final bool isOver;

  _RingPainter({required this.pct, required this.isOver});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;

    final bgPaint = Paint()
      ..color = AppColors.bord
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), radius, bgPaint);

    final fgPaint = Paint()
      ..color = isOver ? AppColors.red : AppColors.acc
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      -pi / 2,
      2 * pi * pct,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.pct != pct || old.isOver != isOver;
}
