import 'dart:math';
import 'package:flutter/material.dart';
import 'astrix_painter.dart';

export 'astrix_painter.dart' show AstrixMood;

class AstrixWidget extends StatefulWidget {
  final AstrixMood mood;
  final double size;

  const AstrixWidget({
    super.key,
    this.mood = AstrixMood.idle,
    this.size = 80,
  });

  @override
  State<AstrixWidget> createState() => _AstrixWidgetState();
}

class _AstrixWidgetState extends State<AstrixWidget> with TickerProviderStateMixin {
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
  void didUpdateWidget(AstrixWidget old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) _applyMood(widget.mood);
  }

  void _applyMood(AstrixMood m) {
    _sparkle.stop();
    switch (m) {
      case AstrixMood.celebrate:
        _main.duration = const Duration(milliseconds: 520);
        _main.repeat();
        _sparkle.repeat();
      case AstrixMood.sad:
        _main.duration = const Duration(seconds: 3);
        _main.forward(from: 0);
      case AstrixMood.wave:
        _main.duration = const Duration(milliseconds: 860);
        _main.repeat();
      case AstrixMood.thinking:
        _main.duration = const Duration(milliseconds: 1200);
        _main.repeat();
      case AstrixMood.idle:
        _main.duration = const Duration(seconds: 2);
        _main.repeat();
    }
  }

  Future<void> _startBlinking() async {
    final rng = Random();
    while (mounted) {
      await Future.delayed(Duration(milliseconds: 2400 + rng.nextInt(2600)));
      if (!mounted) return;
      await _blink.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 70));
      await _blink.reverse();
    }
  }

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
      builder: (_, __) => CustomPaint(
        size: Size(widget.size, widget.size * 1.16),
        painter: AstrixPainter(
          mood: widget.mood,
          t: _main.value,
          blink: _blink.value,
          tailWag: _tail.value * 2 - 1,
          sparkle: _sparkle.value,
        ),
      ),
    );
  }
}
