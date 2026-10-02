import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'nubank_notification_service.dart';

/// Lê notificações ATIVAS da bandeja usando MethodChannel para o Android nativo.
/// Chamado ao iniciar o app para processar notificações que chegaram enquanto
/// o app estava fechado ou o listener não estava ativo.
class ActiveNotificationsService {
  static const _channel = MethodChannel('com.nossabolso/active_notifications');

  static Future<void> processarAtivas() async {
    try {
      final List<dynamic> lista =
          await _channel.invokeMethod('getActiveNotifications') ?? [];

      int processadas = 0;
      for (final raw in lista) {
        final Map<String, dynamic> notif = Map<String, dynamic>.from(raw as Map);
        final pkg = notif['packageName'] as String? ?? '';
        if (pkg != 'com.nu.production') continue;

        // Prioriza tickerText (não bloqueado por vis=PRIVATE) — igual ao
        // listener em tempo real. Fallback: title + bigText/text.
        final ticker = (notif['tickerText'] as String?)?.trim() ?? '';
        final title = notif['title'] as String? ?? '';
        final text = (notif['bigText'] as String?) ?? (notif['text'] as String?) ?? '';
        final texto = ticker.isNotEmpty ? ticker : '$title $text'.trim();
        if (texto.isEmpty) continue;

        await NubankNotificationService.processarTexto(texto);
        processadas++;
      }

      if (processadas > 0) {
        await Sentry.captureMessage(
          '[ActiveNotif] $processadas notificações do Nubank processadas na abertura',
          level: SentryLevel.info,
          withScope: (s) =>
              s.setContexts('info', {'total_lidas': lista.length}),
        );
      }
    } on MissingPluginException {
      // Canal não disponível (ex: iOS ou Android < API 18)
    } catch (e, st) {
      await Sentry.captureException(e, stackTrace: st);
    }
  }
}
