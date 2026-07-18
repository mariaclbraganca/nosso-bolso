import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UnicornType { astrix, sweet, happy, geronimo }

enum UnicornMood { idle, wave, celebrate, love, focus, chaos, thinking, sad }

class UnicornMessage {
  final UnicornType type;
  final String text;
  final UnicornMood mood;
  final Duration duration;

  const UnicornMessage({
    required this.type,
    required this.text,
    this.mood = UnicornMood.idle,
    this.duration = const Duration(seconds: 5),
  });
}

class TeamMoment {
  final Map<UnicornType, String> messages;
  final Duration duration;

  const TeamMoment({
    required this.messages,
    this.duration = const Duration(seconds: 7),
  });
}

final unicornTeamProvider       = StateProvider<UnicornMessage?>((ref) => null);
final unicornTeamMomentProvider = StateProvider<TeamMoment?>((ref) => null);

extension UnicornTrigger on WidgetRef {
  void sweet(
    String text, {
    UnicornMood mood = UnicornMood.love,
    Duration duration = const Duration(seconds: 5),
  }) =>
      read(unicornTeamProvider.notifier).state =
          UnicornMessage(type: UnicornType.sweet, text: text, mood: mood, duration: duration);

  void happy(
    String text, {
    UnicornMood mood = UnicornMood.focus,
    Duration duration = const Duration(seconds: 5),
  }) =>
      read(unicornTeamProvider.notifier).state =
          UnicornMessage(type: UnicornType.happy, text: text, mood: mood, duration: duration);

  void geronimo(
    String text, {
    UnicornMood mood = UnicornMood.chaos,
    Duration duration = const Duration(seconds: 5),
  }) =>
      read(unicornTeamProvider.notifier).state =
          UnicornMessage(type: UnicornType.geronimo, text: text, mood: mood, duration: duration);

  void unicornTeam({
    required Map<UnicornType, String> messages,
    Duration duration = const Duration(seconds: 7),
  }) =>
      read(unicornTeamMomentProvider.notifier).state =
          TeamMoment(messages: messages, duration: duration);
}
