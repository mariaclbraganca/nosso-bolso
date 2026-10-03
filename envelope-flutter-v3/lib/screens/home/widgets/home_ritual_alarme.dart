import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../../../ui/theme/nb_theme.dart';

const _kPermissaoPedida = 'alarme_fechamento_permissao';

/// Se o app foi aberto pelo alarme, vai direto ao fechamento do dia (o tap
/// com o app fechado não passa pelo onDidReceiveNotificationResponse).
/// Senão, na primeira abertura explica o alarme das 23h30 e pede as
/// permissões (notificações, alarme exato, tela cheia) que ele precisa.
Future<void> prepararAlarmeFechamento(BuildContext context) async {
  try {
    await _preparar(context);
  } catch (e) {
    debugPrint('[Alarme] preparo ignorado: $e'); // plugin ausente (testes, web)
  }
}

Future<void> _preparar(BuildContext context) async {
  if (await NotificationService.lancadoPeloAlarme()) {
    NotificationService.abrirFechamentoDia();
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kPermissaoPedida) == true || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: NBColors.cartao,
      title: Text('Alarme das 23h30', style: NBText.secao),
      content: Text(
        'Todo dia às 23h30 o celular toca para a família fechar o dia: conferir os gastos '
        'e confirmar os envelopes. Leva 30 segundos.\n\n'
        'Na próxima tela, permita notificações, alarmes e tela cheia.',
        style: NBText.corpo,
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ativar'))],
    ),
  );
  await NotificationService.pedirPermissoesAlarme();
  await NotificationService.agendarAlarmeFechamento();
  await prefs.setBool(_kPermissaoPedida, true);
}
