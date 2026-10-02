import 'dart:math';
import 'package:flutter/material.dart';
import '../../providers/unicorn_team.dart';

/// Sweet 🌸 — lovable, warm, full of love.
/// Rose body, big anime eyes (heart pupils when mood==love), wavy pastel mane.
class SweetPainter extends CustomPainter {
  final UnicornMood mood;
  final double t;
  final double blink;
  final double tailWag;
  final double sparkle;

  static const _body  = Color(0xFFFCE4EC);
  static const _line  = Color(0xFFFF80AB);
  static const _maneA = Color(0xFFFF8FAB);
  static const _maneB = Color(0xFFCE93D8);
  static const _maneC = Color(0xFFFFCC80);
  static const _horn1 = Color(0xFFFF8FAB);
  static const _horn2 = Color(0xFFE91E8C);
  static const _iris  = Color(0xFF4A0E2E);
  static const _blush = Color(0xFFFF4F91);
  static const _hoof  = Color(0xFFE8A0B4);

  SweetPainter({
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
    if (mood == UnicornMood.idle || mood == UnicornMood.wave || mood == UnicornMood.love) {
      dy = sin(t * 2 * pi) * 2.5;
    }
    double sc = 1.0;
    if (mood == UnicornMood.celebrate || mood == UnicornMood.love) {
      sc = 1.0 + sin(t * 2 * pi) * 0.055;
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

    if ((mood == UnicornMood.celebrate || mood == UnicornMood.love) && sparkle > 0.05) {
      _drawHeartSparkles(canvas);
    }

    canvas.restore();
  }

  void _drawBody(Canvas canvas) {
    final r = Rect.fromCenter(center: const Offset(0, 18), width: 60, height: 40);
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
    canvas.drawCircle(const Offset(18, -16), 22, _f(_body));
    canvas.drawCircle(const Offset(18, -16), 22, _s(_line, 0.9));
    final snout = Rect.fromCenter(center: const Offset(34, -9), width: 17, height: 13);
    canvas.drawOval(snout, _f(_body));
    canvas.drawOval(snout, _s(_line, 0.7));
  }

  void _drawHorn(Canvas canvas) {
    final path = Path()
      ..moveTo(10, -34)
      ..lineTo(8, -34)
      ..cubicTo(5, -46, 17, -65, 19, -68)
      ..cubicTo(21, -65, 31, -46, 28, -34)
      ..close();

    final shader = LinearGradient(
      colors: [_horn1, _horn2],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(const Rect.fromLTWH(5, -70, 27, 38));

    canvas.drawPath(path, Paint()..shader = shader..style = PaintingStyle.fill);

    final spiral = Path()
      ..moveTo(13, -36)
      ..cubicTo(10, -44, 22, -55, 19, -62);
    canvas.drawPath(spiral, _s(Colors.white.withOpacity(0.5), 1.0));

    // Heart at the very tip
    canvas.drawPath(_heartPath(const Offset(19, -73), 5.0), _f(_horn1));
  }

  void _drawMane(Canvas canvas) {
    for (final (color, ox, oy) in [
      (_maneA, 0.0, 3.5),
      (_maneB, 4.5, 0.0),
      (_maneC, -4.0, -1.5),
    ]) {
      final path = Path()
        ..moveTo(10 + ox, -34 + oy)
        ..cubicTo(-3 + ox, -22 + oy, -11 + ox, 3 + oy, -6 + ox, 17 + oy)
        ..cubicTo(-9 + ox, 8 + oy, 0 + ox, -15 + oy, 14 + ox, -27 + oy)
        ..close();
      canvas.drawPath(path, _f(color));
    }
  }

  void _drawTail(Canvas canvas) {
    final wag = tailWag * 14;
    for (final (color, oy, width) in [
      (_maneA, 0.0, 5.0),
      (_maneC, 2.5, 4.2),
      (_maneB, -2.5, 3.6),
    ]) {
      final path = Path()
        ..moveTo(-26, 12 + oy)
        ..cubicTo(-40, 22 + oy, -48 + wag, 38 + oy, -38 + wag, 54 + oy);
      canvas.drawPath(path, _s(color, width));
    }
  }

  void _drawBackLegs(Canvas canvas) {
    _drawLeg(canvas, -22, 30);
    _drawLeg(canvas, -10, 30);
  }

  void _drawFrontLegs(Canvas canvas) {
    final waveAngle = mood == UnicornMood.wave ? -sin(t * 2 * pi) * 0.6 : 0.0;
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
    final openFrac = (1.0 - blink).clamp(0.05, 1.0);
    // BIG round eyes — Sweet's signature look
    final h = 12.0 * openFrac;

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(12, -20), width: 14, height: h),
      _f(Colors.white),
    );

    if (h > 2.0) {
      if (mood == UnicornMood.love && h > 4.0) {
        // Heart-shaped pupils
        canvas.drawPath(_heartPath(const Offset(12.5, -20.5), h * 0.38), _f(_iris));
      } else {
        canvas.drawCircle(const Offset(12.5, -19.5), h * 0.38, _f(_iris));
        // Double highlight — anime style
        canvas.drawCircle(const Offset(14.5, -21.5), 1.6, _f(Colors.white));
        canvas.drawCircle(const Offset(11.0, -22.0), 0.9, _f(Colors.white.withOpacity(0.7)));
      }
    }

    // Long prominent eyelashes
    final lash = _s(_iris.withOpacity(0.8), 1.2);
    canvas.drawLine(const Offset(6, -27),  const Offset(4.5, -31),  lash);
    canvas.drawLine(const Offset(9, -28),  const Offset(8.5, -32),  lash);
    canvas.drawLine(const Offset(12, -28), const Offset(12, -32.5), lash);
    canvas.drawLine(const Offset(15, -27), const Offset(15.5, -31), lash);
    canvas.drawLine(const Offset(18, -26), const Offset(19.5, -29), lash);

    if (mood == UnicornMood.sad) {
      final lid = Path()
        ..moveTo(7, -22)
        ..quadraticBezierTo(12, -18, 17, -22);
      canvas.drawPath(lid, _s(_line, 1.4));
    }
  }

  void _drawFace(Canvas canvas) {
    // Large heart-shaped blush cheeks
    canvas.drawPath(_heartPath(const Offset(6, -8), 6.5), _f(_blush.withOpacity(0.28)));
    canvas.drawPath(_heartPath(const Offset(30, -9), 5.5), _f(_blush.withOpacity(0.25)));

    // Nostril
    canvas.drawCircle(const Offset(34, -5), 1.3, _f(_line));

    // Gentle wide smile
    final mouth = Path();
    if (mood == UnicornMood.sad) {
      mouth.moveTo(27, -3);
      mouth.quadraticBezierTo(31, -6, 35, -3);
    } else {
      mouth.moveTo(26, -5);
      mouth.quadraticBezierTo(31, -1, 36, -5);
    }
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

  void _drawHeartSparkles(Canvas canvas) {
    for (int i = 0; i < 6; i++) {
      final angle = (i / 6.0) * 2 * pi + t * pi;
      final dist  = 42.0 + sin(t * 2 * pi + i * 1.1) * 8;
      final cx    = cos(angle) * dist;
      final cy    = sin(angle) * dist - 12;
      final r     = 2.5 + sin(t * 2 * pi * 1.3 + i) * 1.0;
      final color = i % 2 == 0 ? _maneA : _horn1;
      canvas.drawPath(_heartPath(Offset(cx, cy), r), _f(color.withOpacity(sparkle * 0.9)));
    }
  }

  Path _heartPath(Offset c, double r) {
    final p = Path();
    p.moveTo(c.dx, c.dy + r * 0.3);
    p.cubicTo(c.dx - r, c.dy + r * 0.1, c.dx - r, c.dy - r * 0.6, c.dx, c.dy - r * 0.2);
    p.cubicTo(c.dx + r, c.dy - r * 0.6, c.dx + r, c.dy + r * 0.1, c.dx, c.dy + r * 0.3);
    p.close();
    return p;
  }

  @override
  bool shouldRepaint(SweetPainter oldDelegate) =>
      oldDelegate.mood != mood || oldDelegate.t != t || oldDelegate.blink != blink ||
      oldDelegate.tailWag != tailWag || oldDelegate.sparkle != sparkle;
}
