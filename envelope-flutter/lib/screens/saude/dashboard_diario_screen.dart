import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/saude_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/saude_api_service.dart';
import '../../widgets/saude/macro_progress_ring.dart';
import '../../widgets/saude/macro_bar.dart';
import '../../widgets/saude/meal_slot_card.dart';
import '../../widgets/saude/morning_digest_card.dart';
import '../../widgets/saude/hidratacao_widget.dart';
import 'anamnese_screen.dart';
import 'registrar_refeicao_sheet.dart';

// ── Definição dos slots do dia ────────────────────────────────────────────────

class _Slot {
  final String tipo;
  final IconData icon;
  final String label;
  final String horarioDica;

  const _Slot(this.tipo, this.icon, this.label, this.horarioDica);
}

const _kSlots = [
  _Slot('cafe_da_manha', Icons.coffee_rounded,       'Café da manhã',  '7h – 9h'),
  _Slot('almoco',        Icons.restaurant_rounded,   'Almoço',         '12h – 14h'),
  _Slot('lanche_tarde',  Icons.cookie_rounded,       'Lanche',         '15h – 17h'),
  _Slot('jantar',        Icons.nightlight_round,     'Jantar',         '19h – 21h'),
];

// ── Tela principal ────────────────────────────────────────────────────────────

class DashboardDiarioScreen extends ConsumerWidget {
  final String membroId;

  const DashboardDiarioScreen({super.key, required this.membroId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(perfilMetabolicoProvider(membroId));

    return perfilAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.grn)),
      error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: AppColors.red))),
      data: (perfil) => perfil == null
          ? _SemPerfilView(membroId: membroId)
          : _DashboardContent(membroId: membroId),
    );
  }
}

// ── Sem perfil ────────────────────────────────────────────────────────────────

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
              'Vamos montar seu plano nutricional!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.tx),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Responda algumas perguntas rápidas e receba suas metas de calorias e nutrientes personalizadas.',
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
              child: const Text('Criar meu plano', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Conteúdo principal ────────────────────────────────────────────────────────

class _DashboardContent extends ConsumerStatefulWidget {
  final String membroId;
  const _DashboardContent({required this.membroId});

  @override
  ConsumerState<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<_DashboardContent> {
  String get _hoje {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final extratoAsync  = ref.watch(extratoDiarioProvider((membroId: widget.membroId, data: _hoje)));
    final refeicaoAsync = ref.watch(refeicoesDiaProvider((membroId: widget.membroId, data: _hoje)));
    final hidraAsync    = ref.watch(hidratacaoDiaProvider((membroId: widget.membroId, data: _hoje)));
    final streakAsync   = ref.watch(streakProvider(widget.membroId));
    final familiaId = ref.watch(perfilUsuarioLogadoProvider).asData?.value?['familia_id'] as String? ?? '';
    final nomeCompleto  = ref.watch(perfilUsuarioLogadoProvider).asData?.value?['nome'] as String? ?? '';
    final nome          = nomeCompleto.split(' ').first;

    // Morning digest — carregado em background, não bloqueia a tela
    final digestAsync = ref.watch(morningDigestProvider((membroId: widget.membroId, familiaId: familiaId)));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(extratoDiarioProvider);
        ref.invalidate(refeicoesDiaProvider);
        ref.invalidate(hidratacaoDiaProvider);
        ref.invalidate(streakProvider);
      },
      color: AppColors.grn,
      backgroundColor: AppColors.surf,
      child: CustomScrollView(
        slivers: [
          // 1 — Saudação personalizada
          SliverToBoxAdapter(
            child: extratoAsync.when(
              loading: () => _buildGreeting(nome, streakAsync.value ?? 0, null),
              error:   (_, __) => _buildGreeting(nome, streakAsync.value ?? 0, null),
              data:    (e) => _buildGreeting(nome, streakAsync.value ?? 0, e),
            ),
          ),

          // 2 — Morning Digest card (lazy, dismissable)
          SliverToBoxAdapter(
            child: MorningDigestCard(digestData: digestAsync.value),
          ),

          // 3 — Anel calórico
          SliverToBoxAdapter(
            child: extratoAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: AppColors.grn)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erro ao carregar dados: $e', style: const TextStyle(color: AppColors.red)),
              ),
              data: (extrato) => _buildAnelCalorico(extrato),
            ),
          ),

          // 4 — Banner de celebração
          SliverToBoxAdapter(
            child: extratoAsync.maybeWhen(
              data: (e) {
                final cons = (e['calorias_consumidas_kcal'] as num?)?.toDouble() ?? 0;
                final meta = (e['meta_calorica_kcal'] as num?)?.toDouble() ?? 2000;
                if (meta > 0 && cons >= meta * 0.95) return _buildCelebracaoBanner(cons, meta);
                return const SizedBox.shrink();
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ),

          // 5 — Meal slots
          SliverToBoxAdapter(
            child: refeicaoAsync.when(
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
              data:    (refeicoes) => _buildMealSlots(context, ref, refeicoes, familiaId),
            ),
          ),

          // 6 — Macros secundários
          SliverToBoxAdapter(
            child: extratoAsync.maybeWhen(
              data: (e) => _buildMacros(e),
              orElse: () => const SizedBox.shrink(),
            ),
          ),

          // 7 — Hidratação
          SliverToBoxAdapter(
            child: hidraAsync.when(
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
              data:    (h) => _buildHidratacao(context, ref, h, familiaId),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── Saudação ──────────────────────────────────────────────────────────────

  Widget _buildGreeting(String nome, int streak, Map<String, dynamic>? extrato) {
    final h    = DateTime.now().hour;
    final saud = h < 12 ? 'Bom dia' : h < 18 ? 'Boa tarde' : 'Boa noite';
    final nomeStr = nome.isNotEmpty ? ', $nome' : '';
    final status   = _statusMsg(extrato);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$saud$nomeStr!',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.tx),
                ),
                const SizedBox(height: 3),
                Text(status, style: const TextStyle(fontSize: 13, color: AppColors.mu)),
              ],
            ),
          ),
          if (streak >= 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.org.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.org.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(
                    '$streak dias',
                    style: const TextStyle(fontSize: 12, color: AppColors.org, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _statusMsg(Map<String, dynamic>? extrato) {
    if (extrato == null) return 'Carregando seu dia...';
    final count = (extrato['refeicoes_count'] as num?)?.toInt() ?? 0;
    final cons  = (extrato['calorias_consumidas_kcal'] as num?)?.toDouble() ?? 0;
    final meta  = (extrato['meta_calorica_kcal'] as num?)?.toDouble() ?? 2000;
    final h     = DateTime.now().hour;

    if (count == 0) {
      if (h < 10) return 'Começou o dia! Não esqueça do café da manhã ☕';
      if (h < 13) return 'Bora registrar o que você já comeu hoje?';
      return 'Vamos lá! Registre suas refeições do dia.';
    }
    if (meta <= 0) return 'Continue registrando suas refeições!';
    final pct = cons / meta;
    if (pct >= 0.95) return 'Meta calórica batida! Dia incrível 🎯';
    if (pct >= 0.6)  return 'No caminho certo! Continue assim 💪';
    if (pct >= 0.3)  return 'Bom progresso! Lembre das próximas refeições.';
    return 'Ótimo começo! Continue registrando o dia.';
  }

  // ── Anel calórico ─────────────────────────────────────────────────────────

  Widget _buildAnelCalorico(Map<String, dynamic> extrato) {
    final cons = (extrato['calorias_consumidas_kcal'] as num?)?.toDouble() ?? 0;
    final meta = (extrato['meta_calorica_kcal'] as num?)?.toDouble() ?? 2000;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Center(child: MacroProgressRing(consumido: cons, meta: meta, size: 160)),
          const SizedBox(height: 6),
          Text(
            meta > 0 ? 'Meta diária: ${meta.toInt()} kcal' : '',
            style: const TextStyle(fontSize: 11, color: AppColors.mu),
          ),
        ],
      ),
    );
  }

  // ── Banner de celebração ──────────────────────────────────────────────────

  Widget _buildCelebracaoBanner(double cons, double meta) {
    final over = cons > meta;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: over ? AppColors.org.withOpacity(0.1) : AppColors.grn.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: over ? AppColors.org.withOpacity(0.3) : AppColors.grn.withOpacity(0.3),
        ),
      ),
      child: Row(children: [
        Text(over ? '⚠️' : '🎯', style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            over
                ? 'Você passou ${(cons - meta).toInt()} kcal da meta de hoje. Tudo bem, amanhã é outro dia!'
                : 'Excelente! Você está dentro da sua meta calórica hoje!',
            style: TextStyle(
              fontSize: 13,
              color: over ? AppColors.org : AppColors.grn,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Meal slots ────────────────────────────────────────────────────────────

  Widget _buildMealSlots(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> refeicoes,
    String familiaId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text(
            'REFEIÇÕES DO DIA',
            style: TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
        ),
        ..._kSlots.map((slot) {
          final slotRefeicoes = refeicoes.where((r) => r['tipo_refeicao'] == slot.tipo).toList();
          return MealSlotCard(
            icon:         slot.icon,
            label:        slot.label,
            horarioDica:  slot.horarioDica,
            refeicoes:    slotRefeicoes,
            onRegistrar:  () => _abrirRegistro(context, familiaId, slot.tipo),
            onPular:      () => _pularSlot(context, ref, familiaId, slot.tipo, slot.label),
            onDeletar:    (id) => _deletarRefeicao(context, ref, id),
          );
        }),
      ],
    );
  }

  // ── Macro bars ────────────────────────────────────────────────────────────

  Widget _buildMacros(Map<String, dynamic> extrato) {
    final protCons = (extrato['proteina_consumida_g'] as num?)?.toDouble() ?? 0;
    final protMeta = (extrato['proteina_meta_g'] as num?)?.toDouble() ?? 150;
    final carbCons = (extrato['carboidrato_consumido_g'] as num?)?.toDouble() ?? 0;
    final carbMeta = (extrato['carboidrato_meta_g'] as num?)?.toDouble() ?? 200;
    final gordCons = (extrato['gordura_consumida_g'] as num?)?.toDouble() ?? 0;
    final gordMeta = (extrato['gordura_meta_g'] as num?)?.toDouble() ?? 70;
    final fibraCons = (extrato['fibra_consumida_g'] as num?)?.toDouble() ?? 0;
    final fibraMeta = (extrato['fibra_meta_g'] as num?)?.toDouble() ?? 25;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NUTRIENTES',
            style: TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),
          MacroBar(label: 'Proteína',    consumido: protCons,  meta: protMeta,  color: AppColors.blu),
          const SizedBox(height: 10),
          MacroBar(label: 'Carboidrato', consumido: carbCons,  meta: carbMeta,  color: AppColors.org),
          const SizedBox(height: 10),
          MacroBar(label: 'Gordura',     consumido: gordCons,  meta: gordMeta,  color: AppColors.pur),
          const SizedBox(height: 10),
          MacroBar(label: 'Fibra',       consumido: fibraCons, meta: fibraMeta, color: AppColors.grn),
        ],
      ),
    );
  }

  // ── Hidratação ────────────────────────────────────────────────────────────

  Widget _buildHidratacao(BuildContext context, WidgetRef ref, Map<String, dynamic> hidra, String familiaId) {
    final total = (hidra['total_ml'] as num?)?.toInt() ?? 0;
    final meta  = (hidra['meta_ml']  as num?)?.toInt() ?? 2000;
    return HidratacaoWidget(
      totalMl: total,
      metaMl:  meta,
      onRegistrar: () async {
        try {
          await SaudeApiService.registrarHidratacao(widget.membroId, familiaId, volumeMl: 250);
          ref.invalidate(hidratacaoDiaProvider);
        } catch (_) {}
      },
    );
  }

  // ── Ações ─────────────────────────────────────────────────────────────────

  void _abrirRegistro(BuildContext context, String familiaId, String tipo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RegistrarRefeicaoSheet(
        membroId: widget.membroId,
        familiaId: familiaId,
        initialTipo: tipo,
      ),
    ).then((_) {
      ref.invalidate(extratoDiarioProvider);
      ref.invalidate(refeicoesDiaProvider);
      ref.invalidate(streakProvider);
    });
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

  Future<void> _pularSlot(
    BuildContext context,
    WidgetRef ref,
    String familiaId,
    String tipo,
    String label,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Pular $label?', style: const TextStyle(color: AppColors.tx)),
        content: Text(
          'Isso registra que você não comeu neste horário. Tudo bem!',
          style: const TextStyle(color: AppColors.mu, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.pur),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pular'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;
    try {
      await SaudeApiService.registrarRefeicao({
        'membro_id': widget.membroId,
        'familia_id': familiaId,
        'tipo_refeicao': tipo,
        'is_jejum': true,
        'motivo_jejum': 'nao_tive_fome',
        'modalidade_entrada': 'manual',
        'data_refeicao': _hoje,
      });
      ref.invalidate(refeicoesDiaProvider);
      ref.invalidate(extratoDiarioProvider);
    } catch (_) {}
  }
}
