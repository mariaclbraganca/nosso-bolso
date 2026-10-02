import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/usuarios_provider.dart';
import '../../core/services/app_navigator.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';

void avisar(String texto, {bool erro = false}) {
  scaffoldMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: erro ? NBColors.estouro : NBColors.tinta,
    ));
}

/// Perfil logado obrigatório para gravar (id + familia_id).
Map<String, dynamic> perfilOuErro(WidgetRef ref) {
  final p = ref.read(perfilUsuarioLogadoProvider).value;
  if (p == null || p['familia_id'] == null) {
    throw Exception('Sessão expirada. Entre de novo para continuar.');
  }
  return p;
}

String mensagemErro(Object e) {
  final s = e.toString();
  return s.startsWith('Exception: ') ? s.substring(11) : s;
}

/// Casca padrão dos sheets: rolagem + margens + botão principal fixo no fim.
class CascaSheet extends StatelessWidget {
  const CascaSheet({super.key, required this.filhos, required this.botao});
  final List<Widget> filhos;
  final Widget botao;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 0, NBSpacing.margemTela, NBSpacing.l),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: filhos),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 0, NBSpacing.margemTela, NBSpacing.l),
              child: botao,
            ),
          ),
        ],
      ),
    );
  }
}

class BotaoPrincipal extends StatelessWidget {
  const BotaoPrincipal({super.key, required this.rotulo, required this.onPressed, this.carregando = false, this.cor});
  final String rotulo;
  final VoidCallback? onPressed;
  final bool carregando;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: carregando ? null : onPressed,
      style: cor == null ? null : FilledButton.styleFrom(backgroundColor: cor),
      child: carregando
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
          : Text(rotulo, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class BotaoSecundario extends StatelessWidget {
  const BotaoSecundario({super.key, required this.rotulo, required this.onPressed});
  final String rotulo;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: NBColors.tinta,
        side: const BorderSide(color: NBColors.linha),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NBRadius.campo)),
      ),
      child: Text(rotulo),
    );
  }
}

/// Lista horizontal de envelopes com saldo, para escolher um.
class SeletorEnvelope extends StatelessWidget {
  const SeletorEnvelope({
    super.key,
    required this.envelopes,
    required this.selecionadoId,
    required this.onSelect,
    this.excluirId,
  });

  final List<Map<String, dynamic>> envelopes;
  final String? selecionadoId;
  final ValueChanged<String> onSelect;
  final String? excluirId;

  @override
  Widget build(BuildContext context) {
    final lista = envelopes.where((e) => e['id'] != excluirId && e['deleted_at'] == null).toList();
    if (lista.isEmpty) {
      return Text('Nenhum envelope ainda. Crie um em Planos.', style: NBText.legenda);
    }
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: lista.length,
        separatorBuilder: (_, __) => const SizedBox(width: NBSpacing.s),
        itemBuilder: (_, i) {
          final e = EstadoEnvelope(lista[i]);
          final id = lista[i]['id'] as String;
          final sel = id == selecionadoId;
          return SizedBox(
            width: 128,
            child: CartaoNB(
              onTap: () => onSelect(id),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              borda: sel ? NBColors.tinta : NBColors.linha,
              larguraBorda: sel ? 2 : 1,
              cor: sel ? NBColors.papel : NBColors.cartao,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: e.natureza.forte, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(e.nome, style: NBText.rotulo, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 4),
                  Text(brl(e.saldo),
                      style: NBText.corpo.copyWith(
                          fontWeight: FontWeight.w700, color: e.estourado ? NBColors.estouro : NBColors.tintaSuave)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class Rotulo extends StatelessWidget {
  const Rotulo(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: NBSpacing.s),
        child: Text(texto, style: NBText.rotulo.copyWith(color: NBColors.tintaSuave)),
      );
}
