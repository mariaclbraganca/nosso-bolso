import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../providers/astrix_provider.dart';
import '../../widgets/mascote/astrix_painter.dart' show AstrixMood;
import '../../widgets/mascote/unicorn_screen_guard.dart';
import 'contas_screen.dart';
import 'metas_screen.dart';

class PlanosScreen extends StatefulWidget {
  const PlanosScreen({super.key});

  @override
  State<PlanosScreen> createState() => _PlanosScreenState();
}

class _PlanosScreenState extends State<PlanosScreen> with SingleTickerProviderStateMixin {
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
    return Column(
      children: [
        UnicornScreenGuard(
          screenId: 'planos',
          onFirstMount: (r) => r.astrix(
            'Metas e contas planejadas. O futuro começa com um bom plano!',
            mood: AstrixMood.thinking,
          ),
        ),
        Container(
          color: AppColors.surf,
          child: TabBar(
            controller: _tab,
            indicatorColor: AppColors.acc,
            labelColor: AppColors.acc,
            unselectedLabelColor: AppColors.mu,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: '🧾  Contas'),
              Tab(text: '🎯  Metas'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              ContasScreen(),
              MetasScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
