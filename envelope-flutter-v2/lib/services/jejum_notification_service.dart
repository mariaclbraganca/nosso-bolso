import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../providers/jejum_provider.dart';

/// Notificações do jejum (Android):
/// - Persistente do timer ativo, com ações inline (Encerrar / Abrir).
/// - Marcos agendados localmente (12h, 16h, hidratação a cada 2h, janela abre/fecha).
/// - Canal de Fast Together (FCM) para incentivos do parceiro.
///
/// Marcos usam agendamento LOCAL (zonedSchedule) — disparam no horário exato
/// mesmo com o app fechado, sem depender de rede.
class JejumNotificationService {
  static const _idTimer = 7401;
  static const _baseMarcos = 7500; // ids 7500..7599 reservados aos marcos

  static final _plugin = FlutterLocalNotificationsPlugin();
  static Timer? _tick;
  static bool _inicializado = false;

  /// Handler para taps em ações — setado pelo app na inicialização, se quiser.
  static void Function(String? actionId)? onAcao;

  static Future<void> _garantirInit() async {
    if (_inicializado) return;
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (resp) {
        onAcao?.call(resp.actionId ?? resp.payload);
      },
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      // Canais por tipo/cor (o Android precisa conhecê-los previamente)
      const canais = [
        AndroidNotificationChannel('jejum_timer', 'Timer de jejum',
            description: 'Progresso do jejum em andamento',
            importance: Importance.low),
        AndroidNotificationChannel('jejum_marco', 'Marcos do jejum',
            description: 'Avisos de fases metabólicas (12h, 16h…)',
            importance: Importance.high),
        AndroidNotificationChannel('jejum_hidratacao', 'Hidratação no jejum',
            description: 'Lembretes de água durante o jejum',
            importance: Importance.defaultImportance),
        AndroidNotificationChannel('jejum_janela', 'Janela alimentar',
            description: 'Avisos de abertura e fechamento da janela',
            importance: Importance.high),
        AndroidNotificationChannel('jejum_motivacao', 'Fast Together',
            description: 'Incentivos do seu parceiro de jejum',
            importance: Importance.high),
      ];
      for (final c in canais) {
        await android.createNotificationChannel(c);
      }
    }
    _inicializado = true;
  }

  // ── Persistente do timer ────────────────────────────────────────────────────

  static Future<void> iniciar(Map<String, dynamic> registro) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _garantirInit();

    final inicio = DateTime.tryParse(registro['iniciado_em'] ?? '')?.toLocal();
    if (inicio == null) return;
    final metaHoras = (registro['meta_horas'] as num?)?.toDouble();

    await _mostrar(inicio, metaHoras);
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      _mostrar(inicio, metaHoras);
    });

    // Agenda os marcos com base na config de notificação
    final notifCfg = (registro['notif_config'] as Map?)?.cast<String, dynamic>();
    await agendarMarcos(
      inicio: inicio,
      metaHoras: metaHoras,
      horaFimJanela: registro['janela_fim'] as String?,
      config: notifCfg,
    );
  }

  static Future<void> encerrar() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _tick?.cancel();
    _tick = null;
    await _plugin.cancel(_idTimer);
    await cancelarMarcos();
  }

  static Future<void> _mostrar(DateTime inicio, double? metaHoras) async {
    final decorrido = DateTime.now().difference(inicio);
    final fase = FaseMetabolica.atual(decorrido);
    final h = decorrido.inHours;
    final m = (decorrido.inMinutes % 60).toString().padLeft(2, '0');

    final progresso = metaHoras != null && metaHoras > 0
        ? (decorrido.inMinutes / (metaHoras * 60) * 100).clamp(0, 100).toInt()
        : null;

    await _plugin.show(
      _idTimer,
      '⏱ ${h}h${m}min de jejum',
      progresso != null
          ? '${fase.emoji} ${fase.nome} · $progresso% da meta'
          : '${fase.emoji} ${fase.nome}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'jejum_timer', 'Timer de jejum',
          channelDescription: 'Progresso do jejum em andamento',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: false,
          showProgress: progresso != null,
          maxProgress: 100,
          progress: progresso ?? 0,
          // Ações inline — aparecem na shade e na lock screen
          actions: const [
            AndroidNotificationAction('jejum_encerrar', '⏹ Encerrar'),
            AndroidNotificationAction('jejum_abrir', 'Abrir app'),
          ],
        ),
      ),
    );
  }

  // ── Marcos agendados ────────────────────────────────────────────────────────

  static Future<void> agendarMarcos({
    required DateTime inicio,
    double? metaHoras,
    String? horaFimJanela,
    Map<String, dynamic>? config,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _garantirInit();
    await cancelarMarcos();

    final cfg = config ?? const {};
    bool on(String k, {bool padrao = true}) => cfg[k] as bool? ?? padrao;

    var id = _baseMarcos;
    Future<void> agenda(DateTime quando, String canal, String titulo,
        String corpo) async {
      if (quando.isBefore(DateTime.now())) return;
      try {
        await _plugin.zonedSchedule(
          id++,
          titulo,
          corpo,
          tz.TZDateTime.from(quando, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              canal, canal,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        // Nunca deixa o agendamento de um marco derrubar o fluxo do jejum
        // (ex.: exact_alarms_not_permitted em alguns aparelhos).
        debugPrint('[Jejum] Falha ao agendar marco "$titulo": $e');
      }
    }

    // Marco 12h — queima de gordura
    if (on('marco_12h')) {
      await agenda(inicio.add(const Duration(hours: 12)), 'jejum_marco',
          '🔥 Queima de gordura ativada!',
          'Hora 12 — lipólise ativa. Seu corpo mudou de combustível agora.');
    }
    // Marco 16h — autofagia
    if (on('marco_16h')) {
      await agenda(inicio.add(const Duration(hours: 16)), 'jejum_marco',
          '✨ 16h — Autofagia iniciando',
          'Reparação celular em curso. Você chegou lá!');
    }
    // Hidratação a cada 2h (até 12h de jejum)
    if (on('hidratacao')) {
      for (var horas = 2; horas <= 12; horas += 2) {
        await agenda(inicio.add(Duration(hours: horas)), 'jejum_hidratacao',
            '💧 Hora de hidratar',
            'Hora $horas do jejum — 500ml agora. A fome vai ceder em 20min.');
      }
    }
    // Janela abre (quando a meta é atingida)
    if (on('janela_abre') && metaHoras != null && metaHoras > 0) {
      final abertura =
          inicio.add(Duration(minutes: (metaHoras * 60).round() - 30));
      await agenda(abertura, 'jejum_janela',
          '🍽️ Sua janela abre em 30 minutos',
          'Prepare sua refeição — priorize proteína para fechar a meta do dia.');
    }
    // Janela fecha (1h antes do horário de fim)
    if (on('janela_fecha') && horaFimJanela != null) {
      final fecha = _proximoHorario(horaFimJanela)
          ?.subtract(const Duration(hours: 1));
      if (fecha != null) {
        await agenda(fecha, 'jejum_janela', '⏰ Janela fecha em 1h',
            'Última hora da sua janela alimentar. Aproveite agora.');
      }
    }
  }

  static Future<void> cancelarMarcos() async {
    for (var i = _baseMarcos; i < _baseMarcos + 100; i++) {
      await _plugin.cancel(i);
    }
  }

  /// Próxima ocorrência de "HH:MM" a partir de agora.
  static DateTime? _proximoHorario(String hhmm) {
    if (!hhmm.contains(':')) return null;
    final p = hhmm.split(':');
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    final agora = DateTime.now();
    var alvo = DateTime(agora.year, agora.month, agora.day, h, m);
    if (alvo.isBefore(agora)) alvo = alvo.add(const Duration(days: 1));
    return alvo;
  }
}
