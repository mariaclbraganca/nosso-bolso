import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AstrixBubble extends StatelessWidget {
  final String text;
  final VoidCallback? onDismiss;

  const AstrixBubble({super.key, required this.text, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
        border: Border.all(color: AppColors.bord, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 14,
            offset: const Offset(0, 5),
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
              child: const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.close_rounded, size: 14, color: AppColors.mu),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
