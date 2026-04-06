import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SpeedDialFab extends StatefulWidget {
  final VoidCallback onGastei;
  final VoidCallback onRecebi;
  final VoidCallback onNovoEnvelope;

  const SpeedDialFab({
    super.key,
    required this.onGastei,
    required this.onRecebi,
    required this.onNovoEnvelope,
  });

  @override
  State<SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends State<SpeedDialFab>
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
    return SizedBox(
      width: 200,
      height: 320,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Overlay tap-to-close
          if (_isOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),

          // Option 3 — Novo Envelope (top)
          _buildOption(
            offset: 190,
            label: '📦 Novo Envelope',
            color: AppColors.mu,
            icon: Icons.inventory_2_outlined,
            onTap: () => _onOption(widget.onNovoEnvelope),
          ),

          // Option 2 — Recebi (middle)
          _buildOption(
            offset: 130,
            label: '💰 Recebi',
            color: AppColors.grn,
            icon: Icons.add_circle_outline,
            onTap: () => _onOption(widget.onRecebi),
          ),

          // Option 1 — Gastei (closest)
          _buildOption(
            offset: 70,
            label: '💸 Gastei',
            color: AppColors.red,
            icon: Icons.remove_circle_outline,
            onTap: () => _onOption(widget.onGastei),
          ),

          // Main FAB
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
              FloatingActionButton.small(
                heroTag: label,
                onPressed: onTap,
                backgroundColor: color,
                shape: const CircleBorder(),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
