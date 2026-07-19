import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/saude_provider.dart';
import 'dashboard_diario_view.dart';
import 'historico_saude_view.dart';
import 'perfil_metabolico_view.dart';
import 'registrar_refeicao_sheet.dart';

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
    _tabCtrl = TabController(length: 3, vsync: this);
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
