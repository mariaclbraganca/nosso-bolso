import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/contas_provider.dart';
import '../../services/financeiro_ext_service.dart';
import 'adicionar_conta_sheet.dart';

class ContasScreen extends ConsumerWidget {
  const ContasScreen({super.key});

  String get _mes {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contasAsync = ref.watch(contasMesProvider(_mes));
    final resumoAsync = ref.watch(resumoContasProvider(_mes));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.blu,
        backgroundColor: AppColors.surf,
        onRefresh: () async {
          ref.invalidate(contasMesProvider);
          ref.invalidate(resumoContasProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Resumo do mês
            resumoAsync.when(
              data: (r) => _ResumoCard(resumo: r),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('CONTAS DO MÊS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mu, letterSpacing: 1.2)),
                TextButton.icon(
                  onPressed: () => _abrirAdicionar(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.blu),
                  label: const Text('Adicionar', style: TextStyle(color: AppColors.blu, fontSize: 13)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ],
            ),
            const SizedBox(height: 8),
            contasAsync.when(
              data: (contas) => contas.isEmpty
                  ? _EmptyState(onAdd: () => _abrirAdicionar(context, ref))
                  : Column(
                      children: contas.map((c) => _ContaTile(
                        conta: c,
                        onPagar: () async {
                          try {
                            final pago = !(c['pago'] as bool? ?? false);
                            await FinanceiroExtService.marcarPaga(c['_id'] as String, pago: pago);
                            ref.invalidate(contasMesProvider);
                            ref.invalidate(resumoContasProvider);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
                              );
                            }
                          }
                        },
                        onDeletar: () async {
                          try {
                            await FinanceiroExtService.deletarConta(c['_id'] as String);
                            ref.invalidate(contasMesProvider);
                            ref.invalidate(resumoContasProvider);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
                              );
                            }
                          }
                        },
                      )).toList(),
                    ),
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.blu),
              )),
              error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: AppColors.red))),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirAdicionar(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdicionarContaSheet(mes: _mes),
    ).then((saved) {
      if (saved == true) {
        ref.invalidate(contasMesProvider);
        ref.invalidate(resumoContasProvider);
      }
    });
  }
}

// ── Resumo card ───────────────────────────────────────────────────────────────

class _ResumoCard extends StatelessWidget {
  final Map<String, dynamic> resumo;
  const _ResumoCard({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final total     = (resumo['total'] as num?)?.toDouble() ?? 0;
    final pagas     = (resumo['pagas'] as num?)?.toDouble() ?? 0;
    final pendentes = (resumo['pendentes'] as num?)?.toDouble() ?? 0;
    final vencidas  = (resumo['vencidas'] as num?)?.toDouble() ?? 0;
    final pct       = total > 0 ? pagas / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total: R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.tx)),
              if (vencidas > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('R\$ ${vencidas.toStringAsFixed(2)} vencidas',
                      style: const TextStyle(fontSize: 11, color: AppColors.red)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: AppColors.surf,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.grn),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Pill('✅ R\$ ${pagas.toStringAsFixed(2)} pagas', AppColors.grn),
              const SizedBox(width: 8),
              _Pill('⏳ R\$ ${pendentes.toStringAsFixed(2)} pendentes', AppColors.org),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, color: color)),
  );
}

// ── Conta tile ────────────────────────────────────────────────────────────────

class _ContaTile extends StatelessWidget {
  final Map<String, dynamic> conta;
  final VoidCallback onPagar;
  final VoidCallback onDeletar;
  const _ContaTile({required this.conta, required this.onPagar, required this.onDeletar});

  @override
  Widget build(BuildContext context) {
    final nome      = conta['nome'] as String? ?? '';
    final valor     = (conta['valor'] as num?)?.toDouble() ?? 0;
    final venc      = conta['vencimento'] as String? ?? '';
    final pago      = conta['pago'] as bool? ?? false;
    final categoria = conta['categoria'] as String?;
    final emoji     = emojiCategoria(categoria);

    final parts   = venc.split('-');
    final vencFmt = parts.length == 3 ? '${parts[2]}/${parts[1]}' : venc;

    final hoje     = DateTime.now();
    final vencDate = parts.length == 3 ? DateTime.tryParse(venc) : null;
    final vencida  = !pago && vencDate != null && vencDate.isBefore(DateTime(hoje.year, hoje.month, hoje.day));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: vencida ? AppColors.red.withOpacity(0.4)
              : pago ? AppColors.grn.withOpacity(0.3)
              : AppColors.bord,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPagar,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pago ? AppColors.grn.withOpacity(0.2) : AppColors.surf,
                border: Border.all(color: pago ? AppColors.grn : AppColors.bord),
              ),
              child: pago ? const Icon(Icons.check_rounded, size: 16, color: AppColors.grn) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('$emoji ', style: const TextStyle(fontSize: 14)),
                    Expanded(
                      child: Text(
                        nome,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: pago ? AppColors.mu : AppColors.tx,
                          decoration: pago ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Vence $vencFmt${vencida ? ' · VENCIDA' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: vencida ? AppColors.red : AppColors.mu,
                    fontWeight: vencida ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: pago ? AppColors.mu : AppColors.tx,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDeletar,
            child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.mu),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Text('🧾', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          const Text('Nenhuma conta este mês', style: TextStyle(fontSize: 15, color: AppColors.tx, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('Adicione suas contas para controlar vencimentos', style: TextStyle(fontSize: 12, color: AppColors.mu), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.blu, side: const BorderSide(color: AppColors.blu), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar conta'),
          ),
        ],
      ),
    ),
  );
}
