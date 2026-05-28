import 'dart:math';
import 'package:flutter/material.dart';
import '../../providers/unicorn_team.dart';
import 'astrix_painter.dart';
import 'sweet_painter.dart';
import 'happy_painter.dart';
import 'geronimo_painter.dart';

/// Generic unicorn widget — wraps any unicorn painter with animation controllers.
/// Drop-in replacement for [AstrixWidget] when you need a specific team member.
class UnicornWidget extends StatefulWidget {
  final UnicornType type;
  final UnicornMood mood;
  final double size;

  const UnicornWidget({
    super.key,
    required this.type,
    this.mood = UnicornMood.idle,
    this.size = 80,
  });

  @override
  State<UnicornWidget> createState() => _UnicornWidgetState();
}

class _UnicornWidgetState extends State<UnicornWidget> with TickerProviderStateMixin {
  late AnimationController _main;
  late AnimationController _blink;
  late AnimationController _tail;
  late AnimationController _sparkle;

  @override
  void initState() {
    super.initState();
    _main    = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _tail    = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _blink   = AnimationController(vsync: this, duration: const Duration(milliseconds: 140));
    _sparkle = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _startBlinking();
    _applyMood(widget.mood);
  }

  @override
  void didUpdateWidget(UnicornWidget old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) _applyMood(widget.mood);
  }

  void _applyMood(UnicornMood m) {
    _sparkle.stop();
    switch (m) {
      case UnicornMood.celebrate || UnicornMood.love:
        _main.duration = const Duration(milliseconds: 520);
        _main.repeat();
        _sparkle.repeat();
      case UnicornMood.chaos:
        _main.duration = const Duration(milliseconds: 380);
        _main.repeat();
        _sparkle.repeat();
      case UnicornMood.sad:
        _main.duration = const Duration(seconds: 3);
        _main.forward(from: 0);
      case UnicornMood.wave:
        _main.duration = const Duration(milliseconds: 860);
        _main.repeat();
      case UnicornMood.thinking || UnicornMood.focus:
        _main.duration = const Duration(milliseconds: 1200);
        _main.repeat();
      case UnicornMood.idle:
        _main.duration = const Duration(seconds: 2);
        _main.repeat();
    }
  }

  Future<void> _startBlinking() async {
    final rng = Random();
    while (mounted) {
      // Geronimo blinks erratically, others blink calmly
      final base  = widget.type == UnicornType.geronimo ? 1400 : 2400;
      final extra = widget.type == UnicornType.geronimo ? 1600 : 2600;
      await Future.delayed(Duration(milliseconds: base + rng.nextInt(extra)));
      if (!mounted) return;
      await _blink.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 70));
      await _blink.reverse();
    }
  }

  AstrixMood _toAstrixMood(UnicornMood m) => switch (m) {
        UnicornMood.idle      => AstrixMood.idle,
        UnicornMood.wave      => AstrixMood.wave,
        UnicornMood.celebrate => AstrixMood.celebrate,
        UnicornMood.sad       => AstrixMood.sad,
        UnicornMood.thinking  => AstrixMood.thinking,
        UnicornMood.love      => AstrixMood.celebrate,
        UnicornMood.focus     => AstrixMood.thinking,
        UnicornMood.chaos     => AstrixMood.celebrate,
      };

  @override
  void dispose() {
    _main.dispose();
    _blink.dispose();
    _tail.dispose();
    _sparkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_main, _blink, _tail, _sparkle]),
      builder: (_, __) {
        final t       = _main.value;
        final blink   = _blink.value;
        final tailWag = _tail.value * 2 - 1;
        final sparkle = _sparkle.value;

        final CustomPainter painter = switch (widget.type) {
          UnicornType.astrix => AstrixPainter(
              mood:    _toAstrixMood(widget.mood),
              t:       t,
              blink:   blink,
              tailWag: tailWag,
              sparkle: sparkle,
            ),
          UnicornType.sweet => SweetPainter(
              mood:    widget.mood,
              t:       t,
              blink:   blink,
              tailWag: tailWag,
              sparkle: sparkle,
            ),
          UnicornType.happy => HappyPainter(
              mood:    widget.mood,
              t:       t,
              blink:   blink,
              tailWag: tailWag,
              sparkle: sparkle,
            ),
          UnicornType.geronimo => GeronimoUnicornPainter(
              mood:    widget.mood,
              t:       t,
              blink:   blink,
              tailWag: tailWag,
              sparkle: sparkle,
            ),
        };

        return CustomPaint(
          size:    Size(widget.size, widget.size * 1.16),
          painter: painter,
        );
      },
    );
  }
}
