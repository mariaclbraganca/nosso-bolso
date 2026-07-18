import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared/error_state.dart';
import '../../constants.dart';
import '../../services/api_service.dart';
import '../../providers/usuarios_provider.dart';
import '../../providers/envelopes_provider.dart';
import '../../providers/fixos_provider.dart';
import '../../widgets/unicorn/unicorn_system.dart';
import 'form_gasto_sheet.dart';
import 'form_envelope_sheet.dart';
import 'remanejar_sheet.dart';
import 'abastecer_sheet.dart';

class EnvelopeDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> envelope;
  final bool isAdmin;

  const EnvelopeDetailSheet({
    super.key,
    required this.envelope,
    this.isAdmin = false,
  });

  @override
  ConsumerState<EnvelopeDetailSheet> createState() => _EnvelopeDetailSheetState();
}

class _EnvelopeDetailSheetState extends ConsumerState<EnvelopeDetailSheet> {
  final fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');

  @override
  Widget build(BuildContext context) {
    final id = widget.envelope['id'];
    final envelopesAsync = ref.watch(envelopesProvider);

    return envelopesAsync.when(
      data: (lista) {
        final env = lista.firstWhere((e) => e['id'] == id, orElse: () => widget.envelope);
        final saldo  = (env['saldo_atual'] as num).toDouble();
        final plan   = (env['valor_planejado'] as num).toDouble();
        final pct    = plan > 0 ? (saldo / plan).clamp(0.0, 1.0) : 0.0;
        final isNeg  = saldo < 0;
        final spent  = plan - saldo;

        Color barColor = AppColors.grn;
        if (isNeg) barColor = AppColors.red;
        else if (pct <= 0.2) barColor = AppColors.red;
        else if (pct <= 0.5) barColor = AppColors.org;

        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _header(env, barColor, isNeg, pct),
              _stats(saldo, plan, spent, barColor, pct),
              const Divider(color: AppColors.bord, height: 1),
              Expanded(child: _transactionList(id)),
              _bottomActions(id, env, barColor, isNeg),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 300,
        child: Center(child: UnicornLoading()),
      ),
      error: (e, _) => SizedBox(
        height: 200,
        child: ErrorState(
          mensagem: 'Não foi possível carregar os envelopes.',
          onRetry: () => ref.invalidate(envelopesProvider),
        ),
      ),
    );
  }

  Widget _header(Map<String, dynamic> env, Color color, bool isNeg, double pct) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2)),
            margin: const EdgeInsets.only(bottom: 20),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(env['emoji'] ?? '📦', style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(env['nome_envelope'] ?? '', style: AppTextStyles.title),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                        ),
                        child: Text(
                          isNeg ? 'NEGATIVO' : '${(pct * 100).toInt()}% restante',
                          style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  if (widget.isAdmin)
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => FormEnvelopeSheet(envelope: env),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined, color: AppColors.mu, size: 20),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.mu),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stats(double saldo, double plan, double spent, Color color, double pct) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _statCard('SALDO', fmt.format(saldo), color)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('META MENSAL', fmt.format(plan), AppColors.mu)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.bord,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${fmt.format(spent > 0 ? spent : 0)} gasto de ${fmt.format(plan)} planejado',
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
    ),
    child: Column(
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 6),
        Text(value, style: AppTextStyles.mono.copyWith(color: color, fontSize: 20)),
      ],
    ),
  );

  Widget _transactionList(String envelopeId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('transacoes')
          .stream(primaryKey: ['id'])
          .eq('envelope_id', envelopeId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.acc));
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const UnicornEmpty(
            type: UnicornType.astrix,
            title: 'Nenhuma transação',
            subtitle: 'Registre um gasto neste envelope',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(color: AppColors.bord, height: 1),
          itemBuilder: (context, i) {
            final t = list[i];
            return Dismissible(
              key: Key(t['id']),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _confirmDelete(t),
              onDismissed: (_) => HapticFeedback.mediumImpact(),
              background: Container(
                color: AppColors.red.withOpacity(0.1),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_outline, color: AppColors.red),
              ),
              child: _transactionItem(t),
            );
          },
        );
      },
    );
  }

  Widget _transactionItem(Map<String, dynamic> t) {
    final valor = (t['valor'] as num).toDouble();
    final isDsp  = t['tipo'] == 'despesa';
    final date   = DateFormat('dd/MM HH:mm').format(DateTime.parse(t['created_at']).toLocal());
    final color  = isDsp ? AppColors.red : AppColors.acc;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              isDsp ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: color, size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['descricao'] ?? (isDsp ? 'Gasto' : 'Abastecimento'), style: AppTextStyles.bodySm),
                const SizedBox(height: 2),
                Text(date, style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(
            '${isDsp ? '-' : '+'} ${fmt.format(valor)}',
            style: AppTextStyles.monoSm.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _bottomActions(String id, Map<String, dynamic> env, Color color, bool isNeg) {
    final saldoLivre = ref.watch(saldoLivreProvider);
    final temSaldoParaAbastecer = isNeg && saldoLivre > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: AppColors.surf,
        border: const Border(top: BorderSide(color: AppColors.bord, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (temSaldoParaAbastecer) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AbastecerSheet(),
                  );
                },
                icon: const Icon(Icons.savings_rounded, size: 18),
                label: Text(
                  'Abastecer do saldo disponível',
                  style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold.withOpacity(0.15),
                  foregroundColor: AppColors.gold,
                  elevation: 0,
                  side: const BorderSide(color: AppColors.gold, width: 0.8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => FormGastoSheet(initialEnvelopeId: id),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isNeg ? AppColors.red : AppColors.acc,
                    foregroundColor: AppColors.bg,
                    minimumSize: const Size.fromHeight(55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                  ),
                  child: const Text('+ Gasto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => RemanejSaldoSheet(origem: env),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.bord),
                    minimumSize: const Size.fromHeight(55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                  ),
                  child: Text('Mover', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(Map<String, dynamic> t) async {
    final valor = (t['valor'] as num).toDouble();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
        title: const Text('Excluir transação?', style: TextStyle(color: AppColors.tx)),
        content: Text(
          '${t['descricao'] ?? 'Transação'}\n${fmt.format(valor)}\n\nO saldo será restaurado automaticamente.',
          style: AppTextStyles.caption,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: AppTextStyles.caption)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    try {
      final perfil = ref.read(perfilUsuarioLogadoProvider).value;
      await ApiService.delete('/transacoes/${t['id']}', familiaId: perfil?['familia_id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transação excluída'), backgroundColor: AppColors.grn),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
        );
      }
      return false;
    }
  }
}
