import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:envelope_flutter/providers/auth_provider.dart';
import 'package:envelope_flutter/providers/usuarios_provider.dart';
import 'package:envelope_flutter/providers/mes_provider.dart';
import 'package:envelope_flutter/theme/app_theme.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final mes = ref.watch(mesAtualProvider);
    final perfil = ref.watch(perfilUsuarioLogadoProvider).value;
    
    final userName = perfil?['nome'] ?? user?.email?.split('@').first ?? 'Usuário';
    final familiaNome = perfil?['familias']?['nome'] ?? 'Minha Família';
    final familiaCodigo = perfil?['familias']?['codigo_acesso'] ?? '---';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 50, 18, 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Navegação de mês
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => ref.read(mesAtualProvider.notifier).state = mesAnterior(mes),
                        child: const Icon(Icons.chevron_left, size: 18, color: AppColors.mu),
                      ),
                      Text('${mesLabel(mes)} · GESTÃO FAMILIAR', style: const TextStyle(fontSize: 11, color: AppColors.mu, letterSpacing: 0.5)),
                      GestureDetector(
                        onTap: () => ref.read(mesAtualProvider.notifier).state = mesProximo(mes),
                        child: const Icon(Icons.chevron_right, size: 18, color: AppColors.mu),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        familiaNome.toUpperCase(),
                        style: const TextStyle(color: AppColors.mu, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          if (familiaCodigo != '---') {
                            Clipboard.setData(ClipboardData(text: familiaCodigo));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Código $familiaCodigo copiado!'),
                                backgroundColor: AppColors.acc,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.acc.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.acc.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(familiaCodigo, style: const TextStyle(color: AppColors.acc, fontSize: 9, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              const Icon(Icons.copy_rounded, size: 10, color: AppColors.acc),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('Olá, ${userName.toUpperCase()} 👋', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                onPressed: () => ref.read(authServiceProvider).signOut(),
                icon: const Icon(Icons.logout_rounded, color: AppColors.mu, size: 20),
                tooltip: 'Sair',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
