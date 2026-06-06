import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_screen.dart';
import 'extrato_screen.dart';
import 'compras_pendentes_screen.dart';
import 'planos/planos_screen.dart';
import 'form_gasto_sheet.dart';
import 'form_receita_screen.dart';
import 'form_envelope_sheet.dart';
import '../theme/app_theme.dart';
import '../widgets/speed_dial_fab.dart';
import '../providers/compras_provider.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const ComprasPendentesScreen(),
    const ExtratoScreen(),
    const PlanosScreen(),
  ];

  void _openSheet(Widget sheet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }

  void _goToComprasIA() {
    setState(() => _currentIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    final pendentesAsync = ref.watch(comprasPendentesProvider);
    final pendentesCount = pendentesAsync.value?.length ?? 0;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomAppBar(
        color: AppColors.surf,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _navItem(Icons.home_rounded, 'Início', 0),
              _navItemWithBadge(Icons.smart_toy_outlined, 'Compras IA', 1, pendentesCount),
              const Expanded(child: SizedBox()), // espaço para o FAB central
              _navItem(Icons.description_rounded, 'Extrato', 2),
              _navItem(Icons.savings_rounded, 'Planos', 3),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SpeedDialFab(
        onGastei: () => _openSheet(const FormGastoSheet()),
        onRecebi: () => _openSheet(const FormReceitaScreen()),
        onNovoEnvelope: () => _openSheet(const FormEnvelopeSheet()),
        onComprasIA: _goToComprasIA,
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

  Widget _navItemWithBadge(IconData icon, String label, int index, int badgeCount) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: isSelected ? AppColors.acc : AppColors.mu, size: 20),
                if (badgeCount > 0)
                  Positioned(
                    top: -5,
                    right: -8,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD4A017),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
