import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../providers/unicorn_team.dart';

Color _accentColor(UnicornType type) => switch (type) {
      UnicornType.astrix   => const Color(0xFFAB47FF),
      UnicornType.sweet    => const Color(0xFFFF8FAB),
      UnicornType.happy    => const Color(0xFFFFCA28),
      UnicornType.geronimo => const Color(0xFFFF6D00),
    };

/// Speech bubble styled per unicorn — unique accent border + glow.
class UnicornBubble extends StatelessWidget {
  final String text;
  final UnicornType type;
  final VoidCallback? onDismiss;

  const UnicornBubble({
    super.key,
    required this.text,
    required this.type,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(type);
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.only(
          topLeft:     Radius.circular(16),
          topRight:    Radius.circular(16),
          bottomLeft:  Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
        border: Border.all(color: accent.withOpacity(0.6), width: 1.0),
        boxShadow: [
          BoxShadow(
            color:      accent.withOpacity(0.22),
            blurRadius: 18,
            offset:     const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.tx, fontSize: 13, height: 1.45),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 7),
            GestureDetector(
              onTap: onDismiss,
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Icons.close_rounded, size: 14, color: accent.withOpacity(0.7)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
