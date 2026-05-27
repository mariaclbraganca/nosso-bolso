import 'dart:math';
import 'package:flutter/material.dart';

enum AstrixMood { idle, wave, celebrate, sad, thinking }

/// Draws Astrix the unicorn entirely in code — no external assets needed.
/// Canvas coordinate system: (0,0) = top-left of 120×140 logical units.
/// Call with CustomPaint(size: Size(w, w*1.16), painter: AstrixPainter(...)).
class AstrixPainter extends CustomPainter {
  final AstrixMood mood;
  final double t;        // 0→1 repeating main tick
  final double blink;    // 0=open eye, 1=closed eye
  final double tailWag;  // -1→1
  final double sparkle;  // 0→1 sparkle alpha

  // ─── Palette ────────────────────────────────────────────────────────────────
  static const _body  = Color(0xFFFFF5FC);
  static const _line  = Color(0xFFE0C0D0);
  static const _gold1 = Color(0xFFFFD700);
  static const _gold2 = Color(0xFFE8A000);
  static const _maneA = Color(0xFFAB47FF);  // purple
  static const _maneB = Color(0xFF00C8FF);  // cyan
  static const _maneC = Color(0xFFFF4FA0);  // hot pink
  static const _iris  = Color(0xFF1A0A35);
  static const _blush = Color(0xFFFF90AB);
  static const _hoof  = Color(0xFFD4A8C0);

  AstrixPainter({
    required this.mood,
    required this.t,
    required this.blink,
    required this.tailWag,
    required this.sparkle,
  });

  // ─── Helpers ────────────────────────────────────────────────────────────────
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

    // Scale 120×140 logical units to actual size
    canvas.scale(size.width / 120.0, size.height / 140.0);

    // Work in local coords, origin at (60, 82) — center of the scene
    canvas.translate(60, 82);

    // Idle / wave bob
    double dy = 0;
    if (mood == AstrixMood.idle || mood == AstrixMood.wave) {
      dy = sin(t * 2 * pi) * 2.8;
    }

    // Celebrate pulse scale
    double sc = 1.0;
    if (mood == AstrixMood.celebrate) {
      sc = 1.0 + sin(t * 2 * pi) * 0.072;
    }

    // Sad droop
    if (mood == AstrixMood.sad) dy = t * 5.0;

    canvas.translate(0, dy);
    canvas.scale(sc, sc);

    // Draw order: tail → back legs → body → neck → front legs → head → mane → horn → face details → fx
    _tail(canvas);
    _backLegs(canvas);
    _drawBody(canvas);
    _neck(canvas);
    _frontLegs(canvas);
    _head(canvas);
    _mane(canvas);
    _horn(canvas);
    _eyes(canvas);
    _face(canvas);

    if (mood == AstrixMood.celebrate && sparkle > 0.05) _sparkles(canvas);
    if (mood == AstrixMood.sad && t > 0.25) _tear(canvas);
    if (mood == AstrixMood.thinking) _dots(canvas);

    canvas.restore();
  }

  // ─── Body ───────────────────────────────────────────────────────────────────
  void _drawBody(Canvas canvas) {
    final r = Rect.fromCenter(center: const Offset(0, 18), width: 58, height: 38);
    canvas.drawOval(r, _f(_body));
    canvas.drawOval(r, _s(_line, 0.9));
  }

  // ─── Neck ───────────────────────────────────────────────────────────────────
  void _neck(Canvas canvas) {
    final path = Path()
      ..moveTo(-4, -2)
      ..quadraticBezierTo(-6, 8, -4, 16)
      ..lineTo(12, 16)
      ..quadraticBezierTo(14, 8, 14, -2)
      ..close();
    canvas.drawPath(path, _f(_body));
    canvas.drawPath(path, _s(_line, 0.7));
  }

  // ─── Head ───────────────────────────────────────────────────────────────────
  void _head(Canvas canvas) {
    // Main cranium
    canvas.drawCircle(const Offset(18, -16), 21, _f(_body));
    canvas.drawCircle(const Offset(18, -16), 21, _s(_line, 0.9));
    // Snout protrusion
    final snout = Rect.fromCenter(center: const Offset(33, -9), width: 16, height: 12);
    canvas.drawOval(snout, _f(_body));
    canvas.drawOval(snout, _s(_line, 0.7));
  }

  // ─── Horn ───────────────────────────────────────────────────────────────────
  void _horn(Canvas canvas) {
    final path = Path()
      ..moveTo(11, -34)
      ..lineTo(8, -34)
      ..cubicTo(6, -46, 17, -66, 19, -70)
      ..cubicTo(21, -66, 30, -46, 28, -34)
      ..close();

    final gradient = LinearGradient(
      colors: [_gold1, _gold2],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(const Rect.fromLTWH(6, -72, 26, 40));

    canvas.drawPath(path, Paint()..shader = gradient..style = PaintingStyle.fill);

    // Spiral stripe
    final spiral = Path()
      ..moveTo(13, -36)
      ..cubicTo(10, -44, 22, -56, 19, -64);
    canvas.drawPath(spiral, _s(Colors.white.withOpacity(0.55), 1.1));

    // Glow when celebrating
    if (mood == AstrixMood.celebrate) {
      canvas.drawCircle(
        const Offset(19, -52),
        16,
        Paint()
          ..color = _gold1.withOpacity(sparkle * 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
  }

  // ─── Mane ───────────────────────────────────────────────────────────────────
  void _mane(Canvas canvas) {
    final strands = [
      (_maneA, 0.0, 3.0),
      (_maneB, 4.0, 0.0),
      (_maneC, -4.0, -2.0),
    ];
    for (final (color, ox, oy) in strands) {
      final path = Path()
        ..moveTo(10 + ox, -34 + oy)
        ..cubicTo(-4 + ox, -22 + oy, -12 + ox, 2 + oy, -7 + ox, 16 + oy)
        ..cubicTo(-10 + ox, 7 + oy, -1 + ox, -16 + oy, 13 + ox, -28 + oy)
        ..close();
      canvas.drawPath(path, _f(color));
    }
  }

  // ─── Tail ───────────────────────────────────────────────────────────────────
  void _tail(Canvas canvas) {
    final wag = tailWag * 16;
    final strands = [
      (_maneA, 0.0, 4.8),
      (_maneC, 2.5, 4.0),
      (_maneB, -2.5, 3.4),
    ];
    for (final (color, oy, width) in strands) {
      final path = Path()
        ..moveTo(-26, 12 + oy)
        ..cubicTo(-42, 22 + oy, -48 + wag, 38 + oy, -40 + wag, 54 + oy);
      canvas.drawPath(path, _s(color, width));
    }
  }

  // ─── Legs ───────────────────────────────────────────────────────────────────
  void _backLegs(Canvas canvas) {
    _drawLeg(canvas, -22, 30, 0);
    _drawLeg(canvas, -10, 30, 0);
  }

  void _frontLegs(Canvas canvas) {
    // Front-right may wave
    final waveAngle = mood == AstrixMood.wave ? -sin(t * 2 * pi) * 0.65 : 0.0;
    canvas.save();
    canvas.translate(14, 30);
    canvas.rotate(waveAngle);
    _legAt(canvas, -5, 0);
    canvas.restore();

    _drawLeg(canvas, 4, 30, 0);
  }

  void _drawLeg(Canvas canvas, double x, double y, double rot) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rot);
    _legAt(canvas, 0, 0);
    canvas.restore();
  }

  void _legAt(Canvas canvas, double x, double y) {
    final leg = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, 11, 24),
      const Radius.circular(5),
    );
    canvas.drawRRect(leg, _f(_body));
    canvas.drawRRect(leg, _s(_line, 0.8));

    // Hoof
    final hoof = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y + 18, 11, 8),
      const Radius.circular(4),
    );
    canvas.drawRRect(hoof, _f(_hoof));
  }

  // ─── Eyes ───────────────────────────────────────────────────────────────────
  void _eyes(Canvas canvas) {
    final openFrac = (1.0 - blink).clamp(0.05, 1.0);
    final h = 9.0 * openFrac;

    // Sclera
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(12, -20), width: 11, height: h),
      _f(Colors.white),
    );

    if (h > 1.5) {
      // Iris
      canvas.drawCircle(const Offset(12.5, -19.5), h * 0.36, _f(_iris));
      // Pupil highlight
      canvas.drawCircle(const Offset(14, -21), 1.3, _f(Colors.white));
    }

    // Eyelashes
    final lash = _s(_iris.withOpacity(0.8), 1.1);
    final sadOffset = mood == AstrixMood.sad ? 2.0 : 0.0;
    canvas.drawLine(Offset(8, -26 + sadOffset), Offset(7, -29 + sadOffset), lash);
    canvas.drawLine(Offset(12, -27 + sadOffset), Offset(12, -30 + sadOffset), lash);
    canvas.drawLine(Offset(16, -26 + sadOffset), Offset(17, -29 + sadOffset), lash);

    // Sad half-closed eyelid
    if (mood == AstrixMood.sad) {
      final lid = Path()
        ..moveTo(7, -22)
        ..quadraticBezierTo(12, -18, 17, -22);
      canvas.drawPath(lid, _s(_line, 1.4));
    }
  }

  // ─── Face details ────────────────────────────────────────────────────────────
  void _face(Canvas canvas) {
    // Blush cheeks
    final blush = Paint()
      ..color = _blush.withOpacity(0.32)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(7, -9), width: 13, height: 7),
      blush,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(30, -10), width: 10, height: 6),
      blush,
    );

    // Nostril
    canvas.drawCircle(const Offset(33, -5), 1.3, _f(_line));

    // Mouth
    final mPath = Path();
    if (mood == AstrixMood.sad) {
      mPath.moveTo(27, -3);
      mPath.quadraticBezierTo(31, -6, 35, -3);
    } else {
      mPath.moveTo(27, -5);
      mPath.quadraticBezierTo(31, -2, 35, -5);
    }
    canvas.drawPath(mPath, _s(_iris.withOpacity(0.3), 1.4));

    // Thinking ellipsis
    if (mood == AstrixMood.thinking) {
      final dotPaint = _f(_maneA.withOpacity(0.7 + sin(t * 2 * pi) * 0.3));
      for (int i = 0; i < 3; i++) {
        final delay = (t - i * 0.15).clamp(0.0, 1.0);
        final dotY = -46.0 - sin(delay * pi) * 5;
        canvas.drawCircle(Offset(-8.0 + i * 6, dotY), 2.2, dotPaint);
      }
    }
  }

  // ─── Sparkles ────────────────────────────────────────────────────────────────
  void _sparkles(Canvas canvas) {
    final p1 = _f(_gold1.withOpacity(sparkle * 0.9));
    final p2 = _f(_maneC.withOpacity(sparkle * 0.75));
    final p3 = _f(_maneB.withOpacity(sparkle * 0.7));
    final colors = [p1, p2, p3, p1, p2, p3, p1, p2];

    for (int i = 0; i < 8; i++) {
      final angle = (i / 8.0) * 2 * pi + t * 1.4 * pi;
      final dist = 44.0 + sin(t * 2 * pi + i * 0.9) * 9;
      final cx = cos(angle) * dist;
      final cy = sin(angle) * dist - 14;
      final r = 3.0 + sin(t * 2 * pi * 1.5 + i) * 1.4;
      _star4(canvas, Offset(cx, cy), r, colors[i]);
    }
  }

  void _star4(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final outerA = (i * pi / 2) - pi / 4 + t * pi;
      final innerA = outerA + pi / 4;
      final ox = c.dx + cos(outerA) * r;
      final oy = c.dy + sin(outerA) * r;
      final ix = c.dx + cos(innerA) * r * 0.35;
      final iy = c.dy + sin(innerA) * r * 0.35;
      if (i == 0) { path.moveTo(ox, oy); } else { path.lineTo(ox, oy); }
      path.lineTo(ix, iy);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  // ─── Tear ────────────────────────────────────────────────────────────────────
  void _tear(Canvas canvas) {
    final progress = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
    final tearPath = Path()
      ..moveTo(10, -18)
      ..cubicTo(8, -12 + progress * 22, 12, -8 + progress * 22, 10, -16 + progress * 26);
    canvas.drawPath(tearPath, _s(_maneB.withOpacity(0.65), 2.8));
  }

  // ─── Thinking dots ──────────────────────────────────────────────────────────
  void _dots(Canvas canvas) {
    // already drawn in _face → thinking branch
  }

  @override
  bool shouldRepaint(AstrixPainter oldDelegate) =>
      oldDelegate.mood != mood || oldDelegate.t != t || oldDelegate.blink != blink ||
      oldDelegate.tailWag != tailWag || oldDelegate.sparkle != sparkle;
}
