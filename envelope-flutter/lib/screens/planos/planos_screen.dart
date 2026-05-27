import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
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
