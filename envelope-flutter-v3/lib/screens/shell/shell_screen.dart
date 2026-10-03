import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/compras_provider.dart';
import '../../core/services/app_navigator.dart';
import '../../ui/theme/nb_theme.dart';
import '../compras/compras_screen.dart';
import '../extrato/extrato_screen.dart';
import '../home/home_screen.dart';
import '../minha_vida/minha_vida_screen.dart';
import '../planos/planos_screen.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _aba = navHome;

  @override
  void initState() {
    super.initState();
    registerNavCallback((i) {
      if (mounted) setState(() => _aba = i);
    });
  }

  @override
  void dispose() {
    unregisterNavCallback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendentes = ref.watch(comprasPendentesProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      body: IndexedStack(
        index: _aba,
        children: const [
          HomeScreen(),
          ExtratoScreen(),
          PlanosScreen(),
          ComprasScreen(),
          MinhaVidaScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: NBColors.linha))),
        child: NavigationBar(
          selectedIndex: _aba,
          onDestinationSelected: (i) => setState(() => _aba = i),
          destinations: [
            const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Início'),
            const NavigationDestination(icon: Icon(Icons.format_list_bulleted_rounded), label: 'Extrato'),
            const NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Planos'),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: pendentes > 0,
                backgroundColor: NBColors.estouro,
                label: Text('$pendentes'),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
              selectedIcon: const Icon(Icons.shopping_bag_rounded),
              label: 'Compras',
            ),
            const NavigationDestination(icon: Icon(Icons.favorite_border_rounded), selectedIcon: Icon(Icons.favorite_rounded), label: 'Minha Vida'),
          ],
        ),
      ),
    );
  }
}
