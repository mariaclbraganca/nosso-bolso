import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class MealSlotCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String horarioDica;
  final List<Map<String, dynamic>> refeicoes;
  final VoidCallback onRegistrar;
  final VoidCallback onPular;
  final Future<void> Function(String id) onDeletar;

  const MealSlotCard({
    super.key,
    required this.icon,
    required this.label,
    required this.horarioDica,
    required this.refeicoes,
    required this.onRegistrar,
    required this.onPular,
    required this.onDeletar,
  });

  @override
  Widget build(BuildContext context) {
    final ativas = refeicoes
        .where((r) => r['deleted_at'] == null && r['is_jejum'] != true)
        .toList();
    final puladas = refeicoes
        .where((r) => r['is_jejum'] == true && r['deleted_at'] == null)
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ativas.isNotEmpty
              ? AppColors.grn.withOpacity(0.35)
              : puladas.isNotEmpty
                  ? AppColors.pur.withOpacity(0.35)
                  : AppColors.bord,
          width: 0.8,
        ),
      ),
      child: ativas.isNotEmpty
          ? _FilledSlot(icon: icon, label: label, refeicoes: ativas, onRegistrar: onRegistrar, onDeletar: onDeletar)
          : puladas.isNotEmpty
              ? _PuladaSlot(icon: icon, label: label, onRegistrar: onRegistrar)
              : _EmptySlot(icon: icon, label: label, horarioDica: horarioDica, onRegistrar: onRegistrar, onPular: onPular),
    );
  }
}

// ── Empty ─────────────────────────────────────────────────────────────────────

class _EmptySlot extends StatelessWidget {
  final IconData icon;
  final String label;
  final String horarioDica;
  final VoidCallback onRegistrar;
  final VoidCallback onPular;

  const _EmptySlot({
    required this.icon,
    required this.label,
    required this.horarioDica,
    required this.onRegistrar,
    required this.onPular,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.mu, size: 15),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.tx)),
            const Spacer(),
            Text(horarioDica, style: const TextStyle(fontSize: 11, color: AppColors.mu)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: onRegistrar,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.grn.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.grn.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_rounded, color: AppColors.grn, size: 15),
                      SizedBox(width: 4),
                      Text('Registrar o que comi',
                          style: TextStyle(fontSize: 12, color: AppColors.grn, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onPular,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.surf,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.bord, width: 0.5),
                ),
                child: const Text('Pular', style: TextStyle(fontSize: 12, color: AppColors.mu)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Filled ────────────────────────────────────────────────────────────────────

class _FilledSlot extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Map<String, dynamic>> refeicoes;
  final VoidCallback onRegistrar;
  final Future<void> Function(String id) onDeletar;

  const _FilledSlot({
    required this.icon,
    required this.label,
    required this.refeicoes,
    required this.onRegistrar,
    required this.onDeletar,
  });

  @override
  Widget build(BuildContext context) {
    final totalKcal = refeicoes.fold<int>(0, (sum, r) {
      final macros = r['macros_totais'] as Map<String, dynamic>? ?? {};
      return sum + ((macros['calorias_kcal'] as num?)?.toInt() ?? 0);
    });

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: AppColors.grn.withOpacity(0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: AppColors.grn, size: 13),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.tx)),
            const Spacer(),
            const Icon(Icons.check_circle_rounded, color: AppColors.grn, size: 13),
            const SizedBox(width: 4),
            Text('$totalKcal kcal',
                style: const TextStyle(fontSize: 12, color: AppColors.grn, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          ...refeicoes.map((r) {
            final desc = (r['descricao'] as String? ?? '').trim();
            final macros = r['macros_totais'] as Map<String, dynamic>? ?? {};
            final kcal = (macros['calorias_kcal'] as num?)?.toInt() ?? 0;
            final prot = (macros['proteina_g'] as num?)?.toInt() ?? 0;
            final id = r['id'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.circle, size: 4, color: AppColors.mu),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      desc.length > 45 ? '${desc.substring(0, 45)}…' : desc,
                      style: const TextStyle(fontSize: 12, color: AppColors.tx),
                    ),
                    Text('${kcal}kcal · P${prot}g',
                        style: const TextStyle(fontSize: 11, color: AppColors.mu)),
                  ]),
                ),
                GestureDetector(
                  onTap: () => onDeletar(id),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(8, 0, 0, 0),
                    child: Icon(Icons.close, size: 14, color: AppColors.mu),
                  ),
                ),
              ]),
            );
          }),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onRegistrar,
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.add_rounded, color: AppColors.mu, size: 13),
              SizedBox(width: 3),
              Text('Adicionar mais', style: TextStyle(fontSize: 11, color: AppColors.mu)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Pulada ────────────────────────────────────────────────────────────────────

class _PuladaSlot extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onRegistrar;

  const _PuladaSlot({required this.icon, required this.label, required this.onRegistrar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Icon(icon, color: AppColors.mu, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.tx)),
            const Text('Pulada', style: TextStyle(fontSize: 11, color: AppColors.pur)),
          ]),
        ),
        GestureDetector(
          onTap: onRegistrar,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surf,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.bord, width: 0.5),
            ),
            child: const Text('Registrar mesmo assim', style: TextStyle(fontSize: 11, color: AppColors.mu)),
          ),
        ),
      ]),
    );
  }
}
