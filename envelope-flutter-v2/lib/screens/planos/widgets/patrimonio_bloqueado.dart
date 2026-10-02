import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/pin_provider.dart';
import '../../config/pin_screen.dart';

/// Tela exibida quando a aba de Patrimônio está trancada por PIN
class PatrimonioBloqueado extends ConsumerWidget {
  final bool pinConfigurado;
  const PatrimonioBloqueado({super.key, required this.pinConfigurado});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.acc.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_rounded, color: AppColors.acc, size: 32),
            ),
            const SizedBox(height: 20),
            Text('Patrimônio', style: AppTextStyles.title),
            const SizedBox(height: 8),
            Text(
              'Suas contas bancárias e investimentos.\nDigite seu PIN para acessar.',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.lock_rounded, size: 18),
                label: Text(
                  pinConfigurado ? 'Digitar PIN' : 'Configurar PIN',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.bg),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PinScreen(
                      mode: pinConfigurado ? PinMode.verify : PinMode.setup,
                      onSuccess: () {
                        Navigator.pop(context);
                        ref.invalidate(pinConfiguradoProvider);
                      },
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.acc,
                  foregroundColor: AppColors.bg,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
