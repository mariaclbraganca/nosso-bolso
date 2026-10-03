import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../core/providers/patrimonio_provider.dart';
import '../../../core/providers/pin_provider.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';
import '../sheets/comum.dart';
import 'widgets/form_patrimonio_sheet.dart';
import 'widgets/patrimonio_grafico.dart';
import 'widgets/patrimonio_ia_card.dart';
import 'widgets/patrimonio_pin_sheet.dart';

class PatrimonioTab extends ConsumerWidget {
  const PatrimonioTab({super.key});

  void _abrirPin(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NBColors.cartao,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const PatrimonioPinSheet(),
    );
  }

  void _abrirForm(BuildContext context, [Map<String, dynamic>? conta]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NBColors.cartao,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FormPatrimonioSheet(contaParaEditar: conta),
    );
  }

  Future<void> _excluirConta(BuildContext context, String id, String nome) async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NBColors.cartao,
        title: const Text('Excluir Ativo', style: TextStyle(color: NBColors.tinta)),
        content: Text('Deseja excluir "$nome" do seu patrimônio?', style: NBText.corpo),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: NBColors.estouro)),
          ),
        ],
      ),
    );
    if (conf == true) {
      try {
        await supabase.from('contas_patrimonio').delete().eq('id', id);
        avisar('Ativo excluído com sucesso.');
      } catch (e) {
        avisar(mensagemErro(e), erro: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configurado = ref.watch(pinConfiguradoProvider).valueOrNull ?? false;
    final desbloqueado = ref.watch(pinDesbloqueadoProvider);

    if (configurado && !desbloqueado) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(NBSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 56, color: NBColors.tintaSuave),
              const SizedBox(height: 16),
              Text('Patrimônio Protegido', style: NBText.tituloTela),
              const SizedBox(height: 8),
              const Text(
                'Digite seu PIN de segurança para visualizar seus investimentos e saldo consolidado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: NBColors.tintaSuave),
              ),
              const SizedBox(height: 24),
              BotaoPrincipal(rotulo: 'Desbloquear com PIN', onPressed: () => _abrirPin(context)),
            ],
          ),
        ),
      );
    }

    final contas = ref.watch(patrimonioProvider).valueOrNull ?? [];
    final total = ref.watch(totalPatrimonioProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 12, NBSpacing.margemTela, 120),
      children: [
        CartaoNB(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('PATRIMÔNIO LÍQUIDO CONSOLIDADO', style: NBText.eyebrow),
                  const Spacer(),
                  if (configurado)
                    IconButton(
                      icon: const Icon(Icons.lock_rounded, size: 18, color: NBColors.tintaSuave),
                      tooltip: 'Bloquear sessão',
                      onPressed: () => ref.read(pinNotifierProvider.notifier).bloquear(),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(brl(total), style: NBText.saldo.copyWith(color: NBColors.verde)),
            ],
          ),
        ),
        const SizedBox(height: NBSpacing.l),
        const PatrimonioGrafico(),
        const PatrimonioIaCard(),
        Row(
          children: [
            const Expanded(child: CabecalhoSecao(titulo: 'Bens e Contas')),
            if (!configurado)
              TextButton(
                onPressed: () => _abrirPin(context),
                child: const Text('Ativar PIN', style: TextStyle(color: NBColors.verde)),
              ),
          ],
        ),
        const SizedBox(height: NBSpacing.s),
        if (contas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: UnicornVazio(
              type: UnicornType.astrix,
              titulo: 'Nenhum ativo cadastrado',
              texto: 'Cadastre suas contas bancárias, imóveis e investimentos para acompanhar seu crescimento.',
            ),
          )
        else
          for (final c in contas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CartaoNB(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['nome'] as String? ?? 'Ativo', style: NBText.secao),
                          const SizedBox(height: 2),
                          Text((c['tipo'] as String? ?? 'outro').toUpperCase(), style: NBText.legenda),
                        ],
                      ),
                    ),
                    Text(
                      brl((c['saldo_atual'] as num?)?.toDouble() ?? 0.0),
                      style: NBText.valorCartao.copyWith(color: NBColors.tinta),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: NBColors.tintaSuave),
                      color: NBColors.cartao,
                      onSelected: (val) {
                        if (val == 'editar') _abrirForm(context, c);
                        if (val == 'excluir') _excluirConta(context, c['id'] as String, c['nome'] as String? ?? '');
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'editar', child: Text('Editar')),
                        const PopupMenuItem(
                          value: 'excluir',
                          child: Text('Excluir', style: TextStyle(color: NBColors.estouro)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: NBSpacing.m),
        BotaoSecundario(rotulo: '+ Adicionar Ativo / Conta', onPressed: () => _abrirForm(context)),
      ],
    );
  }
}
