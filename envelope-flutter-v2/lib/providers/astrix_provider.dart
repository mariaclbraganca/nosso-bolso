import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/unicorn/astrix_painter.dart';

class AstrixMessage {
  final String text;
  final AstrixMood mood;
  final Duration duration;

  const AstrixMessage({
    required this.text,
    this.mood = AstrixMood.idle,
    this.duration = const Duration(seconds: 5),
  });
}

final astrixProvider = StateProvider<AstrixMessage?>((ref) => null);

/// Convenience extension — call ref.astrix('...') from anywhere.
extension AstrixTrigger on WidgetRef {
  void astrix(
    String text, {
    AstrixMood mood = AstrixMood.idle,
    Duration duration = const Duration(seconds: 5),
  }) {
    read(astrixProvider.notifier).state =
        AstrixMessage(text: text, mood: mood, duration: duration);
  }
}
