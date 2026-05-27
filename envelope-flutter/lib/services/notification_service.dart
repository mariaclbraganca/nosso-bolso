import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ── IDs fixos por tipo de notificação ────────────────────────────────────────
class _NId {
  static const cafeManhaLembrete   = 1;
  static const almocoLembrete      = 2;
  static const lancheLembrete      = 3;
  static const jantarLembrete      = 4;
  static const streakLembrete      = 5;
  static const hidratacaoLembrete  = 6;
  static const resumoFinanceiro    = 7;
  static const contaVencimento     = 100; // +id da conta para não colidir
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ── Inicialização ──────────────────────────────────────────────────────────
  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onTap,
    );

    _initialized = true;
  }

  static void _onTap(NotificationResponse r) {
    // Payload pode ser usado para navegar: 'nutricao', 'financeiro', etc.
    debugPrint('[Notification] tapped: ${r.payload}');
  }

  // ── Permissão (Android 13+) ───────────────────────────────────────────────
  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  // ── Helpers internos ─────────────────────────────────────────────────────
  static AndroidNotificationDetails _androidChannel(
    String channelId,
    String channelName, {
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
    String? icon,
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      importance: importance,
      priority: priority,
      icon: icon,
      playSound: true,
    );
  }

  static tz.TZDateTime _nextTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var dt = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (dt.isBefore(now)) dt = dt.add(const Duration(days: 1));
    return dt;
  }

  // ── Verificar se notificações estão habilitadas nas prefs ────────────────
  static Future<bool> _isEnabled(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true; // habilitado por padrão
  }

  static Future<void> setEnabled(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NUTRIÇÃO
  // ─────────────────────────────────────────────────────────────────────────

  /// Agenda os 4 lembretes diários de refeição (repete todo dia no mesmo horário).
  static Future<void> agendarLembretesRefeicao() async {
    if (!await _isEnabled('notif_refeicoes')) return;

    final slots = [
      (_NId.cafeManhaLembrete,   7, 30, 'Café da manhã ☕',       'Hora do café! Não pule essa, tá?'),
      (_NId.almocoLembrete,     12,  0, 'Almoço 🍽️',              'Já registrou o almoço hoje?'),
      (_NId.lancheLembrete,     15, 30, 'Lanche da tarde 🍎',     'Um lancinho saudável agora?'),
      (_NId.jantarLembrete,     19,  0, 'Jantar 🌙',              'Hora de registrar o jantar!'),
    ];

    for (final (id, h, m, title, body) in slots) {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextTime(h, m),
        NotificationDetails(
          android: _androidChannel('refeicoes', 'Lembretes de Refeição',
              importance: Importance.high),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'nutricao',
      );
    }
  }

  static Future<void> cancelarLembretesRefeicao() async {
    for (final id in [
      _NId.cafeManhaLembrete,
      _NId.almocoLembrete,
      _NId.lancheLembrete,
      _NId.jantarLembrete,
    ]) {
      await _plugin.cancel(id);
    }
  }

  /// Lembrete de streak às 20h se o usuário ainda não registrou nada hoje.
  static Future<void> agendarLembreteStreak() async {
    if (!await _isEnabled('notif_streak')) return;

    await _plugin.zonedSchedule(
      _NId.streakLembrete,
      'Seu streak tá em risco! 🔥',
      'Você ainda não registrou nenhuma refeição hoje. Não deixa a sequência quebrar!',
      _nextTime(20, 0),
      NotificationDetails(
        android: _androidChannel('streak', 'Streak',
            importance: Importance.high, priority: Priority.high),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'nutricao',
    );
  }

  /// Cancela o lembrete de streak (chamar quando o usuário já registrou hoje).
  static Future<void> cancelarLembreteStreak() async {
    await _plugin.cancel(_NId.streakLembrete);
    // Reagendar para amanhã
    if (await _isEnabled('notif_streak')) agendarLembreteStreak();
  }

  /// Lembrete de hidratação — dispara uma vez, não repete automaticamente.
  static Future<void> notificarHidratacao() async {
    if (!await _isEnabled('notif_hidratacao')) return;

    await _plugin.show(
      _NId.hidratacaoLembrete,
      'Beba água! 💧',
      'Você já bebeu água hoje? Manter-se hidratado(a) melhora o humor e a energia.',
      NotificationDetails(
        android: _androidChannel('hidratacao', 'Hidratação'),
      ),
      payload: 'nutricao',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FINANCEIRO
  // ─────────────────────────────────────────────────────────────────────────

  /// Resumo financeiro toda segunda-feira às 9h.
  static Future<void> agendarResumoFinanceiro() async {
    if (!await _isEnabled('notif_financeiro')) return;

    final now = tz.TZDateTime.now(tz.local);
    // Próxima segunda-feira às 9h
    var dt = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0);
    while (dt.weekday != DateTime.monday || dt.isBefore(now)) {
      dt = dt.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _NId.resumoFinanceiro,
      'Semana nova, dinheiro organizado 💰',
      'Confira como estão seus envelopes esta semana.',
      dt,
      NotificationDetails(
        android: _androidChannel('financeiro', 'Resumo Financeiro'),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'financeiro',
    );
  }

  /// Alerta de conta próxima do vencimento.
  static Future<void> agendarAlertaConta({
    required int contaId,
    required String nomeConta,
    required double valor,
    required DateTime vencimento,
    int diasAntes = 2,
  }) async {
    if (!await _isEnabled('notif_contas')) return;

    final alertaEm = vencimento.subtract(Duration(days: diasAntes));
    if (alertaEm.isBefore(DateTime.now())) return;

    final tz.TZDateTime tzAlerta = tz.TZDateTime(
      tz.local,
      alertaEm.year, alertaEm.month, alertaEm.day, 9, 0,
    );

    final valorFmt = 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

    await _plugin.zonedSchedule(
      _NId.contaVencimento + contaId,
      'Conta vence em $diasAntes dias ⚠️',
      '$nomeConta — $valorFmt',
      tzAlerta,
      NotificationDetails(
        android: _androidChannel('contas', 'Contas a Pagar',
            importance: Importance.high),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'financeiro',
    );
  }

  static Future<void> cancelarAlertaConta(int contaId) async {
    await _plugin.cancel(_NId.contaVencimento + contaId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ASTRIX — celebração instantânea
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> notificarCelebracao(String titulo, String corpo) async {
    await _plugin.show(
      0,
      titulo,
      corpo,
      NotificationDetails(
        android: _androidChannel('astrix', 'Astrix 🦄',
            importance: Importance.high, priority: Priority.high),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cancelar tudo
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> cancelarTodos() => _plugin.cancelAll();

  /// Agenda todas as notificações padrão de uma vez.
  static Future<void> agendarTodas() async {
    await agendarLembretesRefeicao();
    await agendarLembreteStreak();
    await agendarResumoFinanceiro();
  }
}
