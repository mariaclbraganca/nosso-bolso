import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/contas_provider.dart';
import '../../providers/mes_provider.dart';
import '../../services/financeiro_ext_service.dart';
import 'adicionar_conta_sheet.dart';

class ContasTab extends ConsumerWidget {
  const ContasTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesAtualProvider);
    final contasAsync = ref.watch(contasMesProvider(mes));
    final resumoAsync = ref.watch(resumoContasProvider(mes));

    Future<void> invalidar() async {
      ref.invalidate(contasMesProvider);
      ref.invalidate(resumoContasProvider);
    }

    void abrirAdicionar() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AdicionarContaSheet(mes: mes),
      ).then((saved) {
        if (saved == true) invalidar();
      });
    }

    Future<void> togglePago(Map<String, dynamic> conta) async {
      try {
        final pago = !(conta['pago'] as bool? ?? false);
        await FinanceiroExtService.marcarPaga(
            conta['_id'] as String, pago: pago);
        invalidar();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }

    Future<void> deletar(String id) async {
      try {
        await FinanceiroExtService.deletarConta(id);
        invalidar();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }

    return Stack(children: [
      RefreshIndicator(
        color: AppColors.acc,
        backgroundColor: AppColors.surf,
        onRefresh: invalidar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePad,
            AppSpacing.cardGap,
            AppSpacing.pagePad,
            100,
          ),
          children: [
            // Resumo
            resumoAsync.when(
              data: (r) => _ResumoCard(resumo: r),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // Header lista
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CONTAS DO MÊS',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                TextButton.icon(
                  onPressed: abrirAdicionar,
                  icon: const Icon(Icons.add_rounded,
                      size: 16, color: AppColors.acc),
                  label: Text('Adicionar',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.acc)),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize:
                          MaterialTapTargetSize.shrinkWrap),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.cardGap),

            // Lista de contas
            contasAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child:
                      CircularProgressIndicator(color: AppColors.acc),
                ),
              ),
              error: (e, _) => Center(
                child: Text('Erro: $e',
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.red)),
              ),
              data: (contas) {
                if (contas.isEmpty) {
                  return _EmptyState(onAdd: abrirAdicionar);
                }

                // Agrupa: pendentes primeiro, depois pagas
                final pendentes =
                    contas.where((c) => !(c['pago'] as bool? ?? false)).toList();
                final pagas =
                    contas.where((c) => c['pago'] as bool? ?? false).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pendentes.isNotEmpty) ...[
                      Text(
                        'PENDENTES (${pendentes.length})',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.org,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.cardGap),
                      ...pendentes.map((c) => _ContaTile(
                            conta: c,
                            onPagar: () => togglePago(c),
                            onDeletar: () =>
                                deletar(c['_id'] as String),
                          )),
                      const SizedBox(height: AppSpacing.sectionGap),
                    ],
                    if (pagas.isNotEmpty) ...[
                      Text(
                        'PAGAS (${pagas.length})',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.grn,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.cardGap),
                      ...pagas.map((c) => _ContaTile(
                            conta: c,
                            onPagar: () => togglePago(c),
                            onDeletar: () =>
                                deletar(c['_id'] as String),
                          )),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),

      // FAB
      Positioned(
        bottom: 24,
        right: AppSpacing.pagePad,
        child: FloatingActionButton(
          heroTag: 'contas_fab',
          onPressed: abrirAdicionar,
          backgroundColor: AppColors.acc,
          foregroundColor: AppColors.bg,
          child: const Icon(Icons.add_rounded),
        ),
      ),
    ]);
  }
}

// ── Resumo card ────────────────────────────────────────────────────────────────

class _ResumoCard extends StatelessWidget {
  final Map<String, dynamic> resumo;
  const _ResumoCard({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final total = (resumo['total'] as num?)?.toDouble() ?? 0;
    final pagas = (resumo['pagas'] as num?)?.toDouble() ?? 0;
    final pendentes = (resumo['pendentes'] as num?)?.toDouble() ?? 0;
    final vencidas = (resumo['vencidas'] as num?)?.toDouble() ?? 0;
    final pct = total > 0 ? (pagas / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Total do mês',
                    style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  'R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: AppTextStyles.mono,
                ),
              ]),
              if (vencidas > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.red.withOpacity(0.15),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    '⚠️ R\$ ${vencidas.toStringAsFixed(2).replaceAll('.', ',')} vencidas',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.red),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.surf,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.grn),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _Pill(
              '✅ R\$ ${pagas.toStringAsFixed(2).replaceAll('.', ',')} pagas',
              AppColors.grn,
            ),
            const SizedBox(width: 8),
            _Pill(
              '⏳ R\$ ${pendentes.toStringAsFixed(2).replaceAll('.', ',')} pendentes',
              AppColors.org,
            ),
          ]),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius:
              BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Text(
          text,
          style: AppTextStyles.caption.copyWith(color: color),
        ),
      );
}

// ── Conta tile com swipe ───────────────────────────────────────────────────────

class _ContaTile extends StatelessWidget {
  final Map<String, dynamic> conta;
  final VoidCallback onPagar;
  final VoidCallback onDeletar;
  const _ContaTile(
      {required this.conta, required this.onPagar, required this.onDeletar});

  @override
  Widget build(BuildContext context) {
    final nome = conta['nome'] as String? ?? '';
    final valor = (conta['valor'] as num?)?.toDouble() ?? 0;
    final venc = conta['vencimento'] as String? ?? '';
    final pago = conta['pago'] as bool? ?? false;
    final categoria = conta['categoria'] as String?;
    final emoji = emojiCategoria(categoria);

    final parts = venc.split('-');
    final vencFmt =
        parts.length == 3 ? '${parts[2]}/${parts[1]}' : venc;

    final hoje = DateTime.now();
    final vencDate =
        parts.length == 3 ? DateTime.tryParse(venc) : null;
    final vencida = !pago &&
        vencDate != null &&
        vencDate
            .isBefore(DateTime(hoje.year, hoje.month, hoje.day));

    Color borderColor = AppColors.bord;
    if (vencida) {
      borderColor = AppColors.red.withOpacity(0.4);
    } else if (pago) {
      borderColor = AppColors.grn.withOpacity(0.3);
    }

    return Dismissible(
      key: Key('conta_${conta['_id']}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDeletar();
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.red.withOpacity(0.15),
          borderRadius:
              BorderRadius.circular(AppSpacing.radiusCard),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Text(
          'Excluir 🗑️',
          style: AppTextStyles.bodySm.copyWith(
              color: AppColors.red, fontWeight: FontWeight.w700),
        ),
      ),
      child: GestureDetector(
        onTap: pago ? onPagar : () => _confirmarPagamento(context, onPagar, nome, valor),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius:
                BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Row(children: [
            // Checkbox circular
            GestureDetector(
              onTap: pago
                  ? onPagar
                  : () => _confirmarPagamento(
                      context, onPagar, nome, valor),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pago
                      ? AppColors.grn.withOpacity(0.2)
                      : AppColors.surf,
                  border: Border.all(
                      color:
                          pago ? AppColors.grn : AppColors.bord),
                ),
                child: pago
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: AppColors.grn)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('$emoji ', style: const TextStyle(fontSize: 14)),
                    Expanded(
                      child: Text(
                        nome,
                        style: AppTextStyles.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: pago ? AppColors.mu : AppColors.tx,
                          decoration: pago
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    'Vence $vencFmt${vencida ? ' · VENCIDA' : ''}',
                    style: AppTextStyles.caption.copyWith(
                      color: vencida ? AppColors.red : AppColors.mu,
                      fontWeight: vencida
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Valor
            Text(
              'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
              style: AppTextStyles.monoSm.copyWith(
                  color: pago ? AppColors.mu : AppColors.tx),
            ),
          ]),
        ),
      ),
    );
  }

  void _confirmarPagamento(BuildContext context, VoidCallback onConfirm,
      String nome, double valor) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
        title: Text('Marcar como paga?',
            style: AppTextStyles.titleSm),
        content: Text(
          '$nome\nR\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
          style:
              AppTextStyles.bodySm.copyWith(color: AppColors.mu),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: TextStyle(color: AppColors.mu)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.grn,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusBtn),
              ),
            ),
            child: const Text('Confirmar',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: 60, horizontal: 32),
          child: Column(
            children: [
              const Text('🧾', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 16),
              Text('Nenhuma conta este mês',
                  style: AppTextStyles.titleSm,
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                'Adicione suas contas para controlar vencimentos.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onAdd,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.acc,
                  side: const BorderSide(color: AppColors.acc),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        AppSpacing.radiusBtn),
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar conta'),
              ),
            ],
          ),
        ),
      );
}
