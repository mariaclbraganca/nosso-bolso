import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class StreakService {
  static const _kPrefix = 'saude_streak_';

  static Future<int> getStreak(String membroId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kPrefix$membroId');
    if (raw == null) return 0;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final lastDate = map['lastDate'] as String?;
      final streak = (map['streak'] as int?) ?? 0;
      final today = _dateStr(DateTime.now());
      final yesterday = _dateStr(DateTime.now().subtract(const Duration(days: 1)));
      if (lastDate == today || lastDate == yesterday) return streak;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  // Returns the updated streak count after recording today's activity.
  static Future<int> recordActivity(String membroId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kPrefix$membroId';
    final today = _dateStr(DateTime.now());
    final yesterday = _dateStr(DateTime.now().subtract(const Duration(days: 1)));
    final raw = prefs.getString(key);

    int streak;
    if (raw == null) {
      streak = 1;
    } else {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final lastDate = map['lastDate'] as String?;
        final prev = (map['streak'] as int?) ?? 0;
        if (lastDate == today) return prev;
        streak = lastDate == yesterday ? prev + 1 : 1;
      } catch (_) {
        streak = 1;
      }
    }

    await prefs.setString(key, jsonEncode({'streak': streak, 'lastDate': today}));
    // Usuário registrou atividade hoje — cancela o alerta de streak das 20h
    NotificationService.cancelarLembreteStreak();
    return streak;
  }

  static String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
