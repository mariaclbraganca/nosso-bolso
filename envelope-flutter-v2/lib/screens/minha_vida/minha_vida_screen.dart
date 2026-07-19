import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/saude_provider.dart';
import '../../providers/usuarios_provider.dart';
import 'saude/saude_view.dart';
import 'exercicio/exercicio_view.dart';
import 'jejum/jejum_view.dart';

class MinhaVidaScreen extends ConsumerStatefulWidget {
  const MinhaVidaScreen({super.key});

  @override
  ConsumerState<MinhaVidaScreen> createState() => _MinhaVidaScreenState();
}

class _MinhaVidaScreenState extends ConsumerState<MinhaVidaScreen> {
  int _segmento = 0; // 0 = Saúde, 1 = Exercício, 2 = Jejum

  @override
  Widget build(BuildContext context) {
    final perfil   = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
    final membros  = ref.watch(listaUsuariosProvider).asData?.value ?? [];
    final membroId = ref.watch(membroSaudeProvider) ?? perfil?['id'] as String? ?? '';

    final membroNome = membros
        .where((m) => m['id'] == membroId)
        .map((m) => m['nome'] as String? ?? '')
        .firstOrNull ?? 'Eu';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Cabeçalho ─────────────────────────────────────────────
            _buildHeader(context, membros, membroId, membroNome),

            // ── Switcher Saúde / Exercício ─────────────────────────────
            _buildSegmentSwitcher(),

            // ── Conteúdo ───────────────────────────────────────────────
            Expanded(
              child: IndexedStack(
                index: _segmento,
                children: [
                  SaudeView(membroId: membroId, familiaId: perfil?['familia_id'] as String? ?? ''),
                  ExercicioView(membroId: membroId),
                  JejumView(membroId: membroId, familiaId: perfil?['familia_id'] as String? ?? ''),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header com nome do membro ──────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    List<Map<String, dynamic>> membros,
    String membroId,
    String membroNome,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePad, 16, AppSpacing.pagePad, 8,
      ),
      child: Row(
        children: [
          // Título da tela
          Text('Minha Vida', style: AppTextStyles.title),
          const Spacer(),
          // Seletor de membro (só aparece se família tem >1 membro)
          if (membros.length > 1)
            GestureDetector(
              onTap: () => _selecionarMembro(context, membros),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surf,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                  border: Border.all(color: AppColors.bord),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 9,
                      backgroundColor: AppColors.grn.withOpacity(0.25),
                      child: Text(
                        membroNome.isNotEmpty ? membroNome[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.grn,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      membroNome,
                      style: AppTextStyles.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.tx,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more_rounded, size: 14, color: AppColors.mu),
                  ],
                ),
              ),
            )
          else if (membros.isNotEmpty)
            // Só mostra o nome sem dropdown
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_rounded, size: 14, color: AppColors.acc),
                const SizedBox(width: 4),
                Text(
                  membroNome,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Switcher animado ───────────────────────────────────────────────────────

  Widget _buildSegmentSwitcher() {
    // 3 segmentos grandes: Saúde (verde) · Exercício (laranja) · Jejum (roxo)
    const segmentos = [
      ('🌿 Saúde', AppColors.grn),
      ('💪 Exercício', AppColors.org),
      ('⏱ Jejum', AppColors.pur),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePad, 0, AppSpacing.pagePad, AppSpacing.cardGap,
      ),
      child: Row(
        children: List.generate(segmentos.length, (i) {
          final ativo = _segmento == i;
          final cor = segmentos[i].$2;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _segmento = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ativo ? cor.withOpacity(0.10) : AppColors.surf,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                    border: Border.all(
                      color: ativo ? cor : AppColors.bord,
                      width: ativo ? 1.5 : 0.5,
                    ),
                  ),
                  child: Text(
                    segmentos[i].$1,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ativo ? cor : AppColors.mu,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Seleção de membro (sheet) ──────────────────────────────────────────────

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
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.bord, borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Selecionar membro',
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.tx,
              ),
            ),
          ),
          ...membros.map((m) => ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.grn.withOpacity(0.2),
              child: Text(
                ((m['nome'] as String? ?? '?')[0]).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.grn, fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              m['nome'] as String? ?? '',
              style: const TextStyle(color: AppColors.tx),
            ),
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
