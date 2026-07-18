import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/saude_provider.dart';
import '../../../providers/transacoes_provider.dart';
import '../../../providers/fixos_provider.dart';
import '../../../providers/mes_provider.dart';
import 'dashboard_diario_view.dart';
import 'historico_saude_view.dart';
import 'perfil_metabolico_view.dart';
import 'registrar_refeicao_sheet.dart';
import '../jejum/jejum_view.dart';

class SaudeView extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;

  const SaudeView({
    super.key,
    required this.membroId,
    required this.familiaId,
  });

  @override
  ConsumerState<SaudeView> createState() => _SaudeViewState();
}

class _SaudeViewState extends ConsumerState<SaudeView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // ── Tab bar ──────────────────────────────────────────────
            _buildTabBar(),
            // ── Card financeiro-saúde ─────────────────────────────────
            // REGRA: NUNCA na aba Jejum — dados financeiros ficam fora
            // do contexto de jejum (psicologia/autoestima).
            if (_tabCtrl.index != 3) _buildInvestimentoSaudeCard(),
            // ── Conteúdo ─────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  DashboardDiarioView(
                    membroId: widget.membroId,
                    familiaId: widget.familiaId,
                  ),
                  HistoricoSaudeView(membroId: widget.membroId),
                  PerfilMetabolicoView(
                    membroId: widget.membroId,
                    familiaId: widget.familiaId,
                  ),
                  JejumView(
                    membroId: widget.membroId,
                    familiaId: widget.familiaId,
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── FAB (visível só na aba "Hoje") ────────────────────────────
        if (_tabCtrl.index == 0)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'saude_fab',
              backgroundColor: AppColors.grn,
              foregroundColor: Colors.white,
              onPressed: () => _abrirRegistro(context),
              child: const Icon(Icons.add_rounded),
            ),
          ),
      ],
    );
  }

  // ── Card: Investimento na sua saúde ────────────────────────────────────────

  Widget _buildInvestimentoSaudeCard() {
    final transacoes = ref.watch(transacoesComDetalhesProvider);
    final fixos      = ref.watch(fixosMesAtualProvider);
    final mes        = ref.watch(mesAtualProvider);
    final stats      = ref.watch(statsPorMesProvider(mes));

    bool contemKey(String texto, List<String> keys) {
      final lower = texto.toLowerCase();
      return keys.any((k) => lower.contains(k));
    }

    // Categorias e suas palavras-chave
    const alimentacaoKeys = ['alimenta', 'mercado', 'ifood', 'supermercado'];
    const saudeKeys       = ['saude', 'saúde', 'plano', 'médico', 'medico', 'farmácia', 'farmacia'];
    const academiaKeys    = ['academia', 'gym', 'exercício', 'exercicio'];

    double totalAlim    = 0;
    double totalSaude   = 0;
    double totalAcad    = 0;

    // Somar despesas de transações por nome do envelope
    for (final t in transacoes) {
      if (t['tipo'] != 'despesa') continue;
      final nomeEnv = (t['envelopes']?['nome_envelope'] ?? '') as String;
      final valor   = (t['valor'] as num?)?.toDouble() ?? 0.0;
      if (contemKey(nomeEnv, alimentacaoKeys)) totalAlim  += valor;
      if (contemKey(nomeEnv, saudeKeys))       totalSaude += valor;
      if (contemKey(nomeEnv, academiaKeys))    totalAcad  += valor;
    }

    // Somar gastos fixos por nome do fixo
    for (final f in fixos) {
      final nome  = (f['nome'] ?? '') as String;
      final valor = (f['valor'] as num?)?.toDouble() ?? 0.0;
      if (contemKey(nome, alimentacaoKeys)) totalAlim  += valor;
      if (contemKey(nome, saudeKeys))       totalSaude += valor;
      if (contemKey(nome, academiaKeys))    totalAcad  += valor;
    }

    final totalGeral = totalAlim + totalSaude + totalAcad;
    if (totalGeral == 0) return const SizedBox.shrink();

    final receita   = stats.totalReceita;
    final pct       = receita > 0 ? (totalGeral / receita * 100).round() : 0;

    String fmt(double v) =>
        'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',').replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.',
        )}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePad, 0, AppSpacing.pagePad, AppSpacing.cardGap,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Row(
              children: [
                const Text('💰', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Text(
                  'Investimento na sua saúde este mês',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(color: AppColors.bord, height: 1),
            const SizedBox(height: 10),
            // Linhas de categoria (oculta se zero)
            if (totalAlim > 0)  _buildLinha('🥗', 'Alimentação',  fmt(totalAlim)),
            if (totalSaude > 0) _buildLinha('🏥', 'Saúde / Plano', fmt(totalSaude)),
            if (totalAcad > 0)  _buildLinha('🏋️', 'Academia',      fmt(totalAcad)),
            const SizedBox(height: 8),
            Divider(color: AppColors.bord, height: 1),
            const SizedBox(height: 8),
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: AppTextStyles.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.tx,
                  ),
                ),
                Text(
                  fmt(totalGeral),
                  style: AppTextStyles.monoSm.copyWith(color: AppColors.acc),
                ),
              ],
            ),
            if (pct > 0) ...[
              const SizedBox(height: 4),
              Text(
                'representa $pct% da renda do mês',
                style: AppTextStyles.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLinha(String emoji, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.bodySm.copyWith(color: AppColors.mu)),
            ],
          ),
          Text(valor, style: AppTextStyles.monoSm),
        ],
      ),
    );
  }

  // ── Tab bar ─────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.pagePad, 0, AppSpacing.pagePad, AppSpacing.cardGap,
      ),
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          color: AppColors.grn.withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.grn.withOpacity(0.4)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(3),
        dividerColor: Colors.transparent,
        labelColor: AppColors.grn,
        unselectedLabelColor: AppColors.mu,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabs: const [
          Tab(text: 'Hoje'),
          Tab(text: 'Progresso'),
          Tab(text: 'Meu Plano'),
          Tab(text: '⏱ Jejum'),
        ],
      ),
    );
  }

  void _abrirRegistro(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RegistrarRefeicaoSheet(
        membroId: widget.membroId,
        familiaId: widget.familiaId,
      ),
    ).then((_) {
      ref.invalidate(extratoDiarioProvider);
      ref.invalidate(refeicoesDiaProvider);
      ref.invalidate(hidratacaoDiaProvider);
    });
  }
}
