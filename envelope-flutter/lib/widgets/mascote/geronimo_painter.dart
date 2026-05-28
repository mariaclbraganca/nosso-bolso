import 'dart:math';
import 'package:flutter/material.dart';
import '../../providers/unicorn_team.dart';

/// Geronimo 🌀 — wild, chaotic, unpredictable.
/// Orange body, asymmetric swirly eyes, bent rainbow horn, spiky 6-color mane.
class GeronimoUnicornPainter extends CustomPainter {
  final UnicornMood mood;
  final double t;
  final double blink;
  final double tailWag;
  final double sparkle;

  static const _body  = Color(0xFFFFF3E0);
  static const _line  = Color(0xFFFF6D00);
  static const _m1    = Color(0xFFFF1744);
  static const _m2    = Color(0xFFFF6D00);
  static const _m3    = Color(0xFFFFEA00);
  static const _m4    = Color(0xFF00E676);
  static const _m5    = Color(0xFF2979FF);
  static const _m6    = Color(0xFFD500F9);
  static const _iris  = Color(0xFF1A0A00);
  static const _blush = Color(0xFFFF6D00);
  static const _hoof  = Color(0xFFE65100);

  GeronimoUnicornPainter({
    required this.mood,
    required this.t,
    required this.blink,
    required this.tailWag,
    required this.sparkle,
  });

  Paint _f(Color c) => Paint()..color = c..style = PaintingStyle.fill;
  Paint _s(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120.0, size.height / 140.0);
    canvas.translate(60, 82);

    // Chaotic multi-frequency bounce
    double dy = 0;
    if (mood == UnicornMood.idle || mood == UnicornMood.chaos) {
      dy = sin(t * 2 * pi) * 3.5 + sin(t * 3.7 * pi + 0.4) * 1.5;
    }
    double sc = 1.0;
    if (mood == UnicornMood.celebrate || mood == UnicornMood.chaos) {
      sc = 1.0 + sin(t * 5 * pi) * 0.065 + sin(t * 7.3 * pi) * 0.02;
    }
    // Subtle body tilt for chaos mode
    final tilt = (mood == UnicornMood.chaos || mood == UnicornMood.celebrate)
        ? sin(t * 2 * pi + 0.8) * 0.07
        : 0.0;
    if (mood == UnicornMood.sad) dy = t * 4.0;

    canvas.translate(0, dy);
    canvas.scale(sc, sc);
    canvas.rotate(tilt);

    _drawTail(canvas);
    _drawBackLegs(canvas);
    _drawBody(canvas);
    _drawNeck(canvas);
    _drawFrontLegs(canvas);
    _drawHead(canvas);
    _drawMane(canvas);
    _drawHorn(canvas);
    _drawEyes(canvas);
    _drawFace(canvas);

    if ((mood == UnicornMood.celebrate || mood == UnicornMood.chaos) && sparkle > 0.05) {
      _drawConfettiSparkles(canvas);
    }

    canvas.restore();
  }

  void _drawBody(Canvas canvas) {
    final r = Rect.fromCenter(center: const Offset(0, 18), width: 58, height: 38);
    canvas.drawOval(r, _f(_body));
    canvas.drawOval(r, _s(_line, 0.9));
  }

  void _drawNeck(Canvas canvas) {
    final path = Path()
      ..moveTo(-4, -2)
      ..quadraticBezierTo(-6, 8, -4, 16)
      ..lineTo(12, 16)
      ..quadraticBezierTo(14, 8, 14, -2)
      ..close();
    canvas.drawPath(path, _f(_body));
    canvas.drawPath(path, _s(_line, 0.7));
  }

  void _drawHead(Canvas canvas) {
    canvas.drawCircle(const Offset(18, -16), 21, _f(_body));
    canvas.drawCircle(const Offset(18, -16), 21, _s(_line, 0.9));
    final snout = Rect.fromCenter(center: const Offset(33, -9), width: 16, height: 12);
    canvas.drawOval(snout, _f(_body));
    canvas.drawOval(snout, _s(_line, 0.7));
  }

  void _drawHorn(Canvas canvas) {
    // Bent / crooked horn — definitely not straight
    final path = Path()
      ..moveTo(9, -34)
      ..lineTo(7, -34)
      ..cubicTo(2, -48, 10, -60, 14, -66)
      ..cubicTo(20, -68, 26, -60, 25, -50)
      ..cubicTo(28, -42, 24, -34, 22, -34)
      ..close();

    final shader = SweepGradient(
      colors: [_m1, _m2, _m3, _m4, _m5, _m6, _m1],
      stops: const [0.0, 0.17, 0.34, 0.51, 0.67, 0.84, 1.0],
    ).createShader(const Rect.fromLTWH(0, -70, 30, 40));

    canvas.drawPath(path, Paint()..shader = shader..style = PaintingStyle.fill);

    if (mood == UnicornMood.chaos || mood == UnicornMood.celebrate) {
      canvas.drawCircle(
        const Offset(16, -52),
        12,
        Paint()
          ..color = _m3.withOpacity(sparkle * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  void _drawMane(Canvas canvas) {
    // WILD spiky rainbow mane — 6 colors, maximum chaos
    final maneColors = [_m1, _m2, _m3, _m4, _m5, _m6];
    for (int i = 0; i < 6; i++) {
      final color  = maneColors[i];
      final ox     = (i - 2.5) * 1.5;
      final oy     = i * 0.7;
      final wobble = sin(t * 2 * pi + i * 1.4) *
          (mood == UnicornMood.chaos ? 3.0 : 1.2);
      final path = Path()
        ..moveTo(9 + ox, -33 + oy)
        ..cubicTo(
          -2 + ox + wobble, -20 + oy,
          -10 + ox - wobble, 2 + oy,
          -5 + ox + wobble * 0.5, 15 + oy,
        )
        ..lineTo(-3 + ox - wobble, 5 + oy)
        ..cubicTo(
          1 + ox, -10 + oy,
          9 + ox + wobble, -22 + oy,
          13 + ox, -30 + oy,
        )
        ..close();
      canvas.drawPath(path, _f(color));
    }
  }

  void _drawTail(Canvas canvas) {
    final wag = tailWag * 20; // extra waggy
    final tailColors = [_m1, _m2, _m3, _m4];
    for (int i = 0; i < 4; i++) {
      final color = tailColors[i];
      final oy    = i * 2.0;
      final path  = Path()
        ..moveTo(-26, 12 + oy)
        ..cubicTo(-42, 22 + oy, -50 + wag, 38 + oy, -40 + wag, 54 + oy);
      canvas.drawPath(path, _s(color, 4.5 - i * 0.5));
    }
  }

  void _drawBackLegs(Canvas canvas) {
    _drawLeg(canvas, -22, 30);
    _drawLeg(canvas, -10, 30);
  }

  void _drawFrontLegs(Canvas canvas) {
    final waveAngle = (mood == UnicornMood.wave || mood == UnicornMood.chaos)
        ? -sin(t * 2 * pi) * 0.7
        : 0.0;
    final waveAngle2 = mood == UnicornMood.chaos
        ? sin(t * 3 * pi + 1.2) * 0.4
        : 0.0;
    canvas.save();
    canvas.translate(14, 30);
    canvas.rotate(waveAngle);
    _legAt(canvas, -5, 0);
    canvas.restore();
    canvas.save();
    canvas.translate(4, 30);
    canvas.rotate(waveAngle2);
    _legAt(canvas, 0, 0);
    canvas.restore();
  }

  void _drawLeg(Canvas canvas, double x, double y) {
    canvas.save();
    canvas.translate(x, y);
    _legAt(canvas, 0, 0);
    canvas.restore();
  }

  void _legAt(Canvas canvas, double x, double y) {
    final leg = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 11, 24), const Radius.circular(5));
    canvas.drawRRect(leg, _f(_body));
    canvas.drawRRect(leg, _s(_line, 0.8));
    final hoof = RRect.fromRectAndRadius(Rect.fromLTWH(x, y + 18, 11, 8), const Radius.circular(4));
    canvas.drawRRect(hoof, _f(_hoof));
  }

  void _drawEyes(Canvas canvas) {
    final openFrac = (1.0 - blink).clamp(0.05, 1.0);

    // LEFT eye: smaller and squintier
    final hL = 7.0 * openFrac;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(9, -21), width: 9, height: hL),
      _f(Colors.white),
    );
    if (hL > 1.5) {
      canvas.drawCircle(const Offset(9, -21), hL * 0.38, _f(_iris));
      _drawSwirl(canvas, const Offset(9, -21), hL * 0.28, t);
    }

    // RIGHT eye: bigger, wild
    final hR = 12.0 * openFrac;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(20, -18), width: 14, height: hR),
      _f(Colors.white),
    );
    if (hR > 2.0) {
      canvas.drawCircle(const Offset(20.5, -17.5), hR * 0.38, _f(_iris));
      _drawSwirl(canvas, const Offset(20.5, -17.5), hR * 0.3, t * 1.3);
      canvas.drawCircle(const Offset(22, -19), 1.5, _f(Colors.white));
    }

    // Uneven scattered lashes
    final lash = _s(_iris.withOpacity(0.7), 1.1);
    canvas.drawLine(const Offset(6, -26),  const Offset(5, -30),   lash);
    canvas.drawLine(const Offset(9, -27),  const Offset(9, -31),   lash);
    canvas.drawLine(const Offset(16, -25), const Offset(14, -29),  lash);
    canvas.drawLine(const Offset(19, -26), const Offset(19, -30),  lash);
    canvas.drawLine(const Offset(22, -25), const Offset(24, -28),  lash);
    canvas.drawLine(const Offset(25, -23), const Offset(27, -26),  lash);
  }

  void _drawSwirl(Canvas canvas, Offset center, double r, double phase) {
    final path = Path();
    for (int i = 0; i <= 14; i++) {
      final angle = (i / 14.0) * 2 * pi + phase * pi;
      final rad   = r * (1.0 - i / 16.0);
      final x     = center.dx + cos(angle) * rad;
      final y     = center.dy + sin(angle) * rad;
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, _s(Colors.white.withOpacity(0.65), 0.9));
  }

  void _drawFace(Canvas canvas) {
    final blush = Paint()..color = _blush.withOpacity(0.28)..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromCenter(center: const Offset(7, -9), width: 11, height: 7), blush);
    canvas.drawOval(Rect.fromCenter(center: const Offset(30, -10), width: 10, height: 6), blush);

    canvas.drawCircle(const Offset(33, -5), 1.3, _f(_line));

    // Wild uneven grin
    final mouth = Path()
      ..moveTo(26, -5)
      ..quadraticBezierTo(30, -0, 36, -4);
    canvas.drawPath(mouth, _s(_iris.withOpacity(0.45), 1.6));

    if (mood == UnicornMood.chaos || mood == UnicornMood.celebrate) {
      // Extra squiggle above the mouth — pure chaos energy
      final squiggle = Path()
        ..moveTo(27, -7)
        ..cubicTo(29, -9, 31, -5, 33, -7)
        ..cubicTo(35, -9, 36, -6, 37, -7);
      canvas.drawPath(squiggle, _s(_m2.withOpacity(0.4), 1.0));
    }

    if (mood == UnicornMood.thinking) {
      final dotPaint = _f(_m5.withOpacity(0.7 + sin(t * 2 * pi) * 0.3));
      for (int i = 0; i < 3; i++) {
        final delay = (t - i * 0.15).clamp(0.0, 1.0);
        final dotY  = -46.0 - sin(delay * pi) * 5;
        canvas.drawCircle(Offset(-8.0 + i * 6, dotY), 2.2, dotPaint);
      }
    }
  }

  void _drawConfettiSparkles(Canvas canvas) {
    final confettiColors = [_m1, _m2, _m3, _m4, _m5, _m6];
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8.0) * 2 * pi + t * 2.2 * pi;
      final dist  = 38.0 + sin(t * 2 * pi + i * 0.7) * 10;
      final cx    = cos(angle) * dist;
      final cy    = sin(angle) * dist - 14;
      final w     = 4.0 + sin(t * pi + i * 1.3) * 2.0;
      final rot   = t * 6 * pi + i * 0.7;
      final color = confettiColors[i % confettiColors.length];
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: w, height: 2.0),
        _f(color.withOpacity(sparkle * 0.9)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(GeronimoUnicornPainter oldDelegate) =>
      oldDelegate.mood != mood || oldDelegate.t != t || oldDelegate.blink != blink ||
      oldDelegate.tailWag != tailWag || oldDelegate.sparkle != sparkle;
}
