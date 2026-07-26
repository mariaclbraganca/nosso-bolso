import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import 'active_notifications_service.dart';
import 'nubank_notification_service.dart';
import 'notificacao_fila_service.dart';

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

    // Reenvia notificações que ficaram na fila (offline/sessão nula) na sessão
    // anterior. Fire-and-forget — não bloqueia o init.
    NotificacaoFilaService.flush();

    NotificationsListener.receivePort?.listen((evt) {
      if (evt is NotificationEvent) _processarTodos(evt);
    });

    final temPermissao = await NotificationsListener.hasPermission ?? false;
    final running = await NotificationsListener.isRunning ?? false;

    debugPrint('[NotificationListener] permissao=$temPermissao rodando=$running');
    // Sentry só quando FALTA permissão (problema real que impede a captura).
    if (!temPermissao) {
      await Sentry.captureMessage(
        '[NotificationListener] SEM permissão de acesso a notificações',
        level: SentryLevel.warning,
        withScope: (scope) =>
            scope.setContexts('info', {'servico_rodando': running}),
      );
    }

    if (!running) {
      await NotificationsListener.startService(
        // Foreground (não background): no Android 14+/16 o serviço em background
        // tem o binder derrubado ("Closing all transactions") e os eventos não
        // cruzam a ponte para o Dart. O manifest já declara foregroundServiceType
        // specialUse + a property, então o serviço foreground é o modo correto.
        foreground: true,
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
    final session = Supabase.instance.client.auth.currentSession;
    // familia_id vem do user_metadata gravado no login
    final familiaId =
        session?.user.userMetadata?['familia_id'] as String? ?? '';

    const endpoint = '/api/v1/compras/notificacao-ifood';
    final body = {
      'familia_id': familiaId,
      'estabelecimento': estabelecimento,
      'valor': valor,
      'data': data,
    };

    // Sem sessão/família ainda: enfileira p/ enviar quando logar/reconectar.
    if (session == null || familiaId.isEmpty) {
      await NotificacaoFilaService.enfileirar(endpoint, body);
      return;
    }

    try {
      final resp = await http
          .post(
            Uri.parse('${ApiService.baseUrl}$endpoint'),
            headers: ApiService.authHeaders(json: true),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode >= 500 ||
          resp.statusCode == 408 ||
          resp.statusCode == 429) {
        // Falha transitória do servidor → enfileira p/ retry.
        await NotificacaoFilaService.enfileirar(endpoint, body);
      } else {
        // Enviou (ou erro permanente): aproveita p/ drenar a fila acumulada.
        await NotificacaoFilaService.flush();
      }
    } catch (e) {
      // Rede caiu no meio → não perde a compra: enfileira.
      debugPrint('[iFood] Erro ao enviar, enfileirando: $e');
      await NotificacaoFilaService.enfileirar(endpoint, body);
    }
  }

  static Future<bool> temPermissao() async =>
      await NotificationsListener.hasPermission ?? false;

  static Future<void> solicitarPermissao() async =>
      NotificationsListener.openPermissionSettings();
}
