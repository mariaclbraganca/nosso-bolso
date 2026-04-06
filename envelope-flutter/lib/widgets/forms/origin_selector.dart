import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class OriginSelector extends StatelessWidget {
  final String selected;
  final Function(String, String) onSelected;

  const OriginSelector({super.key, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> origs = [
      {'e': '💼', 'l': 'Salário'},
      {'e': '🥗', 'l': 'Vale Alim.'},
      {'e': '🎯', 'l': 'Freelance'},
      {'e': '🏠', 'l': 'Aluguel'},
      {'e': '💫', 'l': 'Aporte'},
      {'e': '📦', 'l': 'Outros'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: origs.map((o) {
        final isSel = selected == o['l'];
        return GestureDetector(
          onTap: () => onSelected(o['l']!, o['e']!),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSel ? AppColors.grn.withOpacity(0.12) : AppColors.surf,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSel ? AppColors.grn : AppColors.bord, 
                width: 1.5
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(o['e']!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  o['l']!, 
                  style: TextStyle(
                    fontSize: 13, 
                    color: isSel ? AppColors.grn : AppColors.tx,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  )
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
