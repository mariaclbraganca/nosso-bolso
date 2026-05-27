import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../hub_screen.dart';
import 'dashboard_exercicio_screen.dart';
import 'historico_exercicio_screen.dart';

class ExercicioNavigationScreen extends ConsumerStatefulWidget {
  const ExercicioNavigationScreen({super.key});

  @override
  ConsumerState<ExercicioNavigationScreen> createState() => _ExercicioNavigationScreenState();
}

class _ExercicioNavigationScreenState extends ConsumerState<ExercicioNavigationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surf,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.mu, size: 18),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HubScreen()),
          ),
        ),
        title: const Row(
          children: [
            Text('🏋️', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'Exercício Físico',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.tx),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.org,
          labelColor: AppColors.org,
          unselectedLabelColor: AppColors.mu,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Hoje'),
            Tab(text: 'Histórico'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          DashboardExercicioScreen(),
          HistoricoExercicioScreen(),
        ],
      ),
    );
  }
}
