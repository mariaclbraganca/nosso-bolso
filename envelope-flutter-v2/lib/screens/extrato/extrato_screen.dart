import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/transacoes_provider.dart';
import '../../providers/mes_provider.dart';
import '../../providers/envelopes_provider.dart';
import '../../providers/remanejamentos_provider.dart';
import '../../constants.dart';
import 'relatorios_body.dart';
import 'resumo_mensal_screen.dart';
import 'edit_transacao_sheet.dart';
import 'lixeira_screen.dart';
import 'extrato_pdf.dart';
import 'extrato_csv.dart';
import '../sheets/form_gasto_sheet.dart';
import '../sheets/form_receita_sheet.dart';

// ─── Filtros locais para Despesas/Receitas ────────────────────────────────────

final _buscaDespesasProvider    = StateProvider<String>((ref) => '');
final _buscaReceitasProvider    = StateProvider<String>((ref) => '');
final _buscaAportesProvider     = StateProvider<String>((ref) => '');
final _filtroMinProvider = StateProvider<double?>((ref) => null);
final _filtroMaxProvider = StateProvider<double?>((ref) => null);

// ─── ExtratoScreen ────────────────────────────────────────────────────────────

/// Tela principal do Extrato — filho de IndexedStack, sem Scaffold aninhado.
/// Usa DefaultTabController com 4 abas: Relatórios | Despesas | Receitas | Reman.
class ExtratoScreen extends ConsumerWidget {
  const ExtratoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            _ExtratoHeader(),
            _TabBar(),
            Expanded(
              child: TabBarView(
                children: [
                  const RelatoriosBody(),
                  _TransacoesTab(tipo: 'despesa'),
                  _TransacoesTab(tipo: 'receita'),
                  const _AportesTab(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tab = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tab,
              builder: (_, __) {
                // aba 0 = Relatórios (sem FAB), 1 = Despesas, 2 = Receitas, 3 = Aportes (sem FAB)
                if (tab.index == 0 || tab.index == 3) return const SizedBox.shrink();
                final isReceita = tab.index == 2;
                return FloatingActionButton(
                  heroTag: 'extrato_fab',
                  backgroundColor: isReceita ? AppColors.grn : AppColors.red,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => isReceita
                          ? const FormReceitaSheet()
                          : const FormGastoSheet(),
                    );
                  },
                  child: Icon(
                    isReceita
                        ? Icons.add_circle_outline_rounded
                        : Icons.remove_circle_outline_rounded,
                    color: Colors.white,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _ExtratoHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesAtualProvider);
    final statusBarH = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePad, statusBarH + 12,
        AppSpacing.pagePad, 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surf,
        border: Border(bottom: BorderSide(color: AppColors.bord, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Seletor de mês
          GestureDetector(
            onTap: () => ref.read(mesAtualProvider.notifier).state =
                mesAnterior(mes),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.chevron_left, color: AppColors.tx, size: 22),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Extrato', style: AppTextStyles.caption),
                  Text(
                    mesLabelLongo(mes),
                    style: AppTextStyles.titleSm,
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => ref.read(mesAtualProvider.notifier).state =
                mesProximo(mes),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.chevron_right, color: AppColors.tx, size: 22),
            ),
          ),
          const SizedBox(width: 4),
          // Ações
          _HeaderAction(
            icon: Icons.summarize_outlined,
            cor: AppColors.acc,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ResumoMensalScreen()),
            ),
          ),
          const SizedBox(width: 4),
          _HeaderAction(
            icon: Icons.delete_outline,
            cor: AppColors.red,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LixeiraScreen()),
            ),
          ),
          const SizedBox(width: 4),
          _HeaderAction(
            icon: Icons.picture_as_pdf_outlined,
            cor: AppColors.org,
            onTap: () => exportarPdf(context, ref, mes),
          ),
          const SizedBox(width: 4),
          _HeaderAction(
            icon: Icons.table_chart_outlined,
            cor: AppColors.blu,
            onTap: () => exportarCsv(context, ref, mes),
          ),
        ],
      ),
    );
  }

}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final Color cor;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.icon,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: cor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cor.withOpacity(0.2), width: 0.5),
        ),
        child: Icon(icon, color: cor, size: 18),
      ),
    );
  }
}

// ─── TabBar customizada ───────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surf,
      child: TabBar(
        labelStyle: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTextStyles.bodySm,
        labelColor: AppColors.acc,
        unselectedLabelColor: AppColors.mu,
        indicatorColor: AppColors.acc,
        indicatorWeight: 2,
        dividerColor: AppColors.bord,
        tabs: const [
          Tab(text: 'Relatórios'),
          Tab(text: 'Despesas'),
          Tab(text: 'Receitas'),
          Tab(text: 'Aportes'),
        ],
      ),
    );
  }
}

// ─── Tab de Transações (Despesas / Receitas) ──────────────────────────────────

class _TransacoesTab extends ConsumerStatefulWidget {
  final String tipo; // 'despesa' | 'receita' | 'abastecimento'
  const _TransacoesTab({required this.tipo});

  @override
  ConsumerState<_TransacoesTab> createState() => _TransacoesTabState();
}

class _TransacoesTabState extends ConsumerState<_TransacoesTab>
    with AutomaticKeepAliveClientMixin {
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  StateProvider<String> get _buscaProvider {
    if (widget.tipo == 'despesa') return _buscaDespesasProvider;
    if (widget.tipo == 'abastecimento') return _buscaAportesProvider;
    return _buscaReceitasProvider;
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(pagedTransacoesProvider.notifier).fetchNextPage();
    }
  }

  void _onBuscaChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(_buscaProvider.notifier).state = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final busca = ref.watch(_buscaProvider).toLowerCase();
    final filtroMin = ref.watch(_filtroMinProvider);
    final filtroMax = ref.watch(_filtroMaxProvider);
    final todasTransacoes = ref.watch(transacoesComDetalhesProvider);

    // Filtra por tipo, busca e valor
    final filtradas = todasTransacoes.where((t) {
      if (t['tipo'] != widget.tipo) return false;

      if (busca.isNotEmpty) {
        final desc = (t['descricao']?.toString() ?? '').toLowerCase();
        final env = ((t['envelopes']?['nome_envelope'] as String?) ?? '').toLowerCase();
        if (!desc.contains(busca) && !env.contains(busca)) return false;
      }

      final val = (t['valor'] as num?)?.toDouble() ?? 0;
      if (filtroMin != null && val < filtroMin) return false;
      if (filtroMax != null && val > filtroMax) return false;

      return true;
    }).toList();

    // Agrupa por data (dd/MM)
    final Map<String, List<Map<String, dynamic>>> grupos = {};
    for (final t in filtradas) {
      final dataStr = t['data']?.toString() ?? t['created_at']?.toString() ?? '';
      String label = '—';
      try {
        final dt = DateTime.parse(dataStr).toLocal();
        label = DateFormat('dd/MM').format(dt);
      } catch (_) {}
      grupos.putIfAbsent(label, () => []).add(t);
    }

    final groupKeys = grupos.keys.toList();

    final totalVal = filtradas.fold<double>(
        0, (s, t) => s + ((t['valor'] as num?)?.toDouble() ?? 0));
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final cor = widget.tipo == 'despesa'
        ? AppColors.red
        : widget.tipo == 'abastecimento'
            ? AppColors.gold
            : AppColors.grn;

    return Column(
      children: [
        // ── Barra de busca e filtros ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePad, 14,
            AppSpacing.pagePad, 0,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: _onBuscaChanged,
                  style: AppTextStyles.bodySm,
                  decoration: InputDecoration(
                    hintText: widget.tipo == 'despesa'
                        ? 'Buscar despesas...'
                        : widget.tipo == 'abastecimento'
                            ? 'Buscar aportes...'
                            : 'Buscar receitas...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.mu, size: 18),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.itemGap),
              _FiltroBtn(
                ativo: filtroMin != null || filtroMax != null,
                onTap: () => _abrirFiltros(context),
              ),
            ],
          ),
        ),

        // ── Badge total + count ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePad, 10,
            AppSpacing.pagePad, 0,
          ),
          child: Row(
            children: [
              Text(
                '${filtradas.length} ${widget.tipo == 'despesa' ? 'despesa${filtradas.length != 1 ? 's' : ''}' : widget.tipo == 'abastecimento' ? 'aporte${filtradas.length != 1 ? 's' : ''}' : 'receita${filtradas.length != 1 ? 's' : ''}'}',
                style: AppTextStyles.caption,
              ),
              const Spacer(),
              Text(
                fmt.format(totalVal),
                style: AppTextStyles.monoSm.copyWith(color: cor),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Lista agrupada ─────────────────────────────────────────────────
        Expanded(
          child: filtradas.isEmpty
              ? _EstadoVazio(tipo: widget.tipo, buscando: busca.isNotEmpty)
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePad, 0,
                    AppSpacing.pagePad, 120,
                  ),
                  itemCount: groupKeys.length,
                  itemBuilder: (context, gi) {
                    final dataLabel = groupKeys[gi];
                    final items = grupos[dataLabel]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header do grupo
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 16, 0, 6),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.bord,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusChip,
                                  ),
                                ),
                                child: Text(
                                  dataLabel,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.tx,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 0.5,
                                  color: AppColors.bord,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                fmt.format(items.fold<double>(
                                  0,
                                  (s, t) => s + ((t['valor'] as num?)?.toDouble() ?? 0),
                                )),
                                style: AppTextStyles.caption.copyWith(color: cor),
                              ),
                            ],
                          ),
                        ),

                        // Itens do grupo com swipe-to-delete
                        ...items.asMap().entries.map((entry) {
                          final t = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.cardGap,
                            ),
                            child: _TransacaoItem(
                              transacao: t,
                              cor: cor,
                              onDeleted: () {
                                // Força refresh via invalidação do stream
                                // (o transacoesComDetalhesProvider recomputa automaticamente)
                              },
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _abrirFiltros(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FiltrosSheet(
        minInicial: ref.read(_filtroMinProvider),
        maxInicial: ref.read(_filtroMaxProvider),
        onAplicar: (min, max) {
          ref.read(_filtroMinProvider.notifier).state = min;
          ref.read(_filtroMaxProvider.notifier).state = max;
        },
        onLimpar: () {
          ref.read(_filtroMinProvider.notifier).state = null;
          ref.read(_filtroMaxProvider.notifier).state = null;
        },
      ),
    );
  }
}

// ─── Item de transação com Swipe-to-Delete ────────────────────────────────────

class _TransacaoItem extends ConsumerWidget {
  final Map<String, dynamic> transacao;
  final Color cor;
  final VoidCallback onDeleted;

  const _TransacaoItem({
    required this.transacao,
    required this.cor,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final val = (transacao['valor'] as num?)?.toDouble() ?? 0;
    final desc = transacao['descricao']?.toString() ?? '—';
    final envNome = (transacao['envelopes']?['nome_envelope'] as String?)
        ?? 'Sem envelope';
    final isAbastecimento = transacao['tipo'] == 'abastecimento';
    // Para aportes, limpa o prefixo "Abastecimento " da descrição
    final descExibida = isAbastecimento
        ? desc.replaceFirst(RegExp(r'^[Aa]bastecimento\s*', caseSensitive: false), '').trim()
        : desc;
    final envEmoji = isAbastecimento
        ? '💰'
        : (transacao['envelopes']?['emoji'] as String?) ?? '💰';
    final userName = (transacao['usuarios']?['nome'] as String?) ?? '?';
    final id = transacao['id']?.toString() ?? '';

    return Dismissible(
      key: ValueKey('tx_$id'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmarExclusao(context),
      onDismissed: (_) => _excluir(context, ref, id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.red.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(
            color: AppColors.red.withOpacity(0.3), width: 0.5,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: AppColors.red, size: 22),
            SizedBox(height: 4),
            Text('Excluir', style: TextStyle(
              color: AppColors.red, fontSize: 11, fontWeight: FontWeight.w500,
            )),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () => _editarTransacao(context, ref),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(color: AppColors.bord, width: 0.5),
          ),
          child: Row(
            children: [
              // Emoji envelope
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(envEmoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              // Descrição e envelope
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      descExibida,
                      style: AppTextStyles.bodySm
                          .copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            envNome,
                            style: AppTextStyles.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3, height: 3,
                          decoration: const BoxDecoration(
                            color: AppColors.mu,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          userName,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.corDoUsuario(userName),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Valor
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmt.format(val),
                    style: AppTextStyles.monoSm.copyWith(color: cor),
                  ),
                  const SizedBox(height: 3),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.mu,
                    size: 14,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmarExclusao(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: const BorderSide(color: AppColors.bord, width: 0.5),
        ),
        title: Text('Excluir transação?', style: AppTextStyles.titleSm),
        content: Text(
          'O item irá para a lixeira e poderá ser restaurado.',
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
  }

  Future<void> _excluir(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    try {
      await supabase
          .from('transacoes')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', id);

      onDeleted();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transação excluída',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.tx)),
            backgroundColor: AppColors.surf,
            action: SnackBarAction(
              label: 'Ver lixeira',
              textColor: AppColors.acc,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LixeiraScreen()),
              ),
            ),
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

  Future<void> _editarTransacao(BuildContext context, WidgetRef ref) async {
    // O transacoesStreamProvider vai auto-atualizar via Supabase realtime.
    await showEditTransacaoSheet(context, transacao);
  }
}

// ─── Estado vazio ─────────────────────────────────────────────────────────────

class _EstadoVazio extends StatelessWidget {
  final String tipo;
  final bool buscando;

  const _EstadoVazio({required this.tipo, required this.buscando});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePad),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              buscando ? Icons.search_off : Icons.receipt_long_outlined,
              color: AppColors.mu,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              buscando
                  ? 'Nenhum resultado'
                  : 'Nenhum${tipo == 'abastecimento' ? '' : 'a'} ${tipo == 'despesa' ? 'despesa' : tipo == 'abastecimento' ? 'aporte' : 'receita'} neste mês',
              style: AppTextStyles.titleSm.copyWith(color: AppColors.mu),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              buscando
                  ? 'Tente outros termos de busca'
                  : 'As transações aparecerão aqui conforme forem adicionadas',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Botão Filtro ─────────────────────────────────────────────────────────────

class _FiltroBtn extends StatelessWidget {
  final bool ativo;
  final VoidCallback onTap;

  const _FiltroBtn({required this.ativo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: ativo
              ? AppColors.acc.withOpacity(0.12)
              : AppColors.surf,
          borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
          border: Border.all(
            color: ativo ? AppColors.acc : AppColors.bord,
            width: ativo ? 1.0 : 0.5,
          ),
        ),
        child: Icon(
          Icons.tune_rounded,
          color: ativo ? AppColors.acc : AppColors.mu,
          size: 18,
        ),
      ),
    );
  }
}

// ─── Sheet de Filtros Avançados ───────────────────────────────────────────────

class _FiltrosSheet extends StatefulWidget {
  final double? minInicial;
  final double? maxInicial;
  final void Function(double? min, double? max) onAplicar;
  final VoidCallback onLimpar;

  const _FiltrosSheet({
    required this.minInicial,
    required this.maxInicial,
    required this.onAplicar,
    required this.onLimpar,
  });

  @override
  State<_FiltrosSheet> createState() => _FiltrosSheetState();
}

class _FiltrosSheetState extends State<_FiltrosSheet> {
  late TextEditingController _minCtrl;
  late TextEditingController _maxCtrl;

  @override
  void initState() {
    super.initState();
    _minCtrl = TextEditingController(
      text: widget.minInicial != null
          ? widget.minInicial!.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
    _maxCtrl = TextEditingController(
      text: widget.maxInicial != null
          ? widget.maxInicial!.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  double? _parse(String v) {
    if (v.trim().isEmpty) return null;
    return double.tryParse(v.replaceAll('.', '').replaceAll(',', '.'));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePad, 20,
        AppSpacing.pagePad, mq.viewInsets.bottom + AppSpacing.pagePad,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.bord,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.acc, size: 20),
              const SizedBox(width: 8),
              Text('Filtros Avançados', style: AppTextStyles.titleSm),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),

          Text('Valor mínimo (R\$)', style: AppTextStyles.caption),
          const SizedBox(height: 6),
          TextField(
            controller: _minCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.body,
            decoration: const InputDecoration(
              hintText: '0,00',
              prefixText: 'R\$ ',
            ),
          ),

          const SizedBox(height: AppSpacing.cardGap),

          Text('Valor máximo (R\$)', style: AppTextStyles.caption),
          const SizedBox(height: 6),
          TextField(
            controller: _maxCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.body,
            decoration: const InputDecoration(
              hintText: '0,00',
              prefixText: 'R\$ ',
            ),
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onLimpar();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.mu,
                    side: const BorderSide(color: AppColors.bord),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                    ),
                  ),
                  child: Text('Limpar', style: AppTextStyles.bodySm),
                ),
              ),
              const SizedBox(width: AppSpacing.cardGap),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    widget.onAplicar(_parse(_minCtrl.text), _parse(_maxCtrl.text));
                    Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.acc,
                    foregroundColor: AppColors.bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                    ),
                  ),
                  child: Text('Aplicar',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.bg,
                      fontWeight: FontWeight.w600,
                    )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Aba Aportes (Abastecimentos + Remanejamentos) ────────────────────────────

class _AportesTab extends ConsumerStatefulWidget {
  const _AportesTab();

  @override
  ConsumerState<_AportesTab> createState() => _AportesTabState();
}

class _AportesTabState extends ConsumerState<_AportesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _fmtData = DateFormat('dd/MM');

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final mesSelecionado = ref.watch(mesAtualProvider);
    final todasTransacoes = ref.watch(transacoesComDetalhesProvider);
    final remanejamentosAsync = ref.watch(remanejamentosProvider);
    final envelopes = ref.watch(envelopesProvider).value ?? [];

    // Mapa id→nome de envelope para cross-reference
    final envNomes = <String, String>{};
    final envEmojis = <String, String>{};
    for (final e in envelopes) {
      final id = e['id']?.toString() ?? '';
      envNomes[id] = e['nome_envelope']?.toString() ?? '—';
      envEmojis[id] = e['emoji']?.toString() ?? '📦';
    }

    // Aportes (abastecimentos) do mês
    final aportes = todasTransacoes
        .where((t) => t['tipo'] == 'abastecimento')
        .toList();

    // Remanejamentos filtrados pelo mês atual
    // Tenta filtrar por created_at; se a coluna não existir, mostra todos
    final todosReman = remanejamentosAsync.value ?? [];
    final remanejamentos = todosReman.where((r) {
      final createdAt = r['created_at']?.toString() ?? r['data']?.toString() ?? '';
      if (createdAt.isEmpty) return true; // sem data: exibe sempre
      return createdAt.length >= 7 && createdAt.substring(0, 7) == mesSelecionado;
    }).toList();

    final totalAportes = aportes.fold<double>(
        0, (s, t) => s + ((t['valor'] as num?)?.toDouble() ?? 0));
    final totalReman = remanejamentos.fold<double>(
        0, (s, r) => s + ((r['valor'] as num?)?.toDouble() ?? 0));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePad, 14, AppSpacing.pagePad, 120,
      ),
      children: [
        // ── Resumo ──────────────────────────────────────────────────────────
        Row(
          children: [
            Text(
              '${aportes.length} aporte${aportes.length != 1 ? 's' : ''}',
              style: AppTextStyles.caption,
            ),
            const Spacer(),
            Text(
              _fmt.format(totalAportes),
              style: AppTextStyles.monoSm.copyWith(color: AppColors.gold),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Lista de Aportes ─────────────────────────────────────────────────
        if (aportes.isEmpty)
          _EmptySection(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Nenhum aporte neste mês',
          )
        else
          ...aportes.map((t) {
            final val = (t['valor'] as num?)?.toDouble() ?? 0;
            final desc = (t['descricao']?.toString() ?? '—')
                .replaceFirst(
                    RegExp(r'^[Aa]bastecimento\s*', caseSensitive: false), '')
                .trim();
            final envNome =
                (t['envelopes']?['nome_envelope'] as String?) ?? 'Sem envelope';
            final dataStr =
                t['data']?.toString() ?? t['created_at']?.toString() ?? '';
            String dataLabel = '—';
            try {
              dataLabel = _fmtData.format(DateTime.parse(dataStr).toLocal());
            } catch (_) {}

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  border: Border.all(color: AppColors.bord, width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text('💰',
                          style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            desc.isEmpty ? envNome : desc,
                            style: AppTextStyles.bodySm.copyWith(
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(envNome, style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _fmt.format(val),
                          style: AppTextStyles.monoSm
                              .copyWith(color: AppColors.gold),
                        ),
                        const SizedBox(height: 3),
                        Text(dataLabel, style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

        // ── Seção Remanejamentos ─────────────────────────────────────────────
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bord,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusChip),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.swap_horiz_rounded,
                        color: AppColors.gold, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Remanejamentos',
                      style: AppTextStyles.caption.copyWith(color: AppColors.tx),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(height: 0.5, color: AppColors.bord),
              ),
              const SizedBox(width: 8),
              Text(
                _fmt.format(totalReman),
                style: AppTextStyles.caption.copyWith(color: AppColors.gold),
              ),
            ],
          ),
        ),

        if (remanejamentosAsync.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.gold),
            ),
          )
        else if (remanejamentos.isEmpty)
          _EmptySection(
            icon: Icons.swap_horiz_rounded,
            label: 'Nenhum remanejamento neste mês',
          )
        else
          ...remanejamentos.map((r) {
            final origemId = r['envelope_origem_id']?.toString() ?? '';
            final destinoId = r['envelope_destino_id']?.toString() ?? '';
            final origemNome = envNomes[origemId] ?? 'Envelope';
            final destinoNome = envNomes[destinoId] ?? 'Envelope';
            final val = (r['valor'] as num?)?.toDouble() ?? 0;
            final createdAt = r['created_at']?.toString() ?? r['data']?.toString() ?? '';
            String dataLabel = '—';
            try {
              if (createdAt.isNotEmpty) {
                dataLabel = _fmtData.format(DateTime.parse(createdAt).toLocal());
              }
            } catch (_) {}

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusCard),
                  border: Border.all(color: AppColors.bord, width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: AppColors.gold,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$origemNome → $destinoNome',
                            style: AppTextStyles.bodySm.copyWith(
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text('Remanejamento',
                              style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _fmt.format(val),
                          style: AppTextStyles.monoSm
                              .copyWith(color: AppColors.gold),
                        ),
                        const SizedBox(height: 3),
                        Text(dataLabel, style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ─── Empty state compacto para seções ─────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EmptySection({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.mu, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: AppTextStyles.caption.copyWith(color: AppColors.mu)),
        ],
      ),
    );
  }
}

