import 'dart:math';
import 'package:flutter/material.dart';
import '../../providers/unicorn_team.dart';

/// Happy ⭐ — focused, concentrated, analytical.
/// Pale yellow body, squinted determined eyes, straight tall lightning horn, sleek gold mane.
class HappyPainter extends CustomPainter {
  final UnicornMood mood;
  final double t;
  final double blink;
  final double tailWag;
  final double sparkle;

  static const _body  = Color(0xFFFFFDE7);
  static const _line  = Color(0xFFFFCA28);
  static const _maneA = Color(0xFFFFCA28);
  static const _maneB = Color(0xFFFF8F00);
  static const _maneC = Color(0xFFFFF9C4);
  static const _gold1 = Color(0xFFFFCA28);
  static const _gold2 = Color(0xFFFF8F00);
  static const _iris  = Color(0xFF3E2000);
  static const _blush = Color(0xFFFFB300);
  static const _hoof  = Color(0xFFE6B800);

  HappyPainter({
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

    double dy = 0;
    if (mood == UnicornMood.idle || mood == UnicornMood.focus) {
      dy = sin(t * 2 * pi) * 1.5; // tight controlled bob
    }
    double sc = 1.0;
    if (mood == UnicornMood.celebrate) {
      sc = 1.0 + sin(t * 4 * pi) * 0.045; // fast energetic pulse
    }
    if (mood == UnicornMood.sad) dy = t * 4.0;

    canvas.translate(0, dy);
    canvas.scale(sc, sc);

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

    if ((mood == UnicornMood.celebrate || mood == UnicornMood.focus) && sparkle > 0.05) {
      _drawLightningSparkles(canvas);
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
    // Straight tall horn — precise and powerful
    final path = Path()
      ..moveTo(12, -34)
      ..lineTo(9, -34)
      ..lineTo(18, -74)
      ..lineTo(27, -34)
      ..close();

    final shader = LinearGradient(
      colors: [_gold1, _gold2],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(const Rect.fromLTWH(8, -76, 22, 44));

    canvas.drawPath(path, Paint()..shader = shader..style = PaintingStyle.fill);

    // Shine line
    final shine = Path()
      ..moveTo(13, -36)
      ..lineTo(17, -68);
    canvas.drawPath(shine, _s(Colors.white.withOpacity(0.5), 1.2));

    // Lightning bolt decorations on the side of the horn
    _drawLightningBolt(canvas, const Offset(9, -52), 7.0, Colors.white.withOpacity(0.75));
    _drawLightningBolt(canvas, const Offset(26, -44), 5.5, _gold1.withOpacity(0.6));

    if (mood == UnicornMood.celebrate || mood == UnicornMood.focus) {
      canvas.drawCircle(
        const Offset(18, -54),
        14,
        Paint()
          ..color = _gold1.withOpacity(sparkle * 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
  }

  void _drawLightningBolt(Canvas canvas, Offset c, double s, Color color) {
    final path = Path()
      ..moveTo(c.dx + s * 0.2,  c.dy - s * 0.5)
      ..lineTo(c.dx - s * 0.1,  c.dy)
      ..lineTo(c.dx + s * 0.15, c.dy)
      ..lineTo(c.dx - s * 0.2,  c.dy + s * 0.5)
      ..lineTo(c.dx + s * 0.1,  c.dy - s * 0.05)
      ..lineTo(c.dx - s * 0.15, c.dy - s * 0.05)
      ..close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  void _drawMane(Canvas canvas) {
    // Sleek, aerodynamic mane — no fluff, all efficiency
    for (final (color, ox, oy) in [
      (_maneA, 0.0, 2.0),
      (_maneB, 3.0, 0.0),
      (_maneC, -2.5, -1.0),
    ]) {
      final path = Path()
        ..moveTo(10 + ox, -34 + oy)
        ..cubicTo(-1 + ox, -22 + oy, -7 + ox, 0 + oy, -3 + ox, 15 + oy)
        ..cubicTo(-6 + ox, 5 + oy, 3 + ox, -17 + oy, 14 + ox, -28 + oy)
        ..close();
      canvas.drawPath(path, _f(color));
    }
  }

  void _drawTail(Canvas canvas) {
    final wag = tailWag * 12;
    for (final (color, oy, width) in [
      (_maneA, 0.0, 4.8),
      (_maneB, 2.5, 4.0),
      (_maneC, -2.5, 3.4),
    ]) {
      final path = Path()
        ..moveTo(-26, 12 + oy)
        ..cubicTo(-40, 22 + oy, -46 + wag, 38 + oy, -38 + wag, 52 + oy);
      canvas.drawPath(path, _s(color, width));
    }
  }

  void _drawBackLegs(Canvas canvas) {
    _drawLeg(canvas, -22, 30);
    _drawLeg(canvas, -10, 30);
  }

  void _drawFrontLegs(Canvas canvas) {
    final waveAngle = mood == UnicornMood.wave ? -sin(t * 2 * pi) * 0.65 : 0.0;
    canvas.save();
    canvas.translate(14, 30);
    canvas.rotate(waveAngle);
    _legAt(canvas, -5, 0);
    canvas.restore();
    _drawLeg(canvas, 4, 30);
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
    // SQUINTED — focused, determined expression
    final openFrac = (1.0 - blink * 0.3).clamp(0.3, 1.0);
    final h = 4.0 * openFrac;

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(12, -20), width: 13, height: h),
      _f(Colors.white),
    );
    if (h > 0.8) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(12.5, -20), width: h * 0.85, height: h * 0.7),
        _f(_iris),
      );
    }

    // Heavy determined brow — the signature Happy look
    final brow = Path()
      ..moveTo(6, -25)
      ..quadraticBezierTo(12.5, -28, 19, -24);
    canvas.drawPath(brow, _s(_iris.withOpacity(0.85), 2.1));

    // Energy sparkle on cheek
    canvas.drawCircle(
      const Offset(5, -14),
      2.8,
      Paint()
        ..color = _gold1.withOpacity(0.35)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawFace(Canvas canvas) {
    final blush = Paint()..color = _blush.withOpacity(0.28)..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromCenter(center: const Offset(7, -9), width: 12, height: 7), blush);
    canvas.drawOval(Rect.fromCenter(center: const Offset(29, -10), width: 10, height: 6), blush);

    canvas.drawCircle(const Offset(33, -5), 1.3, _f(_line));

    // Slight confident smirk
    final mouth = Path()
      ..moveTo(27, -5)
      ..quadraticBezierTo(31, -3, 35, -5);
    canvas.drawPath(mouth, _s(_iris.withOpacity(0.4), 1.5));

    if (mood == UnicornMood.thinking) {
      final dotPaint = _f(_maneA.withOpacity(0.7 + sin(t * 2 * pi) * 0.3));
      for (int i = 0; i < 3; i++) {
        final delay = (t - i * 0.15).clamp(0.0, 1.0);
        final dotY = -46.0 - sin(delay * pi) * 5;
        canvas.drawCircle(Offset(-8.0 + i * 6, dotY), 2.2, dotPaint);
      }
    }
  }

  void _drawLightningSparkles(Canvas canvas) {
    for (int i = 0; i < 5; i++) {
      final angle = (i / 5.0) * 2 * pi + t * 1.5 * pi;
      final dist  = 40.0 + sin(t * 2 * pi + i * 0.8) * 8;
      final cx    = cos(angle) * dist;
      final cy    = sin(angle) * dist - 12;
      final s     = 4.0 + sin(t * 2 * pi + i) * 1.5;
      _drawLightningBolt(canvas, Offset(cx, cy), s, _gold1.withOpacity(sparkle * 0.85));
    }
  }

  @override
  bool shouldRepaint(HappyPainter oldDelegate) =>
      oldDelegate.mood != mood || oldDelegate.t != t || oldDelegate.blink != blink ||
      oldDelegate.tailWag != tailWag || oldDelegate.sparkle != sparkle;
}
