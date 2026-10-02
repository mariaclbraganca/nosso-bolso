import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../core/providers/metas_provider.dart';
import '../../../core/services/financeiro_ext_service.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';
import '../sheets/comum.dart';
import 'widgets/form_meta_sheet.dart';
import 'widgets/meta_aporte_sheet.dart';
import 'widgets/metas_card.dart';

class MetasTab extends ConsumerWidget {
  const MetasTab({super.key});

  Future<void> _excluirMeta(WidgetRef ref, BuildContext context, String id) async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NBColors.cartao,
        title: const Text('Excluir Meta', style: TextStyle(color: NBColors.tinta)),
        content: Text('Deseja realmente excluir esta meta?', style: NBText.corpo),
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
        try {
          await FinanceiroExtService.deletarMeta(id);
        } catch (_) {
          await supabase.from('metas_economia').delete().eq('id', id);
        }
        ref.invalidate(metasProvider);
        avisar('Meta excluída.');
      } catch (e) {
        avisar(mensagemErro(e), erro: true);
      }
    }
  }

  void _abrirNovaMeta(BuildContext context, WidgetRef ref) async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NBColors.cartao,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const FormMetaSheet(),
    );
    if (res == true) ref.invalidate(metasProvider);
  }

  void _abrirAporte(BuildContext context, WidgetRef ref, Map<String, dynamic> meta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NBColors.cartao,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MetaAporteSheet(meta: meta),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metasAsync = ref.watch(metasProvider);

    return metasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: NBColors.verde)),
      error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: NBColors.estouro))),
      data: (metas) {
        final totalAcumulado = metas.fold(0.0, (sum, m) => sum + ((m['valor_atual'] as num?)?.toDouble() ?? 0.0));
        final totalAlvo = metas.fold(0.0, (sum, m) => sum + ((m['valor_alvo'] as num?)?.toDouble() ?? 0.0));

        return ListView(
          padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 12, NBSpacing.margemTela, 120),
          children: [
            CartaoNB(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('RESERVAS & METAS', style: NBText.eyebrow),
                      const Spacer(),
                      const SeloNB(
                        'POUPANÇA ATIVA',
                        cor: NBColors.verde,
                        fundo: NBColors.verdeClaro,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total poupado', style: NBText.legenda),
                            const SizedBox(height: 2),
                            Text(brl(totalAcumulado), style: NBText.valorCartao.copyWith(color: NBColors.verde)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Objetivo total', style: NBText.legenda),
                          const SizedBox(height: 2),
                          Text(brl(totalAlvo), style: NBText.valorCartao.copyWith(fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: NBSpacing.l),
            const CabecalhoSecao(titulo: 'Seus Objetivos'),
            const SizedBox(height: NBSpacing.s),
            if (metas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: UnicornVazio(
                  type: UnicornType.sweet,
                  titulo: 'Nenhuma meta definida',
                  texto: 'Crie metas de curto e longo prazo para realizar seus sonhos!',
                ),
              )
            else
              for (final m in metas)
                MetasCard(
                  meta: m,
                  onAportar: () => _abrirAporte(context, ref, m),
                  onExcluir: () => _excluirMeta(ref, context, m['id'] as String),
                ),
            const SizedBox(height: NBSpacing.m),
            BotaoSecundario(
              rotulo: '+ Nova Meta Financeira',
              onPressed: () => _abrirNovaMeta(context, ref),
            ),
          ],
        );
      },
    );
  }
}
