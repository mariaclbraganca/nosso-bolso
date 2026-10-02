import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/compras_provider.dart';
import '../services/app_navigator.dart';
import 'home/home_screen.dart';
import 'sheets/form_gasto_sheet.dart';
import 'sheets/form_receita_sheet.dart';
import 'extrato/extrato_screen.dart';
import 'planos/planos_screen.dart';
import 'minha_vida/minha_vida_screen.dart';
import 'compras/compras_ia_sheet.dart';
import 'navigation/bottom_nav_bar.dart';
import 'navigation/central_fab.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _index = 0;
  int _qtdAnterior = 0;
  bool _popupAberto = false;
  bool _fabOpen = false;

  static const _screens = [
    HomeScreen(),
    ExtratoScreen(),
    PlanosScreen(),
    MinhaVidaScreen(),
  ];

  @override
  void initState() {
    super.initState();
    registerNavCallback((index) {
      if (mounted) setState(() => _index = index);
    });
  }

  @override
  void dispose() {
    unregisterNavCallback();
    super.dispose();
  }

  void _navegarPara(int i) {
    if (_fabOpen) setState(() => _fabOpen = false);
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  void _closeFab() {
    if (_fabOpen) setState(() => _fabOpen = false);
  }

  Future<void> _mostrarPopupPendentes(int quantidade) async {
    if (!mounted || _popupAberto) return;
    _popupAberto = true;
    final plural = quantidade > 1;

    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🛒', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                plural ? '$quantidade compras esperando envelope' : '1 compra esperando envelope',
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                plural
                    ? 'O app capturou compras que ainda não foram lançadas nos envelopes. Quer organizar agora?'
                    : 'O app capturou uma compra que ainda não foi lançada num envelope. Quer lançar agora?',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showComprasIA();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.acc,
                    foregroundColor: AppColors.bg,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                  ),
                  child: const Text('Categorizar agora', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Depois',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.tx.withOpacity(0.7), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    _popupAberto = false;
  }

  void _showComprasIA() {
    _closeFab();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ComprasIASheet(),
    ).then((_) => ref.invalidate(comprasPendentesProvider));
  }

  void _showFormGasto() {
    _closeFab();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FormGastoSheet(),
    );
  }

  void _showFormReceita() {
    _closeFab();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FormReceitaSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendentes = ref.watch(comprasPendentesProvider).value?.length ?? 0;

    ref.listen(comprasPendentesProvider, (prev, next) {
      final qtd = next.value?.length ?? 0;
      final antes = prev?.value?.length ?? _qtdAnterior;
      _qtdAnterior = qtd;
      if (qtd > antes && !_popupAberto && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarPopupPendentes(qtd));
      }
    });

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _screens),
          if (_fabOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeFab,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        index: _index,
        pendentes: pendentes,
        onTap: _navegarPara,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: CentralFab(
        pendentes: pendentes,
        isOpen: _fabOpen,
        onToggle: () => setState(() => _fabOpen = !_fabOpen),
        onGoToComprasIA: _showComprasIA,
        onGastei: _showFormGasto,
        onRecebi: _showFormReceita,
      ),
    );
  }
}
