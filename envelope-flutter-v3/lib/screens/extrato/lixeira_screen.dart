import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/providers/usuarios_provider.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';

final lixeiraProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  if (perfil == null || perfil['familia_id'] == null) return [];

  final res = await supabase
      .from('transacoes')
      .select('*, envelopes(nome_envelope, emoji)')
      .eq('familia_id', perfil['familia_id'])
      .not('deleted_at', 'is', null)
      .order('deleted_at', ascending: false)
      .limit(100);

  return List<Map<String, dynamic>>.from(res);
});

class LixeiraScreen extends ConsumerWidget {
  const LixeiraScreen({super.key});

  Future<void> _esvaziar(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> itens) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NBColors.cartao,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NBRadius.cartao)),
        title: Text('Esvaziar lixeira?', style: NBText.secao),
        content: Text(
          'Deseja excluir permanentemente todas as ${itens.length} transações? Esta ação não pode ser desfeita.',
          style: NBText.corpo.copyWith(color: NBColors.tintaSuave),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NBColors.estouro),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Esvaziar tudo'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      final ids = itens.map((e) => e['id']?.toString()).whereType<String>().toList();
      await supabase.from('transacoes').delete().inFilter('id', ids);
      ref.invalidate(lixeiraProvider);
      HapticFeedback.heavyImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lixeira esvaziada com sucesso.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: NBColors.estouro),
        );
      }
    }
  }

  Future<void> _restaurar(BuildContext context, WidgetRef ref, String id) async {
    await supabase.from('transacoes').update({'deleted_at': null}).eq('id', id);
    ref.invalidate(lixeiraProvider);
    HapticFeedback.mediumImpact();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transação restaurada!')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lixeiraAsync = ref.watch(lixeiraProvider);
    final fmtData = DateFormat('dd/MM HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lixeira'),
        actions: [
          lixeiraAsync.maybeWhen(
            data: (itens) => itens.isNotEmpty
                ? TextButton.icon(
                    icon: const Icon(Icons.delete_sweep_rounded, color: NBColors.estouro, size: 18),
                    label: Text('Esvaziar', style: NBText.rotulo.copyWith(color: NBColors.estouro)),
                    onPressed: () => _esvaziar(context, ref, itens),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: lixeiraAsync.when(
        loading: () => const UnicornCarregando(texto: 'Carregando itens apagados…'),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (itens) {
          if (itens.isEmpty) {
            return const UnicornVazio(
              type: UnicornType.astrix,
              titulo: 'Lixeira vazia',
              texto: 'Transações que você excluir aparecerão aqui.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(NBSpacing.margemTela),
            itemCount: itens.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final t = itens[i];
              final id = t['id'].toString();
              final desc = (t['descricao'] as String?)?.trim();
              final valor = (t['valor'] as num?)?.toDouble() ?? 0.0;
              final env = (t['envelopes'] as Map?)?['nome_envelope'] as String? ?? 'Sem envelope';
              final deleted = DateTime.tryParse(t['deleted_at']?.toString() ?? '');

              return CartaoNB(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            desc != null && desc.isNotEmpty ? desc : env,
                            style: NBText.corpo.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: NBColors.tintaSuave,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            deleted != null ? 'Excluído em ${fmtData.format(deleted)}' : env,
                            style: NBText.legenda,
                          ),
                        ],
                      ),
                    ),
                    Text(brl(valor), style: NBText.valorCartao.copyWith(fontSize: 15)),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Restaurar',
                      icon: const Icon(Icons.restore_from_trash_rounded, color: NBColors.verde),
                      onPressed: () => _restaurar(context, ref, id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
