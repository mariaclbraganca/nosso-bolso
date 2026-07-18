import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/pin_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../theme/app_theme.dart';
import '../../screens/config/pin_screen.dart';

/// Envolve conteúdo que só admins podem ver.
/// - Se o usuário não for admin: mostra mensagem de acesso negado
/// - Se for admin mas PIN não desbloqueado: mostra botão para digitar PIN
/// - Se for admin e sessão ativa: mostra o conteúdo normalmente
class PinGate extends ConsumerWidget {
  final Widget child;
  final String? mensagemBloqueio;

  const PinGate({
    super.key,
    required this.child,
    this.mensagemBloqueio,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
    final isAdmin = perfil?['role'] == 'admin';
    final desbloqueado = ref.watch(pinDesbloqueadoProvider);
    final pinConfigurado = ref.watch(pinConfiguradoProvider);

    // Não admin: acesso negado permanente
    if (!isAdmin) {
      return _AcessoNegado(mensagem: mensagemBloqueio ?? 'Esta área é restrita aos administradores da família.');
    }

    // Admin + sessão ativa: mostra conteúdo
    if (desbloqueado) return child;

    // Admin + PIN não configurado ainda: direciona para setup
    if (pinConfigurado.asData?.value == false) {
      return _SetupPinPrompt();
    }

    // Admin + PIN configurado mas sessão expirada: pede PIN
    return _PinPrompt();
  }
}

class _AcessoNegado extends StatelessWidget {
  final String mensagem;
  const _AcessoNegado({required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded, color: AppColors.red, size: 28),
            ),
            const SizedBox(height: 16),
            Text('Acesso restrito', style: AppTextStyles.titleSm),
            const SizedBox(height: 8),
            Text(
              mensagem,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupPinPrompt extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.acc.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.security_rounded, color: AppColors.acc, size: 28),
            ),
            const SizedBox(height: 16),
            Text('Configure seu PIN admin', style: AppTextStyles.titleSm),
            const SizedBox(height: 8),
            Text(
              'Defina um PIN de 6 dígitos para proteger as informações financeiras deste dispositivo.',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PinScreen(
                      mode: PinMode.setup,
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
                child: Text('Configurar PIN', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.bg)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinPrompt extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.acc.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, color: AppColors.acc, size: 28),
            ),
            const SizedBox(height: 16),
            Text('Área protegida', style: AppTextStyles.titleSm),
            const SizedBox(height: 8),
            Text(
              'Digite seu PIN para acessar as informações financeiras.',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PinScreen(
                      mode: PinMode.verify,
                      onSuccess: () => Navigator.pop(context),
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.acc,
                  foregroundColor: AppColors.bg,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                ),
                child: Text('Digitar PIN', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.bg)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
