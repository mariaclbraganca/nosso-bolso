import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/usuarios_provider.dart';
import '../../providers/saude_provider.dart';
import '../hub_screen.dart';
import 'dashboard_diario_screen.dart';
import 'historico_screen.dart';
import 'sugestao_jantar_screen.dart';
import 'perfil_metabolico_screen.dart';
import 'registrar_refeicao_sheet.dart';

class SaudeNavigationScreen extends ConsumerStatefulWidget {
  const SaudeNavigationScreen({super.key});

  @override
  ConsumerState<SaudeNavigationScreen> createState() => _SaudeNavigationScreenState();
}

class _SaudeNavigationScreenState extends ConsumerState<SaudeNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
    final membros = ref.watch(listaUsuariosProvider).asData?.value ?? [];
    final membroSelecionadoId = ref.watch(membroSaudeProvider) ?? perfil?['id'] ?? '';

    final membroNome = membros
        .where((m) => m['id'] == membroSelecionadoId)
        .map((m) => m['nome'] as String? ?? '')
        .firstOrNull ?? 'Eu';

    final screens = [
      DashboardDiarioScreen(membroId: membroSelecionadoId),
      HistoricoScreen(membroId: membroSelecionadoId),
      SugestaoJantarScreen(membroId: membroSelecionadoId),
      PerfilMetabolicoScreen(membroId: membroSelecionadoId),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: GestureDetector(
          onTap: membros.length > 1 ? () => _selecionarMembro(context, membros) : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_rounded, size: 16, color: AppColors.acc),
              const SizedBox(width: 6),
              Text(
                membroNome,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.tx),
              ),
              if (membros.length > 1)
                const Icon(Icons.expand_more_rounded, size: 16, color: AppColors.mu),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_view_rounded, color: AppColors.mu, size: 20),
            tooltip: 'Módulos',
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HubScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: AppColors.surf,
          border: Border(top: BorderSide(color: AppColors.bord, width: 0.5)),
        ),
        child: Row(
          children: [
            _navItem(Icons.today_rounded, 'Hoje', 0),
            _navItem(Icons.show_chart_rounded, 'Histórico', 1),
            _navItem(Icons.dinner_dining_rounded, 'Jantar', 2),
            _navItem(Icons.person_rounded, 'Perfil', 3),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              backgroundColor: AppColors.acc,
              foregroundColor: AppColors.bg,
              onPressed: () => _abrirRegistro(context, membroSelecionadoId, perfil?['familia_id'] ?? ''),
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppColors.grn : AppColors.mu, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? AppColors.grn : AppColors.mu,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirRegistro(BuildContext context, String membroId, String familiaId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RegistrarRefeicaoSheet(membroId: membroId, familiaId: familiaId),
    ).then((_) {
      ref.invalidate(extratoDiarioProvider);
      ref.invalidate(refeicoesDiaProvider);
      ref.invalidate(hidratacaoDiaProvider);
    });
  }

  void _selecionarMembro(BuildContext context, List<Map<String, dynamic>> membros) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Selecionar membro',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.tx),
            ),
          ),
          ...membros.map((m) => ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.grn.withOpacity(0.2),
              child: Text(
                (m['nome'] as String? ?? '?')[0].toUpperCase(),
                style: const TextStyle(color: AppColors.grn, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(m['nome'] as String? ?? '', style: const TextStyle(color: AppColors.tx)),
            onTap: () {
              ref.read(membroSaudeProvider.notifier).state = m['id'] as String?;
              Navigator.pop(context);
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
