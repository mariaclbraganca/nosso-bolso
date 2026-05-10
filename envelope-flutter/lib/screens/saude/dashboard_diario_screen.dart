import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/saude_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/saude_api_service.dart';
import '../../widgets/saude/macro_progress_ring.dart';
import '../../widgets/saude/macro_bar.dart';
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
      child: Row(
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
