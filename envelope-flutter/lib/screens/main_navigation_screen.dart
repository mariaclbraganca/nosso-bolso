import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'extrato_screen.dart';
import 'relatorios_screen.dart';
import 'fixos_screen.dart';
import 'compras_pendentes_screen.dart';
import 'form_gasto_sheet.dart';
import 'form_receita_screen.dart';
import 'form_envelope_sheet.dart';
import '../theme/app_theme.dart';
import '../widgets/speed_dial_fab.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const RelatoriosScreen(),
    const ExtratoScreen(),
    const FixosScreen(),
    const ComprasPendentesScreen(),
  ];

  void _openSheet(Widget sheet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: AppColors.surf,
          border: Border(top: BorderSide(color: AppColors.bord, width: 0.5)),
        ),
        child: Row(
          children: [
            _navItem(Icons.home_rounded, 'Início', 0),
            _navItem(Icons.bar_chart_rounded, 'Relatórios', 1),
            _navItem(Icons.description_rounded, 'Extrato', 2),
            _navItem(Icons.calendar_today_rounded, 'Fixos', 3),
            _navItem(Icons.shopping_cart_rounded, 'Compras', 4),
          ],
        ),
      ),
      floatingActionButton: SpeedDialFab(
        onGastei: () => _openSheet(const FormGastoSheet()),
        onRecebi: () => _openSheet(const FormReceitaScreen()),
        onNovoEnvelope: () => _openSheet(const FormEnvelopeSheet()),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppColors.acc : AppColors.mu, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? AppColors.acc : AppColors.mu,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
