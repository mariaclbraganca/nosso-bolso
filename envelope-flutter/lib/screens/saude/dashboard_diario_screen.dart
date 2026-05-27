import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/saude_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/saude_api_service.dart';
import '../../widgets/saude/macro_progress_ring.dart';
import '../../widgets/saude/macro_bar.dart';
import '../../widgets/saude/meal_timeline.dart';
import '../../widgets/saude/refeicao_card.dart';
import '../../widgets/saude/hidratacao_widget.dart';
import 'anamnese_screen.dart';

class DashboardDiarioScreen extends ConsumerWidget {
  final String membroId;

  const DashboardDiarioScreen({super.key, required this.membroId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(perfilMetabolicoProvider(membroId));

    return perfilAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.grn)),
      error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: AppColors.red))),
      data: (perfil) {
        if (perfil == null) {
          return _SemPerfilView(membroId: membroId);
        }
        return _DashboardContent(membroId: membroId, perfil: perfil);
      },
    );
  }
}

class _SemPerfilView extends StatelessWidget {
  final String membroId;
  const _SemPerfilView({required this.membroId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🥗', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Configure seu perfil nutricional',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.tx),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Responda uma anamnese rápida para calcular suas metas de calorias e macros.',
              style: TextStyle(fontSize: 14, color: AppColors.mu),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.grn,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AnamneseScreen(membroId: membroId)),
              ),
              child: const Text('Começar Anamnese', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  final String membroId;
  final Map<String, dynamic> perfil;

  const _DashboardContent({required this.membroId, required this.perfil});

  String get _hoje {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extratoAsync = ref.watch(extratoDiarioProvider((membroId: membroId, data: _hoje)));
    final refeicaoAsync = ref.watch(refeicoesDiaProvider((membroId: membroId, data: _hoje)));
    final hidraAsync = ref.watch(hidratacaoDiaProvider((membroId: membroId, data: _hoje)));
    final familiaId = ref.watch(perfilUsuarioLogadoProvider).asData?.value?['familia_id'] as String? ?? '';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(extratoDiarioProvider);
        ref.invalidate(refeicoesDiaProvider);
        ref.invalidate(hidratacaoDiaProvider);
      },
      color: AppColors.grn,
      backgroundColor: AppColors.surf,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(
            child: extratoAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: AppColors.grn)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erro ao carregar extrato: $e', style: const TextStyle(color: AppColors.red)),
              ),
              data: (extrato) => _buildExtrato(context, ref, extrato, familiaId),
            ),
          ),
          SliverToBoxAdapter(
            child: hidraAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (hidra) => _buildHidratacao(context, ref, hidra, familiaId),
            ),
          ),
          SliverToBoxAdapter(
            child: refeicaoAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (refeicoes) => refeicoes.isEmpty
                  ? const SizedBox.shrink()
                  : MealTimeline(refeicoes: refeicoes),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 16, 14, 8),
              child: Text(
                'REFEIÇÕES DE HOJE',
                style: TextStyle(fontSize: 11, color: AppColors.mu, letterSpacing: 0.8, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          refeicaoAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator(color: AppColors.grn)),
            ),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (refeicoes) => refeicoes.isEmpty
                ? SliverToBoxAdapter(child: _buildVazio())
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => RefeicaoCard(
                        refeicao: refeicoes[i],
                        onDelete: () => _deletarRefeicao(context, ref, refeicoes[i]['id'] as String? ?? ''),
                      ),
                      childCount: refeicoes.length,
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final weekdays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    final months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Text(
        '${weekdays[now.weekday % 7]}, ${now.day} de ${months[now.month - 1]}',
        style: const TextStyle(fontSize: 13, color: AppColors.mu),
      ),
    );
  }

  Widget _buildExtrato(BuildContext context, WidgetRef ref, Map<String, dynamic> extrato, String familiaId) {
    final kcalCons = (extrato['calorias_consumidas_kcal'] as num?)?.toDouble() ?? 0;
    final kcalMeta = (extrato['meta_calorica_kcal'] as num?)?.toDouble() ?? 2000;
    final protCons = (extrato['proteina_consumida_g'] as num?)?.toDouble() ?? 0;
    final protMeta = (extrato['proteina_meta_g'] as num?)?.toDouble() ?? 150;
    final carbCons = (extrato['carboidrato_consumido_g'] as num?)?.toDouble() ?? 0;
    final carbMeta = (extrato['carboidrato_meta_g'] as num?)?.toDouble() ?? 200;
    final gordCons = (extrato['gordura_consumida_g'] as num?)?.toDouble() ?? 0;
    final gordMeta = (extrato['gordura_meta_g'] as num?)?.toDouble() ?? 70;
    final fibraCons = (extrato['fibra_consumida_g'] as num?)?.toDouble() ?? 0;
    final fibraMeta = (extrato['fibra_meta_g'] as num?)?.toDouble() ?? 25;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: MacroProgressRing(consumido: kcalCons, meta: kcalMeta, size: 160),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              MacroBar(label: 'Proteína', consumido: protCons, meta: protMeta, color: AppColors.blu),
              const SizedBox(height: 10),
              MacroBar(label: 'Carboidrato', consumido: carbCons, meta: carbMeta, color: AppColors.org),
              const SizedBox(height: 10),
              MacroBar(label: 'Gordura', consumido: gordCons, meta: gordMeta, color: AppColors.pur),
              const SizedBox(height: 10),
              MacroBar(label: 'Fibra', consumido: fibraCons, meta: fibraMeta, color: AppColors.grn),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildAcoesRapidas(context, ref, familiaId),
      ],
    );
  }

  Widget _buildAcoesRapidas(BuildContext context, WidgetRef ref, String familiaId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _AcaoRapida(
                  icon: Icons.nightlight_round,
                  label: 'Pular / Jejum',
                  color: AppColors.pur,
                  onTap: () => _registrarJejum(context, ref, familiaId),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AcaoRapida(
                  icon: Icons.monitor_weight_rounded,
                  label: 'Registrar Peso',
                  color: AppColors.acc,
                  onTap: () => _registrarPeso(context, ref, familiaId),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _AcaoRapida(
            icon: Icons.auto_awesome,
            label: 'Sugerir Próxima Refeição',
            color: AppColors.org,
            onTap: () => _mostrarSugestaoRefeicao(context, familiaId),
          ),
        ],
      ),
    );
  }

  void _mostrarSugestaoRefeicao(BuildContext context, String familiaId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SugestaoRefeicaoSheet(
        membroId: membroId,
        familiaId: familiaId,
      ),
    );
  }

  Widget _buildHidratacao(BuildContext context, WidgetRef ref, Map<String, dynamic> hidra, String familiaId) {
    final total = (hidra['total_ml'] as num?)?.toInt() ?? 0;
    final meta = (hidra['meta_ml'] as num?)?.toInt() ?? 2000;

    return HidratacaoWidget(
      totalMl: total,
      metaMl: meta,
      onRegistrar: () => _registrarAgua(ref, familiaId),
    );
  }

  Widget _buildVazio() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Text(
          'Nenhuma refeição registrada hoje.\nToque no + para registrar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.mu, fontSize: 14),
        ),
      ),
    );
  }

  Future<void> _registrarAgua(WidgetRef ref, String familiaId) async {
    try {
      await SaudeApiService.registrarHidratacao(membroId, familiaId, volumeMl: 250);
      ref.invalidate(hidratacaoDiaProvider);
    } catch (_) {}
  }

  Future<void> _deletarRefeicao(BuildContext context, WidgetRef ref, String id) async {
    if (id.isEmpty) return;
    try {
      await SaudeApiService.deletarRefeicao(id);
      ref.invalidate(refeicoesDiaProvider);
      ref.invalidate(extratoDiarioProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao deletar: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  void _registrarJejum(BuildContext context, WidgetRef ref, String familiaId) {
    final tipos = [
      ('cafe_da_manha', 'Café da Manhã'),
      ('lanche_manha', 'Lanche da Manhã'),
      ('almoco', 'Almoço'),
      ('lanche_tarde', 'Lanche da Tarde'),
      ('jantar', 'Jantar'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('🌿 Pular qual refeição?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.tx)),
          ),
          ...tipos.map((t) => ListTile(
            title: Text(t.$2, style: const TextStyle(color: AppColors.tx)),
            onTap: () async {
              Navigator.pop(context);
              final now = DateTime.now();
              final data = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
              try {
                await SaudeApiService.registrarRefeicao({
                  'membro_id': membroId,
                  'familia_id': familiaId,
                  'tipo_refeicao': t.$1,
                  'is_jejum': true,
                  'motivo_jejum': 'nao_tive_fome',
                  'modalidade_entrada': 'manual',
                  'data_refeicao': data,
                });
                ref.invalidate(refeicoesDiaProvider);
                ref.invalidate(extratoDiarioProvider);
              } catch (_) {}
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _registrarPeso(BuildContext context, WidgetRef ref, String familiaId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Registrar Peso', style: TextStyle(color: AppColors.tx)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppColors.tx),
          decoration: const InputDecoration(
            hintText: 'Ex: 74.5',
            hintStyle: TextStyle(color: AppColors.mu),
            suffixText: 'kg',
            suffixStyle: TextStyle(color: AppColors.mu),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.grn),
            onPressed: () async {
              final peso = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (peso == null) return;
              Navigator.pop(context);
              final now = DateTime.now();
              try {
                await SaudeApiService.registrarPeso({
                  'membro_id': membroId,
                  'familia_id': familiaId,
                  'peso_kg': peso,
                  'data_medicao': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
                });
              } catch (_) {}
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

class _AcaoRapida extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AcaoRapida({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3), width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _SugestaoRefeicaoSheet extends StatefulWidget {
  final String membroId;
  final String familiaId;
  const _SugestaoRefeicaoSheet({required this.membroId, required this.familiaId});

  @override
  State<_SugestaoRefeicaoSheet> createState() => _SugestaoRefeicaoSheetState();
}

class _SugestaoRefeicaoSheetState extends State<_SugestaoRefeicaoSheet> {
  Map<String, dynamic>? _sugestao;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final res = await SaudeApiService.getSugestaoJantar(
        widget.familiaId,
        [widget.membroId],
      );
      if (mounted) setState(() => _sugestao = res);
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2)),
                margin: const EdgeInsets.only(bottom: 16),
              ),
            ),
            Row(children: [
              const Icon(Icons.auto_awesome, color: AppColors.org, size: 18),
              const SizedBox(width: 8),
              const Text('Sugestão de Refeição', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.tx)),
            ]),
            const SizedBox(height: 16),
            if (_erro != null)
              Text('Erro: $_erro', style: const TextStyle(color: AppColors.red))
            else if (_sugestao == null)
              const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(children: [
                  CircularProgressIndicator(color: AppColors.org),
                  SizedBox(height: 12),
                  Text('Analisando seu saldo de macros...', style: TextStyle(color: AppColors.mu, fontSize: 13)),
                ]),
              ))
            else
              Expanded(
                child: ListView(controller: ctrl, children: [
                  _buildSugestaoContent(_sugestao!),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSugestaoContent(Map<String, dynamic> s) {
    final titulo = s['titulo'] as String? ?? s['nome'] as String? ?? 'Sugestão';
    final descricao = s['descricao'] as String? ?? s['sugestao'] as String? ?? s['texto'] as String? ?? '';
    final macros = s['macros'] as Map<String, dynamic>? ?? {};
    final motivo = s['motivo'] as String? ?? s['justificativa'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.org)),
        if (descricao.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(descricao, style: const TextStyle(fontSize: 14, color: AppColors.tx, height: 1.5)),
        ],
        if (macros.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in macros.entries)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surf,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.bord),
                ),
                child: Text('${entry.key}: ${entry.value}', style: const TextStyle(fontSize: 12, color: AppColors.mu)),
              ),
          ]),
        ],
        if (motivo.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.org.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.org.withOpacity(0.2)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, color: AppColors.org, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(motivo, style: const TextStyle(fontSize: 12, color: AppColors.org, height: 1.4))),
            ]),
          ),
        ],
        if (s.containsKey('itens') && s['itens'] is List) ...[
          const SizedBox(height: 16),
          const Text('Ingredientes', style: TextStyle(fontSize: 12, color: AppColors.mu, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final item in (s['itens'] as List))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Icon(Icons.circle, size: 5, color: AppColors.mu),
                const SizedBox(width: 8),
                Expanded(child: Text(item.toString(), style: const TextStyle(fontSize: 13, color: AppColors.tx))),
              ]),
            ),
        ],
      ],
    );
  }
}
