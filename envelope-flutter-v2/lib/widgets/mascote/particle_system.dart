import 'dart:math';
import 'package:flutter/material.dart';
import '../../providers/unicorn_team.dart';

enum ParticleType { stars, hearts, lightning, confetti, teamBurst }

/// Returns the correct particle type for a given unicorn.
ParticleType particleTypeForUnicorn(UnicornType type) => switch (type) {
      UnicornType.astrix   => ParticleType.stars,
      UnicornType.sweet    => ParticleType.hearts,
      UnicornType.happy    => ParticleType.lightning,
      UnicornType.geronimo => ParticleType.confetti,
    };

// ── Particle data (immutable, computed positionally via animation t) ──────────

class _Particle {
  final double xBase;       // 0–1 normalised base x
  final double xAmplitude;  // horizontal sway amplitude (fraction of screen)
  final double phase;       // 0–1 start offset in animation cycle
  final double speedMult;   // speed relative to controller period
  final double size;
  final double rot0;        // initial rotation
  final double rotSpeed;    // radians per full cycle
  final Color color;
  final int shapeType;      // 0=star 1=heart 2=lightning 3=rect

  const _Particle({
    required this.xBase,
    required this.xAmplitude,
    required this.phase,
    required this.speedMult,
    required this.size,
    required this.rot0,
    required this.rotSpeed,
    required this.color,
    required this.shapeType,
  });
}

List<_Particle> _generate(ParticleType type, Random rng) {
  final count = type == ParticleType.teamBurst ? 48 : 24;
  return List.generate(count, (i) {
    final colors = _colors(type);
    final shapeType = switch (type) {
      ParticleType.stars     => 0,
      ParticleType.hearts    => 1,
      ParticleType.lightning => 2,
      ParticleType.confetti  => 3,
      ParticleType.teamBurst => i % 4,
    };
    return _Particle(
      xBase:      rng.nextDouble(),
      xAmplitude: 0.03 + rng.nextDouble() * 0.05,
      phase:      rng.nextDouble(),
      speedMult:  0.7 + rng.nextDouble() * 1.3,
      size:       5.0 + rng.nextDouble() * 10.0,
      rot0:       rng.nextDouble() * 2 * pi,
      rotSpeed:   (rng.nextDouble() - 0.5) * 4 * pi,
      color:      colors[rng.nextInt(colors.length)],
      shapeType:  shapeType,
    );
  });
}

List<Color> _colors(ParticleType type) => switch (type) {
      ParticleType.stars     => const [Color(0xFFAB47FF), Color(0xFF00C8FF), Color(0xFFFF4FA0), Color(0xFFFFD700)],
      ParticleType.hearts    => const [Color(0xFFFF8FAB), Color(0xFFCE93D8), Color(0xFFFFCC80), Color(0xFFFF4F91)],
      ParticleType.lightning => const [Color(0xFFFFCA28), Color(0xFFFF8F00), Color(0xFFFFF9C4), Colors.white],
      ParticleType.confetti  => const [Color(0xFFFF1744), Color(0xFFFF6D00), Color(0xFFFFEA00), Color(0xFF00E676), Color(0xFF2979FF), Color(0xFFD500F9)],
      ParticleType.teamBurst => const [Color(0xFFAB47FF), Color(0xFFFF8FAB), Color(0xFFFFCA28), Color(0xFFFF6D00), Color(0xFF00C8FF), Color(0xFFFF4FA0)],
    };

// ── Widget ────────────────────────────────────────────────────────────────────

/// Full-screen particle layer. Wrap with [IgnorePointer] / [Positioned.fill].
class FullScreenParticles extends StatefulWidget {
  final ParticleType type;

  const FullScreenParticles({super.key, required this.type});

  @override
  State<FullScreenParticles> createState() => _FullScreenParticlesState();
}

class _FullScreenParticlesState extends State<FullScreenParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl      = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _particles = _generate(widget.type, Random());
  }

  @override
  void didUpdateWidget(FullScreenParticles old) {
    super.didUpdateWidget(old);
    if (old.type != widget.type) _particles = _generate(widget.type, Random());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _ParticlesPainter(particles: _particles, t: _ctrl.value),
          size: MediaQuery.of(context).size,
        ),
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;

  _ParticlesPainter({required this.particles, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final progress = (t * p.speedMult + p.phase) % 1.0;
      final y        = size.height * (1.0 - progress) - 20;
      final x        = (p.xBase + p.xAmplitude * sin(progress * 2 * pi)) * size.width;

      // Fade in (first 5%) and fade out (last 20%)
      final alpha = (progress < 0.05
              ? progress / 0.05
              : progress > 0.8
                  ? (1.0 - progress) / 0.2
                  : 1.0)
          .clamp(0.0, 1.0);

      final rotation = p.rot0 + progress * p.rotSpeed;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      _drawShape(canvas, p, alpha);
      canvas.restore();
    }
  }

  void _drawShape(Canvas canvas, _Particle p, double alpha) {
    final paint = Paint()
      ..color = p.color.withOpacity(alpha * 0.85)
      ..style = PaintingStyle.fill;

    switch (p.shapeType) {
      case 0:
        _drawStar(canvas, p.size, paint);
      case 1:
        _drawHeart(canvas, p.size, paint);
      case 2:
        _drawLightning(canvas, p.size, paint);
      default:
        _drawRect(canvas, p.size, paint);
    }
  }

  void _drawStar(Canvas canvas, double r, Paint p) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final outerA = i * pi / 2 - pi / 4;
      final innerA = outerA + pi / 4;
      final ox = cos(outerA) * r;
      final oy = sin(outerA) * r;
      final ix = cos(innerA) * r * 0.35;
      final iy = sin(innerA) * r * 0.35;
      if (i == 0) { path.moveTo(ox, oy); } else { path.lineTo(ox, oy); }
      path.lineTo(ix, iy);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  void _drawHeart(Canvas canvas, double r, Paint p) {
    final path = Path();
    path.moveTo(0, r * 0.3);
    path.cubicTo(-r, r * 0.1, -r, -r * 0.6, 0, -r * 0.2);
    path.cubicTo(r, -r * 0.6, r, r * 0.1, 0, r * 0.3);
    path.close();
    canvas.drawPath(path, p);
  }

  void _drawLightning(Canvas canvas, double s, Paint p) {
    final path = Path()
      ..moveTo(s * 0.2,   -s * 0.5)
      ..lineTo(-s * 0.1,  0)
      ..lineTo(s * 0.15,  0)
      ..lineTo(-s * 0.2,  s * 0.5)
      ..lineTo(s * 0.1,  -s * 0.05)
      ..lineTo(-s * 0.15, -s * 0.05)
      ..close();
    canvas.drawPath(path, p);
  }

  void _drawRect(Canvas canvas, double s, Paint p) {
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: s * 0.55, height: s * 0.28),
      p,
    );
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) => old.t != t;
}
