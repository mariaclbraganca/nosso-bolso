import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

class CentralFab extends StatefulWidget {
  final int pendentes;
  final bool isOpen;
  final VoidCallback onToggle;
  final VoidCallback onGoToComprasIA;
  final VoidCallback onGastei;
  final VoidCallback onRecebi;

  const CentralFab({
    super.key,
    required this.pendentes,
    required this.isOpen,
    required this.onToggle,
    required this.onGoToComprasIA,
    required this.onGastei,
    required this.onRecebi,
  });

  @override
  State<CentralFab> createState() => _CentralFabState();
}

class _CentralFabState extends State<CentralFab> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _rotation = Tween(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.isOpen) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(CentralFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      widget.isOpen ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.isOpen;

    return SizedBox(
      width: 200,
      height: 300,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Opção 3 — Compras IA
          _FabOption(
            heroTag: 'fab_compras_ia',
            offset: 200,
            open: open,
            icon: Icons.qr_code_scanner_rounded,
            label: 'Compras IA',
            color: AppColors.gold,
            badge: widget.pendentes > 0 ? widget.pendentes : null,
            onTap: widget.onGoToComprasIA,
          ),

          // Opção 2 — Recebi
          _FabOption(
            heroTag: 'fab_recebi',
            offset: 140,
            open: open,
            icon: Icons.add_circle_outline_rounded,
            label: 'Recebi',
            color: AppColors.grn,
            onTap: widget.onRecebi,
          ),

          // Opção 1 — Gastei
          _FabOption(
            heroTag: 'fab_gastei',
            offset: 80,
            open: open,
            icon: Icons.remove_circle_outline_rounded,
            label: 'Gastei',
            color: AppColors.red,
            onTap: widget.onGastei,
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
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.onToggle();
                  },
                  elevation: 12,
                  backgroundColor: AppColors.acc,
                  shape: const CircleBorder(),
                  child: Icon(
                    open ? Icons.close_rounded : Icons.add_rounded,
                    color: AppColors.bg,
                    size: 28,
                  ),
                ),
              ),
              if (!open && widget.pendentes > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      '${widget.pendentes}',
                      style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
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
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
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
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text('$badge', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
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
