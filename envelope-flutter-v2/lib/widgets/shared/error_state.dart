import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Widget padrão de error state com mensagem amigável e botão de retry.
class ErrorState extends StatelessWidget {
  final String mensagem;
  final VoidCallback? onRetry;
  final bool sliver;

  const ErrorState({
    super.key,
    this.mensagem = 'Algo deu errado. Tente novamente.',
    this.onRetry,
    this.sliver = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.red.withOpacity(0.7)),
            const SizedBox(height: 16),
            Text(
              mensagem,
              style: AppTextStyles.body.copyWith(color: AppColors.mu),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('TENTAR NOVAMENTE'),
                style: TextButton.styleFrom(foregroundColor: AppColors.acc),
              ),
            ],
          ],
        ),
      ),
    );

    if (sliver) return SliverToBoxAdapter(child: content);
    return content;
  }
}
