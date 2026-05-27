import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/astrix_provider.dart';
import 'astrix_widget.dart';
import 'astrix_bubble.dart';

/// Wrap your app's body (or MaterialApp.builder) with this.
/// Astrix sits in the bottom-right corner and reacts to [astrixProvider].
class AstrixOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const AstrixOverlay({super.key, required this.child});

  @override
  ConsumerState<AstrixOverlay> createState() => _AstrixOverlayState();
}

class _AstrixOverlayState extends ConsumerState<AstrixOverlay>
    with SingleTickerProviderStateMixin {
  AstrixMessage? _current;
  Timer? _timer;
  late AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _fade.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _show(AstrixMessage msg) {
    _timer?.cancel();
    setState(() => _current = msg);
    _fade.forward(from: 0);
    _timer = Timer(msg.duration, _dismiss);
  }

  void _dismiss() {
    _timer?.cancel();
    _fade.reverse().then((_) {
      if (mounted) {
        setState(() => _current = null);
        ref.read(astrixProvider.notifier).state = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AstrixMessage?>(astrixProvider, (_, next) {
      if (next != null) _show(next);
    });

    return Stack(
      children: [
        widget.child,
        Positioned(
          bottom: 16,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Speech bubble
              if (_current != null)
                FadeTransition(
                  opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: _fade, curve: Curves.easeOut)),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6, right: 6),
                      child: AstrixBubble(
                        text: _current!.text,
                        onDismiss: _dismiss,
                      ),
                    ),
                  ),
                ),
              // Astrix always visible (tapping dismisses current bubble)
              GestureDetector(
                onTap: _current != null ? _dismiss : null,
                child: AstrixWidget(
                  mood: _current?.mood ?? AstrixMood.idle,
                  size: 72,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
