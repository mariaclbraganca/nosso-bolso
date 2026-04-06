import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/usuarios_provider.dart';
import '../theme/app_theme.dart';

class SeletorUsuario extends ConsumerWidget {
  const SeletorUsuario({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedUser = ref.watch(usuarioFiltroProvider);
    final usersAsync = ref.watch(listaUsuariosProvider);

    return usersAsync.when(
      data: (users) {
        final names = ['Todos', ...users.map((u) => u['nome'] as String)];
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(30)),
          child: Row(
            children: names.map((u) {
              final isSelected = selectedUser == u || (u == 'Todos' && selectedUser == null);
              return Expanded(
                child: GestureDetector(
                  onTap: () => ref.read(usuarioFiltroProvider.notifier).state = (u == 'Todos' ? null : u),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.acc : Colors.transparent, 
                      borderRadius: BorderRadius.circular(26)
                    ),
                    child: Text(
                      u, 
                      textAlign: TextAlign.center, 
                      style: TextStyle(
                        color: isSelected ? AppColors.bg : AppColors.mu, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 12
                      )
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
