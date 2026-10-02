import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/compras_provider.dart';
import 'widgets/lista_compras_widgets.dart';

final itensAvulsosListaProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);

/// Lista inteligente de compras baseada em histórico com IA.
class ListaComprasScreen extends ConsumerStatefulWidget {
  const ListaComprasScreen({super.key});

  @override
  ConsumerState<ListaComprasScreen> createState() => _ListaComprasScreenState();
}

class _ListaComprasScreenState extends ConsumerState<ListaComprasScreen> {
  int _dias = 7;

  void _compartilharLista(List<Map<String, dynamic>> itens, Set<String> checked) {
    if (itens.isEmpty) return;
    final sb = StringBuffer('🛒 *Lista de Compras — Nosso Bolso*\n\n');
    for (final item in itens) {
      final nome = item['nome'] ?? '';
      final cat = item['categoria'] ?? 'Outros';
      final key = '${cat}_$nome';
      final isDone = checked.contains(key);
      final qtd = item['quantidade_sugerida'] ?? 1;
      final unidade = item['unidade'] ?? 'un';
      sb.writeln('${isDone ? "✅" : "⬜"} $nome ($qtd $unidade)');
    }
    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Lista copiada para a área de transferência!'),
        backgroundColor: AppColors.grn,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _adicionarItemAvulso() async {
    final nomeCtrl = TextEditingController();
    final qtdCtrl = TextEditingController(text: '1');
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
        title: Text('Adicionar Item Avulso 🛍️', style: AppTextStyles.titleSm),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeCtrl,
              autofocus: true,
              style: AppTextStyles.body,
              decoration: const InputDecoration(hintText: 'Nome do produto (ex: Leite)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtdCtrl,
              keyboardType: TextInputType.number,
              style: AppTextStyles.body,
              decoration: const InputDecoration(hintText: 'Quantidade (ex: 2)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('Cancelar', style: AppTextStyles.body.copyWith(color: AppColors.mu)),
          ),
          ElevatedButton(
            onPressed: () {
              final n = nomeCtrl.text.trim();
              if (n.isNotEmpty) {
                Navigator.pop(c, {
                  'nome': n,
                  'categoria': 'Avulsos',
                  'quantidade_sugerida': int.tryParse(qtdCtrl.text) ?? 1,
                  'unidade': 'un',
                  'preco_estimado': 0.0,
                  'motivo': 'Adicionado manualmente',
                });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.acc),
            child: Text('Adicionar', style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (res != null && mounted) {
      ref.read(itensAvulsosListaProvider.notifier).state = [
        ...ref.read(itensAvulsosListaProvider),
        res,
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final listaAsync = ref.watch(listaComprasProvider(_dias));
    final checked = ref.watch(itensChecadosListaProvider);
    final avulsos = ref.watch(itensAvulsosListaProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.tx),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Lista Inteligente', style: AppTextStyles.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.acc),
            tooltip: 'Copiar lista',
            onPressed: () {
              final dados = listaAsync.value;
              final itensApi = (dados?['itens'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
              _compartilharLista([...itensApi, ...avulsos], checked);
            },
          ),
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
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mu, size: 18),
                items: [7, 14, 30].map((d) => DropdownMenuItem<int>(
                  value: d,
                  child: Text('$d dias', style: AppTextStyles.bodySm.copyWith(color: AppColors.tx)),
                )).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _dias = v);
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.acc,
        foregroundColor: AppColors.bg,
        onPressed: _adicionarItemAvulso,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Item Avulso', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: listaAsync.when(
        data: (lista) {
          final itensRaw = (lista['itens'] as List?) ?? [];
          final itens = [
            ...itensRaw.map((e) => Map<String, dynamic>.from(e as Map)),
            ...avulsos,
          ];
          if (itens.isEmpty) return _emptyState();

          final total = (lista['custo_estimado_total'] as num?)?.toStringAsFixed(2) ?? '0.00';
          final saldo = (lista['saldo_envelope'] as num?)?.toStringAsFixed(2) ?? '0.00';
          final dentro = lista['dentro_do_orcamento'] as bool? ?? true;
          final diasCob = lista['dias_cobertura'] as int? ?? _dias;

          final Map<String, List<Map<String, dynamic>>> porCategoria = {};
          for (final item in itens) {
            final cat = item['categoria'] as String? ?? 'Outros';
            porCategoria.putIfAbsent(cat, () => []).add(item);
          }

          return Column(
            children: [
              ResumoListaCard(
                total: total,
                saldo: saldo,
                dentro: dentro,
                dias: diasCob,
                marcados: checked.length,
                totalItens: itens.length,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.acc,
                  backgroundColor: AppColors.card,
                  onRefresh: () => ref.refresh(listaComprasProvider(_dias).future),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(AppSpacing.pagePad, AppSpacing.cardGap, AppSpacing.pagePad, 90),
                    children: porCategoria.entries.map((entry) {
                      return CategoriaListaSection(
                        categoria: entry.key,
                        itens: entry.value,
                        checked: checked,
                        onToggle: (key) {
                          final novo = Set<String>.from(ref.read(itensChecadosListaProvider));
                          if (novo.contains(key)) novo.remove(key); else novo.add(key);
                          ref.read(itensChecadosListaProvider.notifier).state = novo;
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acc)),
        error: (e, _) => Center(child: Text('Erro: $e', style: AppTextStyles.body.copyWith(color: AppColors.red))),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart_outlined, size: 64, color: AppColors.mu),
          const SizedBox(height: 16),
          Text('Sem dados suficientes', style: AppTextStyles.title.copyWith(color: AppColors.mu)),
          const SizedBox(height: 8),
          Text('Configure o perfil ou adicione itens avulsos.', style: AppTextStyles.body.copyWith(color: AppColors.mu)),
        ],
      ),
    );
  }
}
