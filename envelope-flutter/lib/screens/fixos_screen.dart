import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../providers/usuarios_provider.dart';
import '../providers/fixos_provider.dart';
import '../providers/mes_provider.dart';
import 'form_fixo_sheet.dart';
import '../providers/astrix_provider.dart';
import '../widgets/mascote/astrix_painter.dart' show AstrixMood;
import '../widgets/mascote/unicorn_screen_guard.dart';

/// Widget embeddable sem Scaffold — usado dentro do PlanosScreen (TabBarView).
class FixosScreen extends ConsumerStatefulWidget {
  const FixosScreen({super.key});

  @override
  ConsumerState<FixosScreen> createState() => _FixosScreenState();
}

class _FixosScreenState extends ConsumerState<FixosScreen> {
  @override
  void initState() {
    super.initState();
    if (UnicornScreenGuard.shouldShow('fixos')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.astrix(
          'Suas despesas fixas — o alicerce do seu orçamento mensal. Vamos verificar!',
          mood: AstrixMood.wave,
        );
      });
    }
  }

  Future<void> _togglePago(String id, bool val) async {
    try {
      await ApiService.patch('/fixos/$id', {'pago': val});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(val ? '✅ Marcado como pago' : '↩ Desfeito'),
          backgroundColor: val ? AppColors.grn : AppColors.org,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red));
    }
  }

  Future<void> _liberarFixo(String id, String nome) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Liberar fixo?'),
        content: Text('Remover "$nome" da lista e liberar o valor para os envelopes?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Liberar', style: TextStyle(color: AppColors.acc))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final perfil = ref.read(perfilUsuarioLogadoProvider).value;
      await ApiService.delete('/fixos/$id', familiaId: perfil?['familia_id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$nome liberado'), backgroundColor: AppColors.acc));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red));
    }
  }

  Future<void> _deletarFixoPago(String id, String nome) => _liberarFixo(id, nome);

  @override
  Widget build(BuildContext context) {
    final fixosAsync = ref.watch(fixosStreamProvider);

    return fixosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acc)),
      error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: AppColors.red))),
      data: (_) => _buildContent(ref.watch(fixosMesAtualProvider)),
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> fixos) {
    final fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final fmtS = NumberFormat.simpleCurrency(locale: 'pt_BR', decimalDigits: 0);
    final totalVal = fixos.fold(0.0, (s, f) => s + (f['valor'] as num).toDouble());
    final paidVal = fixos.where((f) => f['pago'] == true).fold(0.0, (s, f) => s + (f['valor'] as num).toDouble());
    final pendVal = totalVal - paidVal;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
          children: [
            // Seletor de mês
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => ref.read(mesAtualProvider.notifier).state = mesAnterior(ref.read(mesAtualProvider)),
                    child: const Icon(Icons.chevron_left, size: 22, color: AppColors.mu),
                  ),
                  const SizedBox(width: 8),
                  Consumer(builder: (_, r, __) => Text(
                    mesLabelLongo(r.watch(mesAtualProvider)),
                    style: const TextStyle(fontSize: 13, color: AppColors.mu, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  )),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => ref.read(mesAtualProvider.notifier).state = mesProximo(ref.read(mesAtualProvider)),
                    child: const Icon(Icons.chevron_right, size: 22, color: AppColors.mu),
                  ),
                ],
              ),
            ),

            // Summary cards
            Row(children: [
              _miniCard('TOTAL/MÊS', fmtS.format(totalVal), AppColors.tx),
              const SizedBox(width: 8),
              _miniCard('✓ PAGO', fmtS.format(paidVal), AppColors.grn),
              const SizedBox(width: 8),
              _miniCard('🔒 RESERVADO', fmtS.format(pendVal), AppColors.org),
            ]),
            const SizedBox(height: 14),

            if (fixos.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text('Nenhum gasto fixo cadastrado', style: TextStyle(color: AppColors.mu)),
                ),
              )
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: fixos.asMap().entries.map((entry) {
                    return _buildFixoItem(entry.value, entry.key > 0, fmt);
                  }).toList(),
                ),
              ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.acc.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.acc.withOpacity(0.2)),
              ),
              child: const Text(
                '💡 Fixos pendentes ficam reservados do saldo geral. Ao marcar como pago, o valor é debitado. Deslize para a esquerda para liberar.',
                style: TextStyle(fontSize: 12, color: AppColors.acc, height: 1.6),
              ),
            ),
          ],
        ),

        // FAB posicionado dentro do Stack para não conflitar com Scaffold externo
        Positioned(
          bottom: 24,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'fixos_fab',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const FormFixoSheet(),
            ),
            backgroundColor: AppColors.acc,
            child: const Icon(Icons.add, color: AppColors.bg),
          ),
        ),
      ],
    );
  }

  Widget _buildFixoItem(Map<String, dynamic> f, bool showDivider, NumberFormat fmt) {
    final isPago = f['pago'] == true;
    final color = isPago ? AppColors.grn : AppColors.org;

    return Column(children: [
      if (showDivider) const Divider(height: 1, color: AppColors.bord),
      Dismissible(
        key: Key(f['id']),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          if (isPago) {
            await _deletarFixoPago(f['id'], f['nome']);
          } else {
            await _liberarFixo(f['id'], f['nome']);
          }
          return false;
        },
        background: Container(
          color: isPago ? AppColors.red.withOpacity(0.1) : AppColors.acc.withOpacity(0.1),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: Text(
            isPago ? 'Excluir 🗑️' : 'Liberar ⚡',
            style: TextStyle(color: isPago ? AppColors.red : AppColors.acc, fontWeight: FontWeight.bold),
          ),
        ),
        child: InkWell(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => FormFixoSheet(fixo: f),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Text(isPago ? '✅' : '🔒', style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f['nome'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(isPago ? 'Pago' : 'Reservado', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Text(fmt.format(f['valor']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                SizedBox(
                  height: 24, width: 44,
                  child: Switch(
                    value: isPago,
                    onChanged: (v) => _togglePago(f['id'], v),
                    activeColor: Colors.white,
                    activeTrackColor: AppColors.grn,
                    inactiveThumbColor: AppColors.mu,
                    inactiveTrackColor: AppColors.bord,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _miniCard(String label, String val, Color color) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.mu)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    ),
  );
}
