import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/fixos_provider.dart';
import '../../widgets/shared/error_state.dart';
import '../../providers/mes_provider.dart';
import '../../constants.dart';
import '../../services/notification_service.dart';
import 'form_fixo_sheet.dart';

class FixosTab extends ConsumerStatefulWidget {
  const FixosTab({super.key});

  @override
  ConsumerState<FixosTab> createState() => _FixosTabState();
}

class _FixosTabState extends ConsumerState<FixosTab> {
  // ── Modo de seleção múltipla ───────────────────────────────────────────────
  bool _modoSelecao = false;
  Set<String> _selecionados = {};

  void _entrarModoSelecao() {
    setState(() {
      _modoSelecao = true;
      _selecionados = {};
    });
  }

  void _sairModoSelecao() {
    setState(() {
      _modoSelecao = false;
      _selecionados = {};
    });
  }

  void _toggleSelecao(String id) {
    setState(() {
      if (_selecionados.contains(id)) {
        _selecionados.remove(id);
      } else {
        _selecionados.add(id);
      }
    });
  }

  Future<void> _marcarSelecionadosComoPagos(
      List<Map<String, dynamic>> fixos) async {
    if (_selecionados.isEmpty) return;

    final ids = _selecionados.toList();

    try {
      await supabase
          .from('gastos_fixos')
          .update({'pago': true}).inFilter('id', ids);

      // Cancela alertas para cada fixo marcado como pago
      for (final id in ids) {
        NotificationService.cancelarAlertasFixo(id);
      }

      final count = ids.length;
      _sairModoSelecao();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$count ${count == 1 ? 'fixo marcado' : 'fixos marcados'} como pago ✅'),
          backgroundColor: AppColors.grn,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Toggle pago via Supabase PATCH ────────────────────────────────────────
  Future<void> _togglePago(String id, bool novoValor) async {
    try {
      await supabase
          .from('gastos_fixos')
          .update({'pago': novoValor}).eq('id', id);

      // Cancela alertas quando marcado como pago
      if (novoValor) NotificationService.cancelarAlertasFixo(id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(novoValor ? '✅ Marcado como pago' : '↩ Desfeito'),
          backgroundColor: novoValor ? AppColors.grn : AppColors.org,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Excluir via Supabase DELETE ────────────────────────────────────────────
  Future<bool> _confirmarExclusao(String id, String nome) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
        title: Text('Excluir fixo?', style: AppTextStyles.titleSm),
        content: Text(
          'Remover "$nome" da lista?',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: AppColors.mu)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Excluir',
                style: TextStyle(
                    color: AppColors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmar != true) return false;

    try {
      await supabase.from('gastos_fixos').delete().eq('id', id);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return false;
    }
  }

  void _abrirFormFixo([Map<String, dynamic>? fixo]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FormFixoSheet(fixo: fixo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fixosAsync = ref.watch(fixosStreamProvider);
    final fixos = ref.watch(fixosMesAtualProvider);
    final mes = ref.watch(mesAtualProvider);
    final fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');

    final totalVal =
        fixos.fold(0.0, (s, f) => s + (f['valor'] as num).toDouble());
    final pagoVal = fixos
        .where((f) => f['pago'] == true)
        .fold(0.0, (s, f) => s + (f['valor'] as num).toDouble());
    final pendVal = totalVal - pagoVal;

    // Calcula total dos selecionados
    final totalSelecionado = fixos
        .where((f) => _selecionados.contains(f['id'] as String))
        .fold(0.0, (s, f) => s + (f['valor'] as num).toDouble());

    return fixosAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.acc),
      ),
      error: (e, _) => ErrorState(
        mensagem: 'Não foi possível carregar os gastos fixos.',
        onRetry: () => ref.invalidate(fixosStreamProvider),
      ),
      data: (_) => Stack(
        children: [
          // ── Lista ─────────────────────────────────────────────────────────
          ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pagePad,
              AppSpacing.cardGap,
              AppSpacing.pagePad,
              // Espaço extra quando barra de seleção está visível
              _modoSelecao && _selecionados.isNotEmpty ? 140 : 100,
            ),
            children: [
              // Botão Selecionar / Cancelar no topo
              if (fixos.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed:
                        _modoSelecao ? _sairModoSelecao : _entrarModoSelecao,
                    icon: Icon(
                      _modoSelecao
                          ? Icons.close_rounded
                          : Icons.checklist_rounded,
                      size: 18,
                      color: _modoSelecao ? AppColors.mu : AppColors.acc,
                    ),
                    label: Text(
                      _modoSelecao ? 'Cancelar' : 'Selecionar',
                      style: AppTextStyles.caption.copyWith(
                        color: _modoSelecao ? AppColors.mu : AppColors.acc,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      backgroundColor: _modoSelecao
                          ? AppColors.bord.withOpacity(0.5)
                          : AppColors.acc.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusBtn),
                      ),
                    ),
                  ),
                ),

              if (fixos.isNotEmpty) const SizedBox(height: AppSpacing.cardGap),

              // Summary cards
              Row(children: [
                _MiniCard(
                    label: 'TOTAL/MÊS',
                    valor: fmt.format(totalVal),
                    color: AppColors.tx),
                const SizedBox(width: AppSpacing.cardGap),
                _MiniCard(
                    label: '✓ PAGO',
                    valor: fmt.format(pagoVal),
                    color: AppColors.grn),
                const SizedBox(width: AppSpacing.cardGap),
                _MiniCard(
                    label: '⏳ PENDENTE',
                    valor: fmt.format(pendVal),
                    color: AppColors.org),
              ]),
              const SizedBox(height: AppSpacing.sectionGap),

              if (fixos.isEmpty)
                _EmptyState(onAdd: () => _abrirFormFixo())
              else ...[
                Text(
                  'GASTOS FIXOS — ${mesLabel(mes)}',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.cardGap),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusCard),
                    border:
                        Border.all(color: AppColors.bord, width: 0.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: fixos.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final f = entry.value;
                      final id = f['id'] as String;
                      return _FixoItem(
                        fixo: f,
                        showDivider: idx > 0,
                        fmt: fmt,
                        modoSelecao: _modoSelecao,
                        selecionado: _selecionados.contains(id),
                        onToggleSelecao: () => _toggleSelecao(id),
                        onToggle: (v) => _togglePago(id, v),
                        onTap: _modoSelecao
                            ? () => _toggleSelecao(id)
                            : () => _abrirFormFixo(f),
                        onDismiss: _modoSelecao
                            ? null
                            : () => _confirmarExclusao(
                                id, f['nome'] as String),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.cardGap),
                // Dica informativa (oculta no modo de seleção)
                if (!_modoSelecao)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.acc.withOpacity(0.08),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                          color: AppColors.acc.withOpacity(0.2)),
                    ),
                    child: Text(
                      '💡 Deslize para a esquerda para excluir. Toque para editar.',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.acc, height: 1.5),
                    ),
                  ),
                if (_modoSelecao)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.acc.withOpacity(0.08),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                          color: AppColors.acc.withOpacity(0.2)),
                    ),
                    child: Text(
                      '✅ Toque nos itens para selecionar. Pressione "Marcar como pagos" para confirmar.',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.acc, height: 1.5),
                    ),
                  ),
              ],
            ],
          ),

          // ── Barra de seleção múltipla (aparece ao selecionar itens) ──────
          if (_modoSelecao && _selecionados.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BarraSelecao(
                count: _selecionados.length,
                total: totalSelecionado,
                fmt: fmt,
                onConfirmar: () =>
                    _marcarSelecionadosComoPagos(fixos),
                onCancelar: _sairModoSelecao,
              ),
            )
          // ── Rodapé com totais (fora do modo seleção) ──────────────────────
          else if (fixos.isNotEmpty && !_modoSelecao)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _RodapeFixos(
                  totalMes: totalVal, pendente: pendVal, fmt: fmt),
            ),

          // ── FAB (oculto no modo de seleção) ───────────────────────────────
          if (!_modoSelecao)
            Positioned(
              bottom: fixos.isNotEmpty ? 76 : 24,
              right: AppSpacing.pagePad,
              child: FloatingActionButton(
                heroTag: 'fixos_fab',
                onPressed: () => _abrirFormFixo(),
                backgroundColor: AppColors.acc,
                foregroundColor: AppColors.bg,
                child: const Icon(Icons.add_rounded),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Barra inferior de seleção múltipla ─────────────────────────────────────────

class _BarraSelecao extends StatelessWidget {
  final int count;
  final double total;
  final NumberFormat fmt;
  final VoidCallback onConfirmar;
  final VoidCallback onCancelar;

  const _BarraSelecao({
    required this.count,
    required this.total,
    required this.fmt,
    required this.onConfirmar,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePad, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surf,
          border: Border(top: BorderSide(color: AppColors.acc.withOpacity(0.3), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Info de seleção
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count ${count == 1 ? 'selecionado' : 'selecionados'}',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.mu, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fmt.format(total),
                    style: AppTextStyles.monoSm.copyWith(color: AppColors.acc),
                  ),
                ],
              ),
            ),
            // Botão confirmar
            FilledButton.icon(
              onPressed: onConfirmar,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.acc,
                foregroundColor: AppColors.bg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text(
                'Marcar como pagos',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      );
}

// ── Item Fixo com Dismissible ──────────────────────────────────────────────────

class _FixoItem extends StatelessWidget {
  final Map<String, dynamic> fixo;
  final bool showDivider;
  final NumberFormat fmt;
  final bool modoSelecao;
  final bool selecionado;
  final VoidCallback onToggleSelecao;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final Future<bool> Function()? onDismiss;

  const _FixoItem({
    required this.fixo,
    required this.showDivider,
    required this.fmt,
    required this.modoSelecao,
    required this.selecionado,
    required this.onToggleSelecao,
    required this.onToggle,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isPago = fixo['pago'] == true;
    final nome = fixo['nome'] as String? ?? '';
    final valor = (fixo['valor'] as num).toDouble();
    final statusColor = isPago ? AppColors.grn : AppColors.org;

    Widget itemContent = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          // Checkbox (modo seleção) ou ícone status (modo normal)
          if (modoSelecao)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selecionado ? AppColors.acc : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selecionado ? AppColors.acc : AppColors.bord,
                    width: 2,
                  ),
                ),
                child: selecionado
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.bg, size: 16)
                    : null,
              ),
            )
          else
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              alignment: Alignment.center,
              child: Text(
                isPago ? '✅' : '🔒',
                style: const TextStyle(fontSize: 17),
              ),
            ),
          const SizedBox(width: 12),
          // Nome e status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: AppTextStyles.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isPago ? AppColors.mu : AppColors.tx,
                    decoration:
                        isPago ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Row(children: [
                  Text(
                    isPago ? 'Pago' : 'Pendente',
                    style: AppTextStyles.caption.copyWith(
                        color: statusColor, fontWeight: FontWeight.w700),
                  ),
                  if (!isPago && fixo['dia_vencimento'] != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.org.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Vence dia ${fixo['dia_vencimento']}',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.org, fontSize: 10),
                      ),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          // Valor
          Text(
            fmt.format(valor),
            style: AppTextStyles.monoSm
                .copyWith(color: isPago ? AppColors.mu : AppColors.tx),
          ),
          // Switch (apenas fora do modo de seleção)
          if (!modoSelecao) ...[
            const SizedBox(width: 12),
            SizedBox(
              height: 24,
              width: 44,
              child: Switch(
                value: isPago,
                onChanged: onToggle,
                activeColor: Colors.white,
                activeTrackColor: AppColors.grn,
                inactiveThumbColor: AppColors.mu,
                inactiveTrackColor: AppColors.bord,
              ),
            ),
          ] else
            const SizedBox(width: 12),
        ]),
      ),
    );

    // No modo de seleção, desabilita o Dismissible
    if (modoSelecao) {
      return Column(children: [
        if (showDivider) const Divider(height: 1, color: AppColors.bord),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: selecionado ? AppColors.acc.withOpacity(0.08) : Colors.transparent,
          child: itemContent,
        ),
      ]);
    }

    return Column(children: [
      if (showDivider) const Divider(height: 1, color: AppColors.bord),
      Dismissible(
        key: Key('fixo_${fixo['id']}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => onDismiss!(),
        background: Container(
          color: AppColors.red.withOpacity(0.15),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: Text(
            'Excluir 🗑️',
            style: AppTextStyles.bodySm.copyWith(
                color: AppColors.red, fontWeight: FontWeight.w700),
          ),
        ),
        child: itemContent,
      ),
    ]);
  }
}

// ── Mini card de resumo ─────────────────────────────────────────────────────────

class _MiniCard extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;

  const _MiniCard({
    required this.label,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius:
                BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(color: AppColors.bord, width: 0.5),
          ),
          child: Column(children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Text(
              valor,
              style: AppTextStyles.monoSm.copyWith(color: color),
            ),
          ]),
        ),
      );
}

// ── Rodapé fixo com totais ──────────────────────────────────────────────────────

class _RodapeFixos extends StatelessWidget {
  final double totalMes;
  final double pendente;
  final NumberFormat fmt;

  const _RodapeFixos({
    required this.totalMes,
    required this.pendente,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePad, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surf,
          border:
              Border(top: BorderSide(color: AppColors.bord, width: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total pendente', style: AppTextStyles.caption),
              Text(
                fmt.format(pendente),
                style: AppTextStyles.monoSm.copyWith(color: AppColors.org),
              ),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Total do mês', style: AppTextStyles.caption),
              Text(
                fmt.format(totalMes),
                style: AppTextStyles.monoSm,
              ),
            ]),
          ],
        ),
      );
}

// ── Empty state ─────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
          child: Column(
            children: [
              const Text('📌', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 16),
              Text(
                'Nenhum gasto fixo',
                style: AppTextStyles.titleSm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Cadastre aluguel, plano de saúde e outras despesas fixas mensais.',
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
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusBtn),
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar fixo'),
              ),
            ],
          ),
        ),
      );
}
