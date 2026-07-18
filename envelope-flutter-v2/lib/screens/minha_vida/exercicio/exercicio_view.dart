import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/exercicio_provider.dart';
import 'dashboard_exercicio_view.dart';
import 'historico_exercicio_view.dart';
import 'registrar_treino_sheet.dart';

class ExercicioView extends ConsumerStatefulWidget {
  final String membroId;

  const ExercicioView({super.key, required this.membroId});

  @override
  ConsumerState<ExercicioView> createState() => _ExercicioViewState();
}

class _ExercicioViewState extends ConsumerState<ExercicioView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
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
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  DashboardExercicioView(membroId: widget.membroId),
                  HistoricoExercicioView(membroId: widget.membroId),
                ],
              ),
            ),
          ],
        ),

        if (_tabCtrl.index == 0)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'exercicio_fab',
              backgroundColor: AppColors.org,
              foregroundColor: Colors.white,
              onPressed: () => _abrirRegistro(context),
              child: const Icon(Icons.fitness_center_rounded),
            ),
          ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.pagePad, 0, AppSpacing.pagePad, AppSpacing.cardGap),
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          color: AppColors.org.withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.org.withOpacity(0.4)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(3),
        dividerColor: Colors.transparent,
        labelColor: AppColors.org,
        unselectedLabelColor: AppColors.mu,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabs: const [
          Tab(text: 'Hoje'),
          Tab(text: 'Histórico'),
        ],
      ),
    );
  }

  void _abrirRegistro(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RegistrarTreinoSheet(membroId: widget.membroId),
    ).then((_) {
      ref.invalidate(exercicioDiaProvider);
      ref.invalidate(historicoExercicioProvider);
    });
  }
}
