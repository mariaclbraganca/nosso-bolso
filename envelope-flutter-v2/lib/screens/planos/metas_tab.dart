import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/metas_provider.dart';
import '../../widgets/shared/error_state.dart';
import '../../services/financeiro_ext_service.dart';
import '../../widgets/unicorn/unicorn_system.dart';
import 'adicionar_meta_sheet.dart';

class MetasTab extends ConsumerWidget {
  const MetasTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metasAsync = ref.watch(metasProvider);

    void abrirAdicionar() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AdicionarMetaSheet(),
      ).then((saved) {
        if (saved == true) ref.invalidate(metasProvider);
      });
    }

    Future<void> deletarMeta(String id) async {
      try {
        await FinanceiroExtService.deletarMeta(id);
        ref.invalidate(metasProvider);
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

    void abrirContribuir(Map<String, dynamic> meta) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ContribuirSheet(
          meta: meta,
          onSaved: () => ref.invalidate(metasProvider),
        ),
      );
    }

    return metasAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.acc),
      ),
      error: (e, _) => ErrorState(
        mensagem: 'Não foi possível carregar as metas.',
        onRetry: () => ref.invalidate(metasProvider),
      ),
      data: (metas) => Stack(children: [
        metas.isEmpty
            ? _EmptyState(onAdd: abrirAdicionar)
            : RefreshIndicator(
                color: AppColors.acc,
                backgroundColor: AppColors.surf,
                onRefresh: () async => ref.invalidate(metasProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePad,
                    AppSpacing.cardGap,
                    AppSpacing.pagePad,
                    100,
                  ),
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'METAS DE ECONOMIA',
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
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.cardGap),
                    ...metas.map((m) => _MetaCard(
                          meta: m,
                          onContribuir: () => abrirContribuir(m),
                          onDeletar: () =>
                              deletarMeta(m['_id'] as String),
                        )),
                  ],
                ),
              ),

        // FAB
        Positioned(
          bottom: 24,
          right: AppSpacing.pagePad,
          child: FloatingActionButton(
            heroTag: 'metas_fab',
            onPressed: abrirAdicionar,
            backgroundColor: AppColors.acc,
            foregroundColor: AppColors.bg,
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ]),
    );
  }
}

// ── Meta card ──────────────────────────────────────────────────────────────────

class _MetaCard extends StatelessWidget {
  final Map<String, dynamic> meta;
  final VoidCallback onContribuir;
  final VoidCallback onDeletar;

  const _MetaCard({
    required this.meta,
    required this.onContribuir,
    required this.onDeletar,
  });

  @override
  Widget build(BuildContext context) {
    final nome = meta['nome'] as String? ?? '';
    final emoji = meta['emoji'] as String? ?? '🎯';
    final metaVal = (meta['valor_meta'] as num?)?.toDouble() ?? 1;
    final atual = (meta['valor_atual'] as num?)?.toDouble() ?? 0;
    final corHex = meta['cor'] as String? ?? '#9ED465';
    final concluida = meta['concluida'] as bool? ?? false;
    final prazo = meta['prazo'] as String?;
    final pct = (atual / metaVal).clamp(0.0, 1.0);

    Color color;
    try {
      color = Color(int.parse(corHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      color = AppColors.acc;
    }

    String? prazoFmt;
    if (prazo != null) {
      final parts = prazo.split('-');
      if (parts.length >= 2) {
        prazoFmt = '${parts.length == 3 ? '${parts[2]}/' : ''}${parts[1]}/${parts[0]}';
      }
    }

    return Dismissible(
      key: Key('meta_${meta['_id']}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDeletar();
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
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
        onTap: concluida ? null : onContribuir,
        child: Container(
          margin:
              const EdgeInsets.only(bottom: AppSpacing.cardGap),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius:
                BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(
              color: concluida
                  ? AppColors.grn.withOpacity(0.4)
                  : AppColors.bord,
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // Emoji em container colorido
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  alignment: Alignment.center,
                  child:
                      Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            nome,
                            style: AppTextStyles.bodySm.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Badge percentual
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: concluida
                                ? AppColors.grn.withOpacity(0.15)
                                : color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusChip),
                          ),
                          child: Text(
                            concluida
                                ? '✅ 100%'
                                : '${(pct * 100).toInt()}%',
                            style: AppTextStyles.caption.copyWith(
                              color:
                                  concluida ? AppColors.grn : color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        'R\$ ${atual.toStringAsFixed(2).replaceAll('.', ',')} de R\$ ${metaVal.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: AppTextStyles.caption,
                      ),
                      if (prazoFmt != null)
                        Text(
                          'Prazo: $prazoFmt',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.mu),
                        ),
                    ],
                  ),
                ),
                // Deletar
                GestureDetector(
                  onTap: onDeletar,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.mu),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // Barra de progresso
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: AppColors.surf,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    concluida ? AppColors.grn : color,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),

              // Faltam + botão contribuir
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    concluida
                        ? 'Meta concluída!'
                        : 'Faltam R\$ ${(metaVal - atual).toStringAsFixed(2).replaceAll('.', ',')}',
                    style: AppTextStyles.caption.copyWith(
                      color: concluida ? AppColors.grn : color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!concluida)
                    GestureDetector(
                      onTap: onContribuir,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusChip),
                        ),
                        child: Text(
                          '+ Contribuir',
                          style: AppTextStyles.caption.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Contribuir sheet ───────────────────────────────────────────────────────────

class _ContribuirSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> meta;
  final VoidCallback onSaved;
  const _ContribuirSheet({required this.meta, required this.onSaved});

  @override
  ConsumerState<_ContribuirSheet> createState() =>
      _ContribuirSheetState();
}

class _ContribuirSheetState extends ConsumerState<_ContribuirSheet> {
  final _ctrl = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final valor =
        double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (valor == null || valor <= 0) return;

    setState(() => _salvando = true);
    try {
      await FinanceiroExtService.contribuirMeta(
        widget.meta['_id'] as String,
        valor: valor,
      );
      if (mounted) Navigator.of(context).pop();
      widget.onSaved();
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nome = widget.meta['nome'] as String? ?? '';
    final emoji = widget.meta['emoji'] as String? ?? '🎯';
    final metaVal =
        (widget.meta['valor_meta'] as num?)?.toDouble() ?? 0;
    final atual =
        (widget.meta['valor_atual'] as num?)?.toDouble() ?? 0;
    final faltam = metaVal - atual;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 20,
        left: AppSpacing.pagePad,
        right: AppSpacing.pagePad,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.bord,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contribuir para $nome',
                      style: AppTextStyles.titleSm),
                  Text(
                    'Faltam R\$ ${faltam.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 20),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.mono.copyWith(fontSize: 28),
            decoration: InputDecoration(
              hintText: '0,00',
              hintStyle: AppTextStyles.mono
                  .copyWith(fontSize: 28, color: AppColors.mu),
              prefixText: 'R\$ ',
              prefixStyle: AppTextStyles.bodySm
                  .copyWith(color: AppColors.mu, fontSize: 20),
              border: InputBorder.none,
              filled: false,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _salvando ? null : _salvar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.acc,
                foregroundColor: AppColors.bg,
                padding:
                    const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      AppSpacing.radiusBtn),
                ),
              ),
              icon: _salvando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.bg))
                  : const Icon(Icons.savings_rounded),
              label: Text(
                _salvando ? 'Salvando...' : 'Adicionar à meta',
                style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.bg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state com unicórnio Sweet ───────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: 40, horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              UnicornWidget(
                type: UnicornType.sweet,
                size: 140,
                mood: AstrixMood.idle,
              ),
              const SizedBox(height: 20),
              Text(
                'Nenhuma meta criada',
                style: AppTextStyles.titleSm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Defina objetivos financeiros e acompanhe seu progresso mês a mês.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: onAdd,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.acc,
                  side: const BorderSide(color: AppColors.acc),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        AppSpacing.radiusBtn),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Criar primeira meta'),
              ),
            ],
          ),
        ),
      );
}
