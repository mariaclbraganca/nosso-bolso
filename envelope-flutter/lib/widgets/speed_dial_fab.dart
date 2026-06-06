import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/compras_provider.dart';

class SpeedDialFab extends ConsumerStatefulWidget {
  final VoidCallback onGastei;
  final VoidCallback onRecebi;
  final VoidCallback onNovoEnvelope;
  final VoidCallback onComprasIA;

  const SpeedDialFab({
    super.key,
    required this.onGastei,
    required this.onRecebi,
    required this.onNovoEnvelope,
    required this.onComprasIA,
  });

  @override
  ConsumerState<SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends ConsumerState<SpeedDialFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rotation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _rotation = Tween<double>(begin: 0, end: 0.125).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    _isOpen ? _ctrl.forward() : _ctrl.reverse();
  }

  void _close() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
    _ctrl.reverse();
  }

  void _onOption(VoidCallback action) {
    _close();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final pendentesAsync = ref.watch(comprasPendentesProvider);
    final pendentesCount = pendentesAsync.value?.length ?? 0;

    return SizedBox(
      width: 220,
      height: 380,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (_isOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),

          // Option 4 — Compras IA (topo)
          _buildOption(
            offset: 250,
            label: '🤖 Compras IA',
            color: const Color(0xFFD4A017),
            icon: Icons.qr_code_scanner,
            onTap: () => _onOption(widget.onComprasIA),
            badge: pendentesCount > 0 ? pendentesCount : null,
          ),

          // Option 3 — Novo Envelope
          _buildOption(
            offset: 190,
            label: '📦 Novo Envelope',
            color: AppColors.mu,
            icon: Icons.inventory_2_outlined,
            onTap: () => _onOption(widget.onNovoEnvelope),
          ),

          // Option 2 — Recebi
          _buildOption(
            offset: 130,
            label: '💰 Recebi',
            color: AppColors.grn,
            icon: Icons.add_circle_outline,
            onTap: () => _onOption(widget.onRecebi),
          ),

          // Option 1 — Gastei
          _buildOption(
            offset: 70,
            label: '💸 Gastei',
            color: AppColors.red,
            icon: Icons.remove_circle_outline,
            onTap: () => _onOption(widget.onGastei),
          ),

          // Main FAB com badge quando fechado
          Stack(
            clipBehavior: Clip.none,
            children: [
              RotationTransition(
                turns: _rotation,
                child: FloatingActionButton(
                  onPressed: _toggle,
                  elevation: 10,
                  backgroundColor: AppColors.acc,
                  shape: const CircleBorder(),
                  child: Icon(
                    _isOpen ? Icons.close : Icons.add,
                    color: AppColors.bg,
                    size: 28,
                  ),
                ),
              ),
              if (!_isOpen && pendentesCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4A017),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$pendentesCount',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required double offset,
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
    int? badge,
  }) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      bottom: _isOpen ? offset : 8,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _isOpen ? 1.0 : 0.0,
        child: GestureDetector(
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  FloatingActionButton.small(
                    heroTag: label,
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
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$badge',
                          style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
