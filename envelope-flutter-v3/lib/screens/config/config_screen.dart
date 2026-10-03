import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/usuarios_provider.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../sheets/comum.dart';
import 'notificacoes_screen.dart';
import 'ia_config_screen.dart';
import 'pin_config_screen.dart';

/// Central de configurações da v3.
class ConfigScreen extends ConsumerWidget {
  const ConfigScreen({super.key});

  Future<void> _sair(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NBColors.cartao,
        title: Text('Sair da conta?', style: NBText.secao),
        content: Text('Você vai precisar entrar de novo para ver os envelopes.', style: NBText.corpo),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair', style: TextStyle(color: NBColors.estouro)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilUsuarioLogadoProvider).valueOrNull;
    final nome = (perfil?['nome'] as String?) ?? 'Você';
    final email = (perfil?['email'] as String?) ?? '';
    final familia = (perfil?['familias'] as Map?)?['nome'] as String?;
    final admin = perfil?['role'] == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
        children: [
          CartaoNB(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: NBColors.verde,
                  child: Text(nome.isEmpty ? '?' : nome[0].toUpperCase(),
                      style: NBText.secao.copyWith(color: Colors.white)),
                ),
                const SizedBox(width: NBSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome, style: NBText.secao, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (email.isNotEmpty) Text(email, style: NBText.legenda, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (familia != null) ...[
                        const SizedBox(height: 4),
                        SeloNB(admin ? 'Família $familia · admin' : 'Família $familia',
                            cor: NBColors.verde, fundo: NBColors.verdeClaro),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final secao in secoesConfig(context, ref)) ...[
            const SizedBox(height: NBSpacing.xl),
            Text(secao.titulo.toUpperCase(), style: NBText.eyebrow),
            const SizedBox(height: NBSpacing.s),
            CartaoNB(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < secao.itens.length; i++) ...[
                    if (i > 0) const Divider(indent: 56),
                    _LinhaConfig(item: secao.itens[i]),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: NBSpacing.xxl),
          OutlinedButton.icon(
            onPressed: () => _sair(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: NBColors.estouro,
              side: const BorderSide(color: NBColors.estouroClaro, width: 1.5),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sair da conta'),
          ),
        ],
      ),
    );
  }
}

class ItemConfig {
  const ItemConfig({required this.icone, required this.titulo, this.subtitulo, required this.abrir});
  final IconData icone;
  final String titulo;
  final String? subtitulo;
  final VoidCallback abrir;
}

class SecaoConfig {
  const SecaoConfig(this.titulo, this.itens);
  final String titulo;
  final List<ItemConfig> itens;
}

/// Seções da central. Cada funcionalidade nova entra aqui.
List<SecaoConfig> secoesConfig(BuildContext context, WidgetRef ref) {
  void abrir(Widget tela) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => tela));
  final admin = ref.watch(perfilUsuarioLogadoProvider).valueOrNull?['role'] == 'admin';
  return [
    SecaoConfig('Notificações', [
      ItemConfig(
        icone: Icons.notifications_active_outlined,
        titulo: 'Notificações e captura',
        subtitulo: 'Leitor do Nubank e iFood, lembretes e alarmes',
        abrir: () => abrir(const NotificacoesScreen()),
      ),
    ]),
    SecaoConfig('Inteligência', [
      ItemConfig(
        icone: Icons.auto_awesome_outlined,
        titulo: 'Inteligência artificial',
        subtitulo: 'Chaves do Gemini usadas pelo app',
        abrir: () => abrir(const IaConfigScreen()),
      ),
    ]),
    if (admin)
      SecaoConfig('Segurança', [
        ItemConfig(
          icone: Icons.lock_outline_rounded,
          titulo: 'PIN do Patrimônio',
          subtitulo: 'Criar, trocar ou remover',
          abrir: () => abrir(const PinConfigScreen()),
        ),
      ]),
  ];
}

class _LinhaConfig extends StatelessWidget {
  const _LinhaConfig({required this.item});
  final ItemConfig item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: item.abrir,
      leading: Icon(item.icone, color: NBColors.verde),
      title: Text(item.titulo, style: NBText.corpo.copyWith(fontWeight: FontWeight.w700)),
      subtitle: item.subtitulo == null ? null : Text(item.subtitulo!, style: NBText.legenda),
      trailing: const Icon(Icons.chevron_right_rounded, color: NBColors.tintaSuave),
      minVerticalPadding: 12,
    );
  }
}
