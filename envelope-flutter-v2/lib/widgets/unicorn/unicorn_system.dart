import 'dart:math';
import 'package:flutter/material.dart';
import '../../providers/unicorn_team.dart';
export '../../providers/unicorn_team.dart' show UnicornType, UnicornMood;
export 'astrix_painter.dart' show AstrixMood;
import 'astrix_painter.dart';
import 'sweet_painter.dart';
import 'happy_painter.dart';
import 'geronimo_painter.dart';
import 'particle_system.dart';

// ─── Base widget animado — breathing idle + entrada ──────────────────────────

class UnicornWidget extends StatefulWidget {
  final UnicornType type;
  final double size;
  final AstrixMood mood;
  final bool animate;

  const UnicornWidget({
    super.key,
    required this.type,
    this.size = 120,
    this.mood = AstrixMood.idle,
    this.animate = true,
  });

  @override
  State<UnicornWidget> createState() => _UnicornWidgetState();
}

class _UnicornWidgetState extends State<UnicornWidget>
    with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _blink;
  late final AnimationController _enter;

  late final Animation<double> _breathe;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  double _blinkVal = 0;
  double _t = 0;
  double _tailWag = 0;

  @override
  void initState() {
    super.initState();

    // Breathing idle — 3s loop
    _idle = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..addListener(() {
        setState(() {
          _t = _idle.value;
          _tailWag = sin(_idle.value * 2 * pi) * 0.8;
        });
      });

    // Breathing scale 1.0 → 1.025
    _breathe = Tween(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(parent: _idle, curve: Curves.easeInOut),
    );

    // Blink every ~4s
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 150))
      ..addListener(() => setState(() => _blinkVal = _blink.value))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _blink.reverse();
      });

    // Entrada: slide up + fade
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();

    _slide = Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _enter, curve: Curves.easeOut),
    );
    _fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _enter, curve: Curves.easeOut),
    );

    if (widget.animate) {
      _idle.repeat(reverse: true);
      _scheduleBlink();
    }
  }

  void _scheduleBlink() {
    Future.delayed(Duration(milliseconds: 3500 + Random().nextInt(2000)), () {
      if (!mounted) return;
      _blink.forward();
      _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _idle.dispose();
    _blink.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.size * 1.16;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _breathe,
          child: SizedBox(
            width: widget.size,
            height: h,
            child: CustomPaint(
              size: Size(widget.size, h),
              painter: _painterFor(widget.type),
            ),
          ),
        ),
      ),
    );
  }

  UnicornMood _toUnicornMood(AstrixMood m) => switch (m) {
    AstrixMood.idle      => UnicornMood.idle,
    AstrixMood.wave      => UnicornMood.wave,
    AstrixMood.celebrate => UnicornMood.celebrate,
    AstrixMood.sad       => UnicornMood.sad,
    AstrixMood.thinking  => UnicornMood.thinking,
  };

  CustomPainter _painterFor(UnicornType type) {
    final isCelebrate = widget.mood == AstrixMood.celebrate;
    switch (type) {
      case UnicornType.astrix:
        return AstrixPainter(
          mood: widget.mood,
          t: _t,
          blink: _blinkVal,
          tailWag: _tailWag,
          sparkle: isCelebrate ? _t : 0,
        );
      case UnicornType.sweet:
        return SweetPainter(
          mood: _toUnicornMood(widget.mood),
          t: _t,
          blink: _blinkVal,
          tailWag: _tailWag,
          sparkle: isCelebrate ? _t : 0,
        );
      case UnicornType.happy:
        return HappyPainter(
          mood: _toUnicornMood(widget.mood),
          t: _t,
          blink: _blinkVal,
          tailWag: _tailWag,
          sparkle: isCelebrate ? _t : 0,
        );
      case UnicornType.geronimo:
        return GeronimoUnicornPainter(
          mood: _toUnicornMood(widget.mood),
          t: _t,
          blink: _blinkVal,
          tailWag: _tailWag,
          sparkle: isCelebrate ? _t : 0,
        );
    }
  }
}

// ─── Bubble persistente — canto inferior direito ──────────────────────────────

class UnicornBubble extends StatefulWidget {
  final UnicornType type;
  final String? message;
  final VoidCallback? onTap;

  const UnicornBubble({
    super.key,
    this.type = UnicornType.astrix,
    this.message,
    this.onTap,
  });

  @override
  State<UnicornBubble> createState() => _UnicornBubbleState();
}

class _UnicornBubbleState extends State<UnicornBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float;
  late final Animation<Offset> _floatAnim;
  bool _showMessage = false;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _floatAnim = Tween(begin: const Offset(0, 0), end: const Offset(0, -0.08))
        .animate(CurvedAnimation(parent: _float, curve: Curves.easeInOut));

    if (widget.message != null) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _showMessage = true);
      });
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onTap?.call();
        if (widget.message != null) {
          setState(() => _showMessage = !_showMessage);
        }
      },
      child: SlideTransition(
        position: _floatAnim,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_showMessage && widget.message != null)
              _MessageBubble(message: widget.message!),
            UnicornWidget(type: widget.type, size: 80),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final String message;
  const _MessageBubble({required this.message});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250))
      ..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      alignment: Alignment.bottomRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        margin: const EdgeInsets.only(bottom: 8, right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF181C12),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: const Radius.circular(4),
          ),
          border: Border.all(color: const Color(0xFF9ED465).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          widget.message,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFFEFF5E1),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

// ─── Empty State — unicórnio grande centralizado ───────────────────────────

class UnicornEmpty extends StatelessWidget {
  final UnicornType type;
  final String title;
  final String subtitle;

  const UnicornEmpty({
    super.key,
    this.type = UnicornType.astrix,
    required this.title,
    this.subtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UnicornWidget(type: type, size: 160, mood: AstrixMood.wave),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEFF5E1),
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: Color(0xFF5A6450)),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Loading — unicórnio correndo no lugar de spinner ────────────────────────

class UnicornLoading extends StatelessWidget {
  final String? message;
  const UnicornLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UnicornWidget(
            type: UnicornType.happy,
            size: 100,
            mood: AstrixMood.wave,
          ),
          const SizedBox(height: 16),
          Text(
            message ?? 'Carregando...',
            style: const TextStyle(fontSize: 14, color: Color(0xFF5A6450)),
          ),
        ],
      ),
    );
  }
}

// ─── Celebração — tela inteira com partículas ────────────────────────────────

class UnicornCelebration extends StatefulWidget {
  final String title;
  final String subtitle;
  final VoidCallback onContinue;

  const UnicornCelebration({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onContinue,
  });

  @override
  State<UnicornCelebration> createState() => _UnicornCelebrationState();
}

class _UnicornCelebrationState extends State<UnicornCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF080A06),
      child: Stack(
        children: [
          const Positioned.fill(child: ParticleField()),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UnicornWidget(
                        type: UnicornType.sweet,
                        size: 180,
                        mood: AstrixMood.celebrate,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF5C542),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFFEFF5E1),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: widget.onContinue,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF9ED465),
                            foregroundColor: const Color(0xFF080A06),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Continuar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Campo de partículas — wrapper sobre FullScreenParticles ─────────────────

class ParticleField extends StatelessWidget {
  final UnicornType type;
  const ParticleField({super.key, this.type = UnicornType.astrix});

  @override
  Widget build(BuildContext context) {
    return FullScreenParticles(type: particleTypeForUnicorn(type));
  }
}
