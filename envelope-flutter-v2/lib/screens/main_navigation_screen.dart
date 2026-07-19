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

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _index = 0;
  int _ultimaQtdVista = 0;   // maior nº de pendentes já exibido no popup
  bool _popupAberto = false; // evita empilhar popups

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

  void _navegarPara(int i, BuildContext context) {
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final pendentes = ref.watch(comprasPendentesProvider).value?.length ?? 0;

    // Popup de pendentes: aparece na primeira carga com pendentes E sempre que
    // o número aumentar (nova compra capturada enquanto usa o app).
    ref.listen(comprasPendentesProvider, (_, next) {
      final qtd = next.value?.length ?? 0;
      if (qtd == 0) {
        _ultimaQtdVista = 0; // zerou tudo → rearma para futuras compras
        return;
      }
      if (qtd > _ultimaQtdVista && !_popupAberto && mounted) {
        _ultimaQtdVista = qtd;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _mostrarPopupPendentes(qtd));
      }
    });

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _BottomNav(
        index: _index,
        pendentes: pendentes,
        onTap: (i) => _navegarPara(i, context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _CentralFab(
        pendentes: pendentes,
        onGoToComprasIA: _showComprasIA,
        onGastei: _showFormGasto,
        onRecebi: _showFormReceita,
      ),
    );
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🛒', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                plural
                    ? '$quantidade compras esperando envelope'
                    : '1 compra esperando envelope',
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                    ),
                  ),
                  child: const Text('Categorizar agora',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Depois',
                    style: AppTextStyles.caption.copyWith(color: AppColors.mu)),
              ),
            ],
          ),
        ),
      ),
    );
    _popupAberto = false;
  }

  void _showComprasIA() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ComprasIASheet(),
    ).then((_) => ref.invalidate(comprasPendentesProvider));
  }

  void _showFormGasto() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FormGastoSheet(),
    );
  }

  void _showFormReceita() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FormReceitaSheet(),
    );
  }
}

// ─── Bottom Nav ───────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int index;
  final int pendentes;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.index, required this.pendentes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surf,
        border: Border(top: BorderSide(color: AppColors.bord, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Home', selected: index == 0, onTap: () => onTap(0)),
              _NavItem(icon: Icons.receipt_long_rounded, label: 'Extrato', selected: index == 1, onTap: () => onTap(1)),
              const Expanded(child: SizedBox()), // espaço FAB
              _NavItem(icon: Icons.savings_rounded, label: 'Planos', selected: index == 2, onTap: () => onTap(2)),
              _NavItem(icon: Icons.favorite_rounded, label: 'Minha Vida', selected: index == 3, onTap: () => onTap(3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.acc : AppColors.mu;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.translucent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.acc.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FAB Central ─────────────────────────────────────────────────────────────

class _CentralFab extends StatefulWidget {
  final int pendentes;
  final VoidCallback onGoToComprasIA;
  final VoidCallback onGastei;
  final VoidCallback onRecebi;

  const _CentralFab({
    required this.pendentes,
    required this.onGoToComprasIA,
    required this.onGastei,
    required this.onRecebi,
  });

  @override
  State<_CentralFab> createState() => _CentralFabState();
}

class _CentralFabState extends State<_CentralFab> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rotation;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _rotation = Tween(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  void _close() {
    if (!_open) return;
    setState(() => _open = false);
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 300,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (_open)
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),

          // Opção 3 — Compras IA
          _FabOption(
            heroTag: 'fab_compras_ia',
            offset: 200,
            open: _open,
            icon: Icons.qr_code_scanner_rounded,
            label: 'Compras IA',
            color: AppColors.gold,
            badge: widget.pendentes > 0 ? widget.pendentes : null,
            onTap: () { _close(); widget.onGoToComprasIA(); },
          ),

          // Opção 2 — Recebi
          _FabOption(
            heroTag: 'fab_recebi',
            offset: 140,
            open: _open,
            icon: Icons.add_circle_outline_rounded,
            label: 'Recebi',
            color: AppColors.grn,
            onTap: () { _close(); widget.onRecebi(); },
          ),

          // Opção 1 — Gastei
          _FabOption(
            heroTag: 'fab_gastei',
            offset: 80,
            open: _open,
            icon: Icons.remove_circle_outline_rounded,
            label: 'Gastei',
            color: AppColors.red,
            onTap: () { _close(); widget.onGastei(); },
          ),

          // Botão principal
          Stack(
            clipBehavior: Clip.none,
            children: [
              RotationTransition(
                turns: _rotation,
                child: FloatingActionButton(
                  key: const Key('fab_main'),
                  heroTag: 'fab_main',
                  onPressed: _toggle,
                  elevation: 12,
                  backgroundColor: AppColors.acc,
                  shape: const CircleBorder(),
                  child: Icon(
                    _open ? Icons.close_rounded : Icons.add_rounded,
                    color: AppColors.bg,
                    size: 28,
                  ),
                ),
              ),
              if (!_open && widget.pendentes > 0)
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    width: 18, height: 18,
                    decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('${widget.pendentes}',
                      style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FabOption extends StatelessWidget {
  final String heroTag;
  final double offset;
  final bool open;
  final IconData icon;
  final String label;
  final Color color;
  final int? badge;
  final VoidCallback onTap;

  const _FabOption({
    required this.heroTag,
    required this.offset,
    required this.open,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      bottom: open ? offset : 8,
      child: IgnorePointer(
        ignoring: !open,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: open ? 1.0 : 0.0,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Text(label,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    FloatingActionButton.small(
                      heroTag: heroTag,
                      onPressed: onTap,
                      backgroundColor: color,
                      shape: const CircleBorder(),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    if (badge != null)
                      Positioned(
                        top: -4, right: -4,
                        child: Container(
                          width: 16, height: 16,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text('$badge',
                            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

