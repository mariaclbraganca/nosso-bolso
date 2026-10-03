import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/providers/usuarios_provider.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../sheets/comum.dart';

/// Família (código de convite, membros) e o próprio perfil (nome).
class PerfilFamiliaScreen extends ConsumerStatefulWidget {
  const PerfilFamiliaScreen({super.key});

  @override
  ConsumerState<PerfilFamiliaScreen> createState() => _PerfilFamiliaScreenState();
}

class _PerfilFamiliaScreenState extends ConsumerState<PerfilFamiliaScreen> {
  final _nome = TextEditingController();
  bool _salvando = false;
  bool _iniciado = false;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _salvarNome(String id) async {
    final nome = _nome.text.trim();
    if (nome.isEmpty) return avisar('O nome não pode ficar vazio.', erro: true);
    setState(() => _salvando = true);
    try {
      await supabase.from('usuarios').update({'nome': nome}).eq('id', id);
      await ref.read(perfilUsuarioLogadoProvider.notifier).recarregar();
      avisar('Nome atualizado.');
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _copiar(String codigo) async {
    await Clipboard.setData(ClipboardData(text: codigo));
    avisar('Código $codigo copiado.');
  }

  Future<void> _sairDaFamilia(String id, String familia) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NBColors.cartao,
        title: Text('Sair da família $familia?', style: NBText.secao),
        content: Text(
          'Você deixa de ver os envelopes e lançamentos dela. Para voltar, precisa do código de acesso.',
          style: NBText.corpo,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair da família', style: TextStyle(color: NBColors.estouro)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase.from('usuarios').update({'familia_id': null}).eq('id', id);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      await ref.read(perfilUsuarioLogadoProvider.notifier).recarregar();
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(perfilUsuarioLogadoProvider).valueOrNull;
    final membros = ref.watch(listaUsuariosProvider).valueOrNull ?? const [];
    if (perfil == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final id = perfil['id'] as String;
    final familia = (perfil['familias'] as Map?) ?? const {};
    final nomeFamilia = familia['nome'] as String? ?? 'Minha família';
    final codigo = familia['codigo_acesso'] as String?;
    if (!_iniciado) {
      _nome.text = perfil['nome'] as String? ?? '';
      _iniciado = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil e família')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
        children: [
          Text('FAMÍLIA', style: NBText.eyebrow),
          const SizedBox(height: NBSpacing.s),
          CartaoNB(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(nomeFamilia, style: NBText.secao),
                if (codigo != null) ...[
                  const SizedBox(height: NBSpacing.m),
                  Text('Código para convidar', style: NBText.legenda),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          codigo,
                          style: NBText.valorCartao.copyWith(letterSpacing: 4, color: NBColors.verde),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Copiar código',
                        onPressed: () => _copiar(codigo),
                        icon: const Icon(Icons.copy_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quem for entrar cria a conta no app e escolhe "Tenho um código".',
                    style: NBText.legenda,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: NBSpacing.xl),
          Text('MEMBROS (${membros.length})', style: NBText.eyebrow),
          const SizedBox(height: NBSpacing.s),
          CartaoNB(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < membros.length; i++) ...[
                  if (i > 0) const Divider(indent: 64),
                  _LinhaMembro(membro: membros[i], eu: membros[i]['id'] == id),
                ],
              ],
            ),
          ),
          const SizedBox(height: NBSpacing.xl),
          Text('SEU PERFIL', style: NBText.eyebrow),
          const SizedBox(height: NBSpacing.s),
          TextField(
            controller: _nome,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Seu nome'),
          ),
          if ((perfil['email'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: NBSpacing.s),
            Text('E-mail: ${perfil['email']}', style: NBText.legenda),
          ],
          const SizedBox(height: NBSpacing.m),
          BotaoPrincipal(rotulo: 'Salvar nome', carregando: _salvando, onPressed: () => _salvarNome(id)),
          const SizedBox(height: NBSpacing.x3),
          TextButton(
            onPressed: () => _sairDaFamilia(id, nomeFamilia),
            child: const Text('Sair desta família', style: TextStyle(color: NBColors.estouro)),
          ),
        ],
      ),
    );
  }
}

class _LinhaMembro extends StatelessWidget {
  const _LinhaMembro({required this.membro, required this.eu});
  final Map<String, dynamic> membro;
  final bool eu;

  @override
  Widget build(BuildContext context) {
    final nome = (membro['nome'] as String?)?.trim();
    final admin = membro['role'] == 'admin';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: admin ? NBColors.verde : NBColors.reserva,
        child: Text((nome == null || nome.isEmpty) ? '?' : nome[0].toUpperCase(),
            style: NBText.rotulo.copyWith(color: Colors.white)),
      ),
      title: Text(eu ? '${nome ?? 'Você'} (você)' : (nome ?? 'Sem nome'),
          style: NBText.corpo.copyWith(fontWeight: FontWeight.w700)),
      subtitle: (membro['email'] as String?) == null ? null : Text(membro['email'] as String, style: NBText.legenda),
      trailing: SeloNB(admin ? 'admin' : 'membro',
          cor: admin ? NBColors.verde : NBColors.tintaSuave, fundo: admin ? NBColors.verdeClaro : NBColors.afundado),
    );
  }
}
