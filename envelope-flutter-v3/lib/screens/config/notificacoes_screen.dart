import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/ifood_notification_service.dart';
import '../../core/services/notification_service.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';

/// Permissão do leitor de notificações (Nubank/iFood). O Android só concede
/// pela tela de sistema; ao voltar dela o status é conferido de novo.
final permissaoCapturaProvider = FutureProvider.autoDispose<bool>(
  (ref) => IfoodNotificationService.temPermissao(),
);

/// (notificações, alarmes exatos) — null quando o sistema não informa.
final permissoesSistemaProvider = FutureProvider.autoDispose<(bool?, bool?)>((ref) async => (
      await NotificationService.notificacoesPermitidas(),
      await NotificationService.alarmesExatosPermitidos(),
    ));

Future<void> pedirPermissoesSistema(WidgetRef ref) async {
  await NotificationService.pedirPermissoesAlarme();
  await NotificationService.agendarAlarmeFechamento();
  ref.invalidate(permissoesSistemaProvider);
}

Future<void> pedirPermissaoCaptura(WidgetRef ref) async {
  await IfoodNotificationService.solicitarPermissao();
  ref.invalidate(permissaoCapturaProvider);
}

class NotificacoesScreen extends ConsumerStatefulWidget {
  const NotificacoesScreen({super.key});

  @override
  ConsumerState<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends ConsumerState<NotificacoesScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(permissaoCapturaProvider);
      ref.invalidate(permissoesSistemaProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final captura = ref.watch(permissaoCapturaProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Notificações e captura')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
        children: [
          Text('CAPTURA AUTOMÁTICA', style: NBText.eyebrow),
          const SizedBox(height: NBSpacing.s),
          CartaoNB(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _LinhaCaptura(
                  nome: 'Nubank',
                  texto: 'Compras no cartão e Pix enviados viram gastos pendentes; Pix recebido vira receita.',
                  ativo: captura,
                ),
                const Divider(indent: 16),
                _LinhaCaptura(
                  nome: 'iFood Benefícios',
                  texto: 'Compras aprovadas viram gastos pendentes para escolher o envelope.',
                  ativo: captura,
                ),
              ],
            ),
          ),
          if (captura == false) ...[
            const SizedBox(height: NBSpacing.m),
            AvisoPermissaoCaptura(onConceder: () => pedirPermissaoCaptura(ref)),
          ],
          ...secoesNotificacoes(context, ref),
        ],
      ),
    );
  }
}

/// Seções extras desta tela (permissões do sistema, lembretes).
List<Widget> secoesNotificacoes(BuildContext context, WidgetRef ref) {
  final (notif, alarme) = ref.watch(permissoesSistemaProvider).valueOrNull ?? (null, null);
  final faltando = notif == false || alarme == false;
  return [
    const SizedBox(height: NBSpacing.xl),
    Text('PERMISSÕES DO SISTEMA', style: NBText.eyebrow),
    const SizedBox(height: NBSpacing.s),
    CartaoNB(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _LinhaCaptura(
            nome: 'Notificações',
            texto: 'Lembretes, contas a vencer e avisos dos unicórnios.',
            ativo: notif,
          ),
          const Divider(indent: 16),
          _LinhaCaptura(
            nome: 'Alarmes no horário exato',
            texto: 'Necessário para o alarme das 23h30 do fechamento do dia.',
            ativo: alarme,
          ),
        ],
      ),
    ),
    if (faltando) ...[
      const SizedBox(height: NBSpacing.m),
      FilledButton(
        onPressed: () => pedirPermissoesSistema(ref),
        child: const Text('Permitir notificações e alarmes'),
      ),
    ],
  ];
}

class _LinhaCaptura extends StatelessWidget {
  const _LinhaCaptura({required this.nome, required this.texto, required this.ativo});
  final String nome;
  final String texto;
  final bool? ativo;

  @override
  Widget build(BuildContext context) {
    final (rotulo, cor, fundo) = switch (ativo) {
      true => ('Ativa', NBColors.verde, NBColors.verdeClaro),
      false => ('Sem permissão', NBColors.estouro, NBColors.estouroClaro),
      null => ('Verificando…', NBColors.tintaSuave, NBColors.afundado),
    };
    return Padding(
      padding: const EdgeInsets.all(NBSpacing.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: NBText.corpo.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(texto, style: NBText.legenda),
              ],
            ),
          ),
          const SizedBox(width: NBSpacing.s),
          SeloNB(rotulo, cor: cor, fundo: fundo),
        ],
      ),
    );
  }
}

/// Aviso âmbar com o botão que abre a tela de "Acesso a notificações" do Android.
class AvisoPermissaoCaptura extends StatelessWidget {
  const AvisoPermissaoCaptura({super.key, required this.onConceder});
  final VoidCallback onConceder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NBSpacing.l),
      decoration: BoxDecoration(
        color: NBColors.ambarClaro,
        borderRadius: BorderRadius.circular(NBRadius.cartao),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Captura do Nubank e iFood desligada', style: NBText.rotulo.copyWith(color: NBColors.ambarTexto)),
          const SizedBox(height: 4),
          Text(
            'Para lançar compras e Pix sozinho, o app precisa de "Acesso a notificações". '
            'Na tela que abrir, ative o Nosso Bolso v3 e volte para cá.',
            style: NBText.corpo.copyWith(fontSize: 14, color: NBColors.tinta),
          ),
          const SizedBox(height: NBSpacing.m),
          FilledButton(onPressed: onConceder, child: const Text('Conceder permissão')),
        ],
      ),
    );
  }
}
