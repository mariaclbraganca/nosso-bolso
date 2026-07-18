import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/saude_provider.dart';
import '../../../providers/usuarios_provider.dart';
import '../../../services/saude_api_service.dart';

class SugestaoJantarScreen extends ConsumerStatefulWidget {
  final String membroId;

  const SugestaoJantarScreen({super.key, required this.membroId});

  @override
  ConsumerState<SugestaoJantarScreen> createState() => _SugestaoJantarScreenState();
}

class _SugestaoJantarScreenState extends ConsumerState<SugestaoJantarScreen> {
  bool _carregando = false;
  Map<String, dynamic>? _resultado;
  String? _erro;
  List<String> _itensConfirmadosAusentes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buscarSugestoes());
  }

  Future<void> _buscarSugestoes() async {
    final perfil = ref.read(perfilUsuarioLogadoProvider).asData?.value;
    if (perfil == null) return;
    final familiaId = perfil['familia_id'] as String? ?? '';

    setState(() { _carregando = true; _erro = null; });
    try {
      final resultado = await SaudeApiService.getSugestaoJantar(
        familiaId,
        [widget.membroId],
        itensAusentes: _itensConfirmadosAusentes,
      );
      setState(() { _resultado = resultado; _carregando = false; });
    } catch (e) {
      setState(() { _erro = e.toString(); _carregando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.tx),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Sugestão de Jantar',
            style: TextStyle(color: AppColors.tx, fontSize: 18, fontWeight: FontWeight.bold)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(color: AppColors.bord, height: 0.5),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildSubtitle()),
          if (_carregando)
            const SliverFillRemaining(
              child: Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.grn),
                  SizedBox(height: 16),
                  Text('Analisando estoque e metas...', style: TextStyle(color: AppColors.mu)),
                ],
              )),
            )
          else if (_erro != null)
            SliverFillRemaining(child: _buildErro())
          else if (_resultado == null || (_resultado!['sugestoes'] as List?)?.isEmpty == true)
            SliverFillRemaining(child: _buildVazio())
          else ...[
            SliverToBoxAdapter(child: _buildItemsSuspeitos()),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final sugestoes = (_resultado!['sugestoes'] as List).cast<Map<String, dynamic>>();
                  return _SugestaoCard(
                    sugestao: sugestoes[i],
                    index: i,
                    onRegistrar: () => _registrarSugestao(sugestoes[i]),
                  );
                },
                childCount: (_resultado!['sugestoes'] as List?)?.length ?? 0,
              ),
            ),
            SliverToBoxAdapter(child: _buildRodape()),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        'Baseada no seu estoque e metas do dia',
        style: TextStyle(fontSize: 13, color: AppColors.mu),
      ),
    );
  }

  Widget _buildItemsSuspeitos() {
    final suspeitos = (_resultado?['itens_suspeitos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (suspeitos.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.org.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.org.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Verificação Rápida',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.org)),
          const SizedBox(height: 8),
          ...suspeitos.map((item) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${item['nome']} (${item['dias_na_geladeira']}d)',
                  style: const TextStyle(color: AppColors.tx, fontSize: 12),
                ),
              ),
              Row(children: [
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const Text('✅ Sim', style: TextStyle(color: AppColors.grn, fontSize: 12)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _itensConfirmadosAusentes.add(item['nome'] as String));
                    _buscarSugestoes();
                  },
                  style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const Text('❌ Não', style: TextStyle(color: AppColors.red, fontSize: 12)),
                ),
              ]),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_rounded, color: AppColors.org, size: 48),
            const SizedBox(height: 16),
            const Text('Erro ao buscar sugestões',
                style: TextStyle(color: AppColors.tx, fontSize: 16)),
            const SizedBox(height: 8),
            Text(_erro ?? '',
                style: const TextStyle(color: AppColors.mu, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.grn,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
              ),
              onPressed: _buscarSugestoes,
              child: const Text('Tentar Novamente', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVazio() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🍽️', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text('Sem estoque para sugestões',
                style: TextStyle(color: AppColors.tx, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            SizedBox(height: 8),
            Text(
              'Registre compras para que o agente saiba o que há na sua despensa.',
              style: TextStyle(color: AppColors.mu, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRodape() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.grn,
          side: const BorderSide(color: AppColors.grn),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
        ),
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Gerar Novas Sugestões'),
        onPressed: _buscarSugestoes,
      ),
    );
  }

  Future<void> _registrarSugestao(Map<String, dynamic> sugestao) async {
    final perfil = ref.read(perfilUsuarioLogadoProvider).asData?.value;
    if (perfil == null) return;

    final ingredientes = (sugestao['ingredientes_usados'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final totais = {
      'calorias_kcal':  sugestao['calorias_kcal']  ?? 0,
      'proteina_g':     sugestao['proteina_g']     ?? 0,
      'carboidrato_g':  sugestao['carboidrato_g']  ?? 0,
      'gordura_g':      sugestao['gordura_g']      ?? 0,
    };

    final now  = DateTime.now();
    final data = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      await SaudeApiService.registrarRefeicao({
        'membro_id':          widget.membroId,
        'familia_id':         perfil['familia_id'],
        'tipo_refeicao':      'jantar',
        'modalidade_entrada': 'sugestao',
        'descricao':          sugestao['nome'] ?? 'Jantar sugerido',
        'itens_identificados': ingredientes,
        'macros_totais':      totais,
        'confianca_ia':       0.9,
        'confirmado_usuario': true,
        'data_refeicao':      data,
      });

      ref.invalidate(extratoDiarioProvider);
      ref.invalidate(refeicoesDiaProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jantar registrado com sucesso!'),
            backgroundColor: AppColors.grn,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }
}

class _SugestaoCard extends StatelessWidget {
  final Map<String, dynamic> sugestao;
  final int index;
  final VoidCallback onRegistrar;

  const _SugestaoCard({
    required this.sugestao,
    required this.index,
    required this.onRegistrar,
  });

  @override
  Widget build(BuildContext context) {
    final ingredientes  = (sugestao['ingredientes_usados'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final substituicoes = (sugestao['substituicoes'] as List?)?.cast<String>() ?? [];
    final preparo       = sugestao['preparo_minutos'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppColors.grn.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text('${index + 1}',
                    style: const TextStyle(color: AppColors.grn, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sugestao['nome'] as String? ?? '',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.tx)),
                    if (preparo > 0)
                      Text('⏱ $preparo min de preparo',
                          style: const TextStyle(fontSize: 11, color: AppColors.mu)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 4,
            children: [
              _chip('${sugestao['calorias_kcal'] ?? 0} kcal', AppColors.acc),
              _chip('P: ${sugestao['proteina_g'] ?? 0}g',     AppColors.blu),
              _chip('C: ${sugestao['carboidrato_g'] ?? 0}g',  AppColors.org),
              _chip('G: ${sugestao['gordura_g'] ?? 0}g',      AppColors.pur),
            ],
          ),
          if (ingredientes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Ingredientes: ${ingredientes.map((i) => '${i['nome']} (${i['quantidade_g'] ?? 0}g)').join(', ')}',
              style: const TextStyle(fontSize: 11, color: AppColors.mu),
            ),
          ],
          if (sugestao['modo_preparo_resumido'] != null) ...[
            const SizedBox(height: 6),
            Text(sugestao['modo_preparo_resumido'] as String,
                style: const TextStyle(fontSize: 12, color: AppColors.mu),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (substituicoes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surf,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Substituições:',
                      style: TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold)),
                  ...substituicoes.map((s) =>
                      Text('• $s', style: const TextStyle(fontSize: 11, color: AppColors.mu))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.grn,
                side: const BorderSide(color: AppColors.grn),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
              ),
              onPressed: onRegistrar,
              child: const Text('Registrar esta refeição',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}
