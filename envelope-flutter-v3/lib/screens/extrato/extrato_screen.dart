import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/mes_provider.dart';
import '../../core/providers/transacoes_provider.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../retrospectiva/retrospectiva_screen.dart';
import 'exportar_dialog.dart';
import 'lixeira_screen.dart';
import 'relatorios_tab.dart';
import 'resumo_mensal_screen.dart';
import 'widgets/extrato_filtros_bar.dart';
import 'widgets/extrato_lista_view.dart';
import 'widgets/extrato_resumo_header.dart';

enum AbaExtrato { despesas, receitas, aportes, relatorios }

class ExtratoScreen extends ConsumerStatefulWidget {
  const ExtratoScreen({super.key});

  @override
  ConsumerState<ExtratoScreen> createState() => _ExtratoScreenState();
}

class _ExtratoScreenState extends ConsumerState<ExtratoScreen> {
  AbaExtrato _aba = AbaExtrato.despesas;
  final _buscaCtrl = TextEditingController();
  String _termoBusca = '';
  Timer? _debounce;
  String? _envelopeFiltroId;
  String? _usuarioFiltroId;

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaCtrl.dispose();
    super.dispose();
  }

  void _onBuscaChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _termoBusca = q.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final mes = ref.watch(mesAtualProvider);
    final todasTransacoes = ref.watch(transacoesComDetalhesProvider);
    final nomeMes = mesLabelLongo(mes);

    final transacoesAba = todasTransacoes.where((t) {
      final tipo = t['tipo'] as String? ?? 'despesa';
      if (_aba == AbaExtrato.despesas) return tipo == 'despesa';
      if (_aba == AbaExtrato.receitas) return tipo == 'receita';
      if (_aba == AbaExtrato.aportes) return tipo == 'abastecimento';
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _escolherMes(context, mes),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(nomeMes, style: NBText.secao),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: NBColors.cartao,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NBRadius.cartao)),
            onSelected: (val) {
              if (val == 'meses') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RetrospectivaScreen()));
              } else if (val == 'resumo') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumoMensalScreen()));
              } else if (val == 'lixeira') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LixeiraScreen()));
              } else if (val == 'exportar') {
                showDialog(context: context, builder: (_) => ExportarDialog(transacoes: todasTransacoes, mes: mes));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'meses', child: Row(children: [Icon(Icons.history_rounded, size: 18), SizedBox(width: 10), Text('Meses fechados')])),
              const PopupMenuItem(value: 'resumo', child: Row(children: [Icon(Icons.pie_chart_outline_rounded, size: 18), SizedBox(width: 10), Text('Relatórios do mês')])),
              const PopupMenuItem(value: 'exportar', child: Row(children: [Icon(Icons.download_rounded, size: 18), SizedBox(width: 10), Text('Exportar PDF ou CSV')])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'lixeira', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: NBColors.estouro), SizedBox(width: 10), Text('Lixeira', style: TextStyle(color: NBColors.estouro))])),
            ],
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: NBSpacing.margemTela),
              child: Segmentado<AbaExtrato>(
                opcoes: const {
                  AbaExtrato.despesas: 'Despesas',
                  AbaExtrato.receitas: 'Receitas',
                  AbaExtrato.aportes: 'Aportes',
                  AbaExtrato.relatorios: 'Relatórios',
                },
                valor: _aba,
                onChanged: (a) => setState(() => _aba = a),
              ),
            ),
            const SizedBox(height: 10),
            if (_aba == AbaExtrato.relatorios)
              const Expanded(child: RelatoriosTab())
            else
              Expanded(
                child: RefreshIndicator(
                  color: NBColors.verde,
                  onRefresh: () async => ref.invalidate(transacoesStreamProvider),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 120),
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: NBSpacing.margemTela),
                        child: ExtratoResumoHeader(),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: NBSpacing.margemTela),
                        child: TextField(
                          controller: _buscaCtrl,
                          onChanged: _onBuscaChanged,
                          style: NBText.corpo,
                          decoration: InputDecoration(
                            hintText: 'Buscar por descrição ou envelope...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _buscaCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _buscaCtrl.clear();
                                      setState(() => _termoBusca = '');
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ExtratoFiltrosBar(
                        envelopeFiltroId: _envelopeFiltroId,
                        usuarioFiltroId: _usuarioFiltroId,
                        onEnvelopeChanged: (id) => setState(() => _envelopeFiltroId = id),
                        onUsuarioChanged: (id) => setState(() => _usuarioFiltroId = id),
                      ),
                      ExtratoListaView(
                        transacoes: transacoesAba,
                        termoBusca: _termoBusca,
                        envelopeFiltroId: _envelopeFiltroId,
                        usuarioFiltroId: _usuarioFiltroId,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _escolherMes(BuildContext context, String mesAtual) async {
    final meses = gerarMesesDisponiveis();
    final escolhido = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const TopoSheet(titulo: 'Escolha o mês'),
            const SizedBox(height: 12),
            for (final m in meses)
              ListTile(
                title: Text(mesLabelLongo(m), style: NBText.corpo),
                selected: m == mesAtual,
                selectedColor: NBColors.verde,
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (escolhido != null) ref.read(mesAtualProvider.notifier).state = escolhido;
  }
}
