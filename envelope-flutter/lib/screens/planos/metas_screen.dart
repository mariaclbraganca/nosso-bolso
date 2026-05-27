import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/metas_provider.dart';
import '../../services/financeiro_ext_service.dart';
import 'adicionar_meta_sheet.dart';

class MetasScreen extends ConsumerWidget {
  const MetasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metasAsync = ref.watch(metasProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.acc,
        backgroundColor: AppColors.surf,
        onRefresh: () async => ref.invalidate(metasProvider),
        child: metasAsync.when(
          data: (metas) => metas.isEmpty
              ? _EmptyState(onAdd: () => _abrirAdicionar(context, ref))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: metas.map((m) => _MetaCard(
                    meta: m,
                    onContribuir: () => _contribuir(context, ref, m),
                    onDeletar: () async {
                      await FinanceiroExtService.deletarMeta(m['_id'] as String);
                      ref.invalidate(metasProvider);
                    },
                  )).toList(),
                ),
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acc)),
          error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: AppColors.red))),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.acc,
        foregroundColor: Colors.black,
        onPressed: () => _abrirAdicionar(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _abrirAdicionar(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AdicionarMetaSheet(),
    ).then((saved) {
      if (saved == true) ref.invalidate(metasProvider);
    });
  }

  void _contribuir(BuildContext context, WidgetRef ref, Map<String, dynamic> meta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContribuirSheet(meta: meta, onSaved: () => ref.invalidate(metasProvider)),
    );
  }
}

// ── Meta card ─────────────────────────────────────────────────────────────────

class _MetaCard extends StatelessWidget {
  final Map<String, dynamic> meta;
  final VoidCallback onContribuir;
  final VoidCallback onDeletar;
  const _MetaCard({required this.meta, required this.onContribuir, required this.onDeletar});

  @override
  Widget build(BuildContext context) {
    final nome     = meta['nome'] as String? ?? '';
    final emoji    = meta['emoji'] as String? ?? '🎯';
    final metaVal  = (meta['valor_meta'] as num?)?.toDouble() ?? 1;
    final atual    = (meta['valor_atual'] as num?)?.toDouble() ?? 0;
    final corHex   = meta['cor'] as String? ?? '#60A5FA';
    final concluida = meta['concluida'] as bool? ?? false;
    final pct      = (atual / metaVal).clamp(0.0, 1.0);

    Color color;
    try {
      color = Color(int.parse(corHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      color = AppColors.blu;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: concluida ? AppColors.grn.withOpacity(0.5) : AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(nome, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.tx)),
                        ),
                        if (concluida)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.grn.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                            child: const Text('✅ Concluída', style: TextStyle(fontSize: 11, color: AppColors.grn)),
                          ),
                      ],
                    ),
                    Text(
                      'R\$ ${atual.toStringAsFixed(2).replaceAll('.', ',')} de R\$ ${metaVal.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: const TextStyle(fontSize: 12, color: AppColors.mu),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDeletar,
                child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.mu),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.surf,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(pct * 100).toInt()}% alcançado',
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
              ),
              if (!concluida)
                GestureDetector(
                  onTap: onContribuir,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('+ Contribuir', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Contribuir sheet ──────────────────────────────────────────────────────────

class _ContribuirSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> meta;
  final VoidCallback onSaved;
  const _ContribuirSheet({required this.meta, required this.onSaved});

  @override
  ConsumerState<_ContribuirSheet> createState() => _ContribuirSheetState();
}

class _ContribuirSheetState extends ConsumerState<_ContribuirSheet> {
  final _ctrl = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final nome = widget.meta['nome'] as String? ?? '';
    final faltam = ((widget.meta['valor_meta'] as num?)?.toDouble() ?? 0) -
        ((widget.meta['valor_atual'] as num?)?.toDouble() ?? 0);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 20, left: 20, right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text('Contribuir para $nome', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.tx)),
          Text('Faltam R\$ ${faltam.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontSize: 12, color: AppColors.mu)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.tx, fontSize: 22, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: '0,00',
              hintStyle: TextStyle(color: AppColors.mu),
              prefixText: 'R\$ ',
              prefixStyle: TextStyle(color: AppColors.mu, fontSize: 18),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _salvando ? null : _salvar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.acc,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _salvando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.savings_rounded),
              label: Text(_salvando ? 'Salvando...' : 'Adicionar à meta', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _salvar() async {
    final valor = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (valor == null || valor <= 0) return;

    setState(() => _salvando = true);
    try {
      await FinanceiroExtService.contribuirMeta(widget.meta['_id'] as String, valor: valor);
      if (mounted) Navigator.of(context).pop();
      widget.onSaved();
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
      );
    }
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 32),
      child: Column(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          const Text('Nenhuma meta criada', style: TextStyle(fontSize: 15, color: AppColors.tx, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('Defina objetivos financeiros e acompanhe o progresso', style: TextStyle(fontSize: 12, color: AppColors.mu), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.acc, side: const BorderSide(color: AppColors.acc), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Criar meta'),
          ),
        ],
      ),
    ),
  );
}
