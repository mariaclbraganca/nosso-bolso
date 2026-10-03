import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    const _SecaoLembretes(),
  ];
}

/// Um lembrete que a pessoa pode ligar/desligar. [aplicar] reagenda ou cancela.
class _Lembrete {
  const _Lembrete(this.chave, this.titulo, this.quando, this.aplicar);
  final String chave;
  final String titulo;
  final String quando;
  final Future<void> Function(bool ligado) aplicar;
}

final _grupos = <(String, List<_Lembrete>)>[
  ('LEMBRETES DE SAÚDE', [
    _Lembrete('notif_cafe', 'Café da manhã', 'Às 7h30', (_) => NotificationService.agendarLembretesRefeicao()),
    _Lembrete('notif_almoco', 'Almoço', 'Às 12h00', (_) => NotificationService.agendarLembretesRefeicao()),
    _Lembrete('notif_lanche', 'Lanche da tarde', 'Às 15h30', (_) => NotificationService.agendarLembretesRefeicao()),
    _Lembrete('notif_jantar', 'Jantar', 'Às 19h00', (_) => NotificationService.agendarLembretesRefeicao()),
    _Lembrete('notif_streak', 'Sequência de registros', 'Às 20h se ainda não registrou nada no dia',
        (on) => on ? NotificationService.agendarLembreteStreak() : NotificationService.cancelarLembreteStreak()),
    _Lembrete('notif_hidratacao', 'Hidratação', 'Quando ainda não registrou água no dia', (_) async {}),
  ]),
  ('LEMBRETES DO DINHEIRO', [
    _Lembrete('notif_fechamento_dia', 'Alarme do fechamento do dia', 'Todo dia às 23h30',
        (_) => NotificationService.agendarAlarmeFechamento()),
    _Lembrete('notif_financeiro', 'Resumo semanal', 'Segunda-feira às 9h, como estão os envelopes',
        (on) => on ? NotificationService.agendarResumoFinanceiro() : NotificationService.cancelarResumoFinanceiro()),
    _Lembrete('notif_contas', 'Contas a vencer', '2 dias antes de cada vencimento', (_) async {}),
    _Lembrete('notif_envelope_negativo', 'Envelope no vermelho', 'Quando um envelope fica negativo', (_) async {}),
  ]),
];

class _SecaoLembretes extends StatefulWidget {
  const _SecaoLembretes();

  @override
  State<_SecaoLembretes> createState() => _SecaoLembretesState();
}

class _SecaoLembretesState extends State<_SecaoLembretes> {
  Map<String, bool>? _ligado;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() => _ligado = {
            for (final (_, itens) in _grupos)
              for (final l in itens) l.chave: p.getBool(l.chave) ?? true,
          });
    });
  }

  Future<void> _alternar(_Lembrete l, bool valor) async {
    setState(() => _ligado![l.chave] = valor);
    await NotificationService.setEnabled(l.chave, valor);
    await l.aplicar(valor);
  }

  @override
  Widget build(BuildContext context) {
    final ligado = _ligado;
    if (ligado == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (titulo, itens) in _grupos) ...[
          const SizedBox(height: NBSpacing.xl),
          Text(titulo, style: NBText.eyebrow),
          const SizedBox(height: NBSpacing.s),
          CartaoNB(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < itens.length; i++) ...[
                  if (i > 0) const Divider(indent: 16),
                  SwitchListTile(
                    value: ligado[itens[i].chave] ?? true,
                    onChanged: (v) => _alternar(itens[i], v),
                    activeThumbColor: NBColors.verde,
                    title: Text(itens[i].titulo, style: NBText.corpo.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text(itens[i].quando, style: NBText.legenda),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
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
