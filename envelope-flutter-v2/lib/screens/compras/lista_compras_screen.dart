import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/compras_provider.dart';

/// Lista inteligente de compras baseada em histórico.
/// Empurrada via Navigator.push de dentro do modal.
class ListaComprasScreen extends ConsumerStatefulWidget {
  const ListaComprasScreen({super.key});

  @override
  ConsumerState<ListaComprasScreen> createState() =>
      _ListaComprasScreenState();
}

class _ListaComprasScreenState extends ConsumerState<ListaComprasScreen> {
  int _dias = 7;
  final Set<String> _checked = {};

  @override
  Widget build(BuildContext context) {
    final listaAsync = ref.watch(listaComprasProvider(_dias));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.tx),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Lista Inteligente', style: AppTextStyles.title),
        actions: [
          // Seletor de dias
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surf,
              borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
              border: Border.all(color: AppColors.bord),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _dias,
                dropdownColor: AppColors.card,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.mu, size: 18),
                items: [7, 14, 30]
                    .map((d) => DropdownMenuItem<int>(
                          value: d,
                          child: Text(
                            '$d dias',
                            style: AppTextStyles.bodySm
                                .copyWith(color: AppColors.tx),
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _dias = v;
                      _checked.clear();
                    });
                  }
                },
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: AppColors.bord),
        ),
      ),
      body: listaAsync.when(
        data: (lista) {
          if (lista.isEmpty) {
            return _emptyState();
          }

          final itensRaw = (lista['itens'] as List?) ?? [];
          final itens = itensRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final total =
              (lista['custo_estimado_total'] as num?)?.toStringAsFixed(2) ??
                  '0.00';
          final saldo =
              (lista['saldo_envelope'] as num?)?.toStringAsFixed(2) ?? '0.00';
          final dentro = lista['dentro_do_orcamento'] as bool? ?? true;
          final diasCob =
              lista['dias_cobertura'] as int? ?? _dias;

          // Agrupar por categoria
          final Map<String, List<Map<String, dynamic>>> porCategoria = {};
          for (final item in itens) {
            final cat = item['categoria'] as String? ?? 'Outros';
            porCategoria.putIfAbsent(cat, () => []).add(item);
          }

          // Contar marcados
          final marcados = _checked.length;
          final totalItens = itens.length;

          return Column(
            children: [
              // Card de resumo
              _ResumoCard(
                total: total,
                saldo: saldo,
                dentro: dentro,
                dias: diasCob,
                marcados: marcados,
                totalItens: totalItens,
              ),

              // Lista agrupada
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.acc,
                  backgroundColor: AppColors.card,
                  onRefresh: () =>
                      ref.refresh(listaComprasProvider(_dias).future),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.pagePad,
                      AppSpacing.cardGap,
                      AppSpacing.pagePad,
                      MediaQuery.of(context).padding.bottom + 80,
                    ),
                    children: porCategoria.entries.map((entry) {
                      return _CategoriaSection(
                        categoria: entry.key,
                        itens: entry.value,
                        checked: _checked,
                        onToggle: (key) => setState(() {
                          if (_checked.contains(key)) {
                            _checked.remove(key);
                          } else {
                            _checked.add(key);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.acc),
              const SizedBox(height: 16),
              Text(
                'Gerando lista inteligente com IA…',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
              ),
              const SizedBox(height: 8),
              Text(
                'Analisando histórico de $_dias dias',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.red),
              const SizedBox(height: 12),
              Text('Erro ao carregar lista',
                  style: AppTextStyles.body.copyWith(color: AppColors.red)),
              const SizedBox(height: 8),
              Text(e.toString(),
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () =>
                    ref.invalidate(listaComprasProvider(_dias)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.acc),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusBtn)),
                ),
                child: Text('Tentar novamente',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.acc)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart_outlined,
              size: 64, color: AppColors.mu),
          const SizedBox(height: 16),
          Text('Sem dados suficientes',
              style: AppTextStyles.title.copyWith(color: AppColors.mu)),
          const SizedBox(height: 8),
          Text(
            'Configure o perfil da família\ne registre algumas compras primeiro.',
            style: AppTextStyles.body.copyWith(color: AppColors.mu),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Card de resumo ───────────────────────────────────────────────────────────

class _ResumoCard extends StatelessWidget {
  final String total;
  final String saldo;
  final bool dentro;
  final int dias;
  final int marcados;
  final int totalItens;

  const _ResumoCard({
    required this.total,
    required this.saldo,
    required this.dentro,
    required this.dias,
    required this.marcados,
    required this.totalItens,
  });

  @override
  Widget build(BuildContext context) {
    final corStatus = dentro ? AppColors.acc : AppColors.red;
    final iconStatus = dentro
        ? Icons.check_circle_rounded
        : Icons.warning_amber_rounded;

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.pagePad, AppSpacing.pagePad, AppSpacing.pagePad, 0),
      padding: const EdgeInsets.all(AppSpacing.pagePad),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: corStatus.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: corStatus.withOpacity(0.12),
            ),
            child: Icon(iconStatus, color: corStatus, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lista para $dias dias',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  'R\$ $total',
                  style: AppTextStyles.mono.copyWith(
                    color: corStatus,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Saldo envelope: R\$ $saldo',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          // Progress circular de itens marcados
          if (totalItens > 0) ...[
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: marcados / totalItens,
                        backgroundColor: AppColors.bord,
                        valueColor: const AlwaysStoppedAnimation(AppColors.acc),
                        strokeWidth: 3,
                      ),
                      Text(
                        '$marcados',
                        style: AppTextStyles.bodySm.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.acc),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('/$totalItens',
                    style: AppTextStyles.caption),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Seção por categoria ──────────────────────────────────────────────────────

class _CategoriaSection extends StatelessWidget {
  final String categoria;
  final List<Map<String, dynamic>> itens;
  final Set<String> checked;
  final ValueChanged<String> onToggle;

  const _CategoriaSection({
    required this.categoria,
    required this.itens,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header da categoria
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.acc,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                categoria,
                style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.mu, fontWeight: FontWeight.w600,
                    letterSpacing: 0.5),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bord,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                ),
                child: Text(
                  '${itens.length}',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
        ),
        // Itens
        ...itens.map((item) {
          final nome = item['nome'] as String? ?? '';
          final key = '${categoria}_$nome';
          return _ItemListaCard(
            item: item,
            isChecked: checked.contains(key),
            onToggle: () => onToggle(key),
          );
        }),
      ],
    );
  }
}

// ─── Card de item ─────────────────────────────────────────────────────────────

class _ItemListaCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isChecked;
  final VoidCallback onToggle;

  const _ItemListaCard({
    required this.item,
    required this.isChecked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final corte = item['corte_sugerido'] as bool? ?? false;
    final nome = item['nome'] as String? ?? '';
    final qtd = item['quantidade_sugerida'];
    final unidade = item['unidade'] as String? ?? 'un';
    final preco = item['preco_estimado'] as num? ?? 0;
    final motivo = item['motivo'] as String? ?? '';

    return Opacity(
      opacity: corte ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.itemGap),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isChecked
                ? AppColors.acc.withOpacity(0.06)
                : AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 4),
            border: Border.all(
              color: isChecked
                  ? AppColors.acc.withOpacity(0.3)
                  : corte
                      ? AppColors.red.withOpacity(0.2)
                      : AppColors.bord,
            ),
          ),
          child: Row(
            children: [
              // Checkbox customizado
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isChecked
                      ? AppColors.acc
                      : Colors.transparent,
                  border: Border.all(
                    color: isChecked
                        ? AppColors.acc
                        : AppColors.bord,
                    width: 1.5,
                  ),
                ),
                child: isChecked
                    ? const Icon(Icons.check_rounded,
                        color: Colors.black, size: 14)
                    : null,
              ),
              const SizedBox(width: 12),

              // Conteúdo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      style: AppTextStyles.body.copyWith(
                        decoration: corte || isChecked
                            ? TextDecoration.lineThrough
                            : null,
                        color: isChecked
                            ? AppColors.mu
                            : corte
                                ? AppColors.mu
                                : AppColors.tx,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$qtd $unidade${motivo.isNotEmpty ? ' · $motivo' : ''}',
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Preço e indicador de corte
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R\$ ${preco.toStringAsFixed(2)}',
                    style: AppTextStyles.monoSm.copyWith(
                      color: isChecked
                          ? AppColors.mu
                          : corte
                              ? AppColors.red
                              : AppColors.acc,
                      fontSize: 13,
                    ),
                  ),
                  if (corte)
                    Text(
                      'Corte sugerido',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.red),
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
