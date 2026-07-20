import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/usuarios_provider.dart';
import '../../widgets/shared/error_state.dart';
import '../../services/api_service.dart';
import '../../constants.dart';

/// Provider para transações deletadas (soft-delete)
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

/// Tela de lixeira — sem AppBar próprio.
/// Empilhada via Navigator.push de dentro do Extrato.
class LixeiraScreen extends ConsumerWidget {
  const LixeiraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lixeiraAsync = ref.watch(lixeiraProvider);
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final fmtData = DateFormat('dd/MM/yy HH:mm');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surf,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: AppColors.red, size: 20),
            const SizedBox(width: 8),
            Text('Lixeira', style: AppTextStyles.titleSm),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.tx, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.bord),
        ),
      ),
      body: lixeiraAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_sweep_outlined,
                    color: AppColors.mu, size: 64),
                  const SizedBox(height: 16),
                  Text('Lixeira vazia',
                    style: AppTextStyles.titleSm.copyWith(color: AppColors.mu)),
                  const SizedBox(height: 8),
                  Text('Itens excluídos aparecem aqui',
                    style: AppTextStyles.caption),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePad, AppSpacing.sectionGap,
              AppSpacing.pagePad, 80,
            ),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
              const SizedBox(height: AppSpacing.cardGap),
            itemBuilder: (context, index) {
              final t = items[index];
              final val = (t['valor'] as num?)?.toDouble() ?? 0;
              final desc = t['descricao']?.toString() ?? '—';
              final tipo = t['tipo']?.toString() ?? 'despesa';
              final deletedAt = t['deleted_at']?.toString() ?? '';
              final envNome = (t['envelopes']?['nome_envelope'] as String?)
                  ?? 'Sem envelope';
              final envEmoji = (t['envelopes']?['emoji'] as String?) ?? '💰';

              DateTime? deletedDt;
              try {
                deletedDt = DateTime.parse(deletedAt).toLocal();
              } catch (_) {}

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  border: Border.all(color: AppColors.bord, width: 0.5),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Emoji envelope
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(envEmoji,
                              style: const TextStyle(fontSize: 20)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(desc,
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.mu,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(envNome, style: AppTextStyles.caption),
                                if (deletedDt != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Excluído em ${fmtData.format(deletedDt)}',
                                    style: AppTextStyles.caption
                                        .copyWith(color: AppColors.red.withOpacity(0.7)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            fmt.format(val),
                            style: AppTextStyles.monoSm.copyWith(
                              color: tipo == 'receita'
                                  ? AppColors.grn
                                  : AppColors.mu,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 0),
                    // Ações
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => _restaurar(context, ref, t),
                            icon: const Icon(Icons.restore_rounded,
                              size: 16, color: AppColors.acc),
                            label: Text('Restaurar',
                              style: AppTextStyles.bodySm
                                  .copyWith(color: AppColors.acc)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        Container(width: 0.5, height: 40, color: AppColors.bord),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => _excluirPermanente(context, ref, t),
                            icon: const Icon(Icons.delete_forever_rounded,
                              size: 16, color: AppColors.red),
                            label: Text('Excluir',
                              style: AppTextStyles.bodySm
                                  .copyWith(color: AppColors.red)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.acc, strokeWidth: 2),
        ),
        error: (e, _) => ErrorState(
          mensagem: 'Não foi possível carregar a lixeira.',
          onRetry: () => ref.invalidate(lixeiraProvider),
        ),
      ),
    );
  }

  Future<void> _restaurar(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> t,
  ) async {
    final id = t['id']?.toString();
    if (id == null) return;

    try {
      // Via API: o backend restaura no Supabase E ressincroniza o MongoDB
      // (_sync_mongo_restaurar). Update direto deixaria a compra órfã.
      await ApiService.post('/transacoes/$id/restaurar', {})
          .timeout(const Duration(seconds: 30));

      ref.invalidate(lixeiraProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transação restaurada',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.tx)),
            backgroundColor: AppColors.grn,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao restaurar: $e',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.tx)),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _excluirPermanente(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> t,
  ) async {
    final id = t['id']?.toString();
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: const BorderSide(color: AppColors.bord, width: 0.5),
        ),
        title: Text('Excluir permanentemente?',
          style: AppTextStyles.titleSm),
        content: Text(
          'Esta ação não pode ser desfeita. A transação será removida para sempre.',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: AppTextStyles.bodySm),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Excluir',
              style: AppTextStyles.bodySm.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Via API: hard-delete no Supabase + limpeza do vínculo no MongoDB.
      await ApiService.delete('/transacoes/$id/permanente')
          .timeout(const Duration(seconds: 30));

      ref.invalidate(lixeiraProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transação excluída permanentemente',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.tx)),
            backgroundColor: AppColors.surf,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.tx)),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }
}
