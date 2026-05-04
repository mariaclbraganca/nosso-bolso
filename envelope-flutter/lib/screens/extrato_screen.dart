import 'package:envelope_flutter/screens/edit_transacao_sheet.dart';
import 'package:envelope_flutter/screens/lixeira_screen.dart';
import 'package:envelope_flutter/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../providers/usuarios_provider.dart';
import '../providers/transacoes_provider.dart';
import '../providers/mes_provider.dart';
import '../theme/app_theme.dart';
import '../constants.dart';
import '../widgets/transacao_item.dart';
import '../widgets/seletor_usuario.dart';

class ExtratoScreen extends ConsumerStatefulWidget {
  const ExtratoScreen({super.key});
  @override
  ConsumerState<ExtratoScreen> createState() => _ExtratoScreenState();
}

class _ExtratoScreenState extends ConsumerState<ExtratoScreen> {
  String _tipoAba = 'despesa';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _query = '';
  
  // Filtros Avançados
  bool _showFilters = false;
  double? _valMin;
  double? _valMax;
  DateTime? _dataIni;
  DateTime? _dataFim;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
        ref.read(pagedTransacoesProvider.notifier).fetchNextPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> _confirmarExclusao(Map<String, dynamic> t) async {
    final valor = (t['valor'] as num).toDouble();
    final desc = t['descricao'] ?? 'Transação';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir transação?', style: TextStyle(color: AppColors.tx)),
        content: Text(
          '$desc\nR\$ ${valor.toStringAsFixed(2)}\n\nO saldo será restaurado automaticamente.',
          style: const TextStyle(color: AppColors.mu, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.mu)),
          ),
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
      ref.invalidate(pagedTransacoesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Transação excluída com sucesso'),
          backgroundColor: AppColors.grn,
        ));
      }
      return true;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red));
      return false;
    }
  }

  void _abrirExport(String formato) async {
    final perfil = ref.read(perfilUsuarioLogadoProvider).value;
    if (perfil == null) return;

    final base = ApiService.baseUrl;
    String url = "$base/transacoes/export?familia_id=${perfil['familia_id']}&formato=$formato";
    
    if (_query.isNotEmpty) url += "&q=${Uri.encodeComponent(_query)}";
    if (_valMin != null) url += "&valor_min=$_valMin";
    if (_valMax != null) url += "&valor_max=$_valMax";
    
    await launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final selectedUser = ref.watch(usuarioFiltroProvider);
    final pagedAsync = ref.watch(pagedTransacoesProvider);
    final allTransacoes = pagedAsync.value ?? [];
    final isLoading = pagedAsync.isLoading;
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(mesLabelLongo(ref.watch(mesAtualProvider)), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, size: 20, color: AppColors.mu),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LixeiraScreen())),
              tooltip: 'Lixeira',
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: AppColors.acc),
              onPressed: () => _abrirExport('pdf'),
              tooltip: 'Exportar PDF',
            ),
            IconButton(
              icon: const Icon(Icons.table_chart_outlined, size: 20, color: AppColors.grn),
              onPressed: () => _abrirExport('csv'),
              tooltip: 'Exportar CSV',
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            onTap: (index) => setState(() => _tipoAba = index == 0 ? 'despesa' : 'receita'),
            indicatorColor: _tipoAba == 'despesa' ? AppColors.red : AppColors.grn,
            labelColor: _tipoAba == 'despesa' ? AppColors.red : AppColors.grn,
            unselectedLabelColor: AppColors.mu,
            tabs: const [
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.arrow_downward, size: 16), SizedBox(width: 8), Text('Despesas')])),
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.arrow_upward, size: 16), SizedBox(width: 8), Text('Receitas')])),
            ],
          ),
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SizedBox(height: 50, child: SeletorUsuario()),
            ),
            _buildSearchBar(),
            if (_showFilters) _buildFiltersPanel(),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildLista(tipo: 'despesa', user: selectedUser, transacoes: allTransacoes, loading: isLoading),
                  _buildLista(tipo: 'receita', user: selectedUser, transacoes: allTransacoes, loading: isLoading),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: (v) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && v == _searchController.text) setState(() => _query = v);
              });
            },
            decoration: InputDecoration(
              hintText: 'Buscar na descrição...',
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.mu),
              filled: true,
              fillColor: AppColors.surf,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => setState(() => _showFilters = !_showFilters),
          icon: Icon(Icons.tune, color: _showFilters ? AppColors.acc : AppColors.mu),
          style: IconButton.styleFrom(backgroundColor: AppColors.surf, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ],
    ),
  );

  Widget _buildFiltersPanel() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.bord)),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: _filterInput('Min (R\$)', (v) => setState(() => _valMin = double.tryParse(v)))),
            const SizedBox(width: 12),
            Expanded(child: _filterInput('Max (R\$)', (v) => setState(() => _valMax = double.tryParse(v)))),
          ],
        ),
      ],
    ),
  );

  Widget _filterInput(String hint, Function(String) onChange) => TextField(
    keyboardType: TextInputType.number,
    style: const TextStyle(fontSize: 12),
    onChanged: onChange,
    decoration: InputDecoration(
      hintText: hint,
      isDense: true,
      hintStyle: const TextStyle(fontSize: 10, color: AppColors.mu),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      fillColor: AppColors.bg,
      filled: true,
    ),
  );

  Widget _buildLista({
    required String tipo, 
    String? user, 
    required List<Map<String, dynamic>> transacoes,
    required bool loading,
  }) {
    final filtradas = transacoes.where((t) {
      if (t['tipo'] != tipo) return false;
      if (user != null && t['usuarios']['nome'] != user) return false;
      
      if (_query.isNotEmpty) {
        final desc = (t['descricao'] ?? '').toString().toLowerCase();
        if (!desc.contains(_query.toLowerCase())) return false;
      }
      
      if (_valMin != null && t['valor'] < _valMin!) return false;
      if (_valMax != null && t['valor'] > _valMax!) return false;
      
      return true;
    }).toList();

    final total = filtradas.fold<double>(0, (sum, item) => sum + (item['valor'] as num).toDouble());
    final isDespesa = tipo == 'despesa';

    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (var t in filtradas) {
      final date = DateFormat('dd/MM').format(DateTime.parse(t['created_at']));
      groups[date] = groups[date] ?? [];
      groups[date]!.add(t);
    }

    final sortedDates = groups.keys.toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pagedTransacoesProvider);
      },
      backgroundColor: AppColors.surf,
      color: isDespesa ? AppColors.red : AppColors.grn,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: (isDespesa ? AppColors.red : AppColors.grn).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (isDespesa ? AppColors.red : AppColors.grn).withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${filtradas.length} registros', style: const TextStyle(fontSize: 12, color: AppColors.mu)),
                Text(
                  '${isDespesa ? '-' : '+'} ${NumberFormat.simpleCurrency(locale: 'pt_BR').format(total)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDespesa ? AppColors.red : AppColors.grn),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          if (filtradas.isEmpty && !loading)
            const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Text('Nenhum registro', style: TextStyle(color: AppColors.mu)))),

          ...sortedDates.map((date) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 8, top: 4),
                child: Text(date, style: const TextStyle(fontSize: 11, color: AppColors.mu, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: groups[date]!.asMap().entries.map((entry) {
                    final i = entry.key;
                    final t = entry.value;
                    return Column(
                      children: [
                        if (i > 0) const Divider(height: 1, color: AppColors.bord, indent: 14, endIndent: 14),
                        Dismissible(
                          key: Key(t['id']),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmarExclusao(t),
                          background: Container(color: AppColors.red.withOpacity(0.1), alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete_outline, color: AppColors.red)),
                          child: GestureDetector(
                            onTap: () => showModalBottomSheet(
                              context: context, 
                              isScrollControlled: true, 
                              backgroundColor: Colors.transparent, 
                              builder: (_) => EditTransacaoSheet(transacao: t)
                            ),
                            child: TransacaoItem(t: t),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          )),

          if (loading) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}
