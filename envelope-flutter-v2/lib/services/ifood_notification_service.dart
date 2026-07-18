import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import 'active_notifications_service.dart';
import 'nubank_notification_service.dart';

/// Ponto central de escuta de notificações.
/// Roteia para iFood e Nubank a partir de um único receivePort.
class IfoodNotificationService {
  static final _regexValor = RegExp(
    r'Compra de R\$\s*([\d.,]+) aprovada em (.+)\.',
    caseSensitive: false,
  );

  static bool _iniciado = false;

  static Future<void> init() async {
    if (_iniciado) return;
    _iniciado = true;

    await NotificationsListener.initialize(callbackHandle: _onNotificacao);

    NotificationsListener.receivePort?.listen((evt) {
      if (evt is NotificationEvent) _processarTodos(evt);
    });

    final temPermissao = await NotificationsListener.hasPermission ?? false;
    final running = await NotificationsListener.isRunning ?? false;

    await Sentry.captureMessage(
      '[NotificationListener] Status na inicialização: permissao=$temPermissao rodando=$running',
      level: temPermissao ? SentryLevel.info : SentryLevel.warning,
      withScope: (scope) {
        scope.setExtra('tem_permissao', temPermissao);
        scope.setExtra('servico_rodando', running);
      },
    );

    if (!running) {
      await NotificationsListener.startService(
        foreground: false,
        title: 'Nosso Bolso',
        description: 'Monitorando notificações financeiras',
      );
    }

    // Processa notificações que estão na bandeja e não foram capturadas pelo listener
    if (temPermissao) {
      ActiveNotificationsService.processarAtivas();
    }
  }

  @pragma('vm:entry-point')
  static void _onNotificacao(NotificationEvent evt) {
    _processarTodos(evt);
  }

  static Future<void> _processarTodos(NotificationEvent evt) async {
    await _processarIfood(evt);
    await NubankNotificationService.processar(evt);
  }

  static Future<void> _processarIfood(NotificationEvent evt) async {
    final pkg = evt.packageName ?? '';
    if (!pkg.contains('ifood')) return;

    final texto = evt.text ?? '';
    final match = _regexValor.firstMatch(texto);
    if (match == null) return;

    final valorStr = match.group(1)!.replaceAll('.', '').replaceAll(',', '.');
    final valor = double.tryParse(valorStr);
    if (valor == null || valor <= 0) return;

    final estabelecimento = match.group(2)!.trim();
    final hoje = DateTime.now().toIso8601String().substring(0, 10);

    debugPrint('[iFood] Capturado: $estabelecimento R\$$valor');
    await _enviarBackend(estabelecimento, valor, hoje);
  }

  static Future<void> _enviarBackend(
    String estabelecimento,
    double valor,
    String data,
  ) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      // familia_id vem do user_metadata gravado no login
      final familiaId =
          session.user.userMetadata?['familia_id'] as String? ?? '';
      if (familiaId.isEmpty) return;

      final uri = Uri.parse(
          '${ApiService.baseUrl}/api/v1/compras/notificacao-ifood');
      await http.post(
        uri,
        headers: ApiService.authHeaders(json: true),
        body: jsonEncode({
          'familia_id': familiaId,
          'estabelecimento': estabelecimento,
          'valor': valor,
          'data': data,
        }),
      );
    } catch (e) {
      debugPrint('[iFood] Erro ao enviar: $e');
    }
  }

  static Future<bool> temPermissao() async =>
      await NotificationsListener.hasPermission ?? false;

  static Future<void> solicitarPermissao() async =>
      NotificationsListener.openPermissionSettings();
}
