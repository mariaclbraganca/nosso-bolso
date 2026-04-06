import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../providers/usuarios_provider.dart';
import '../providers/fixos_provider.dart';
import 'form_fixo_sheet.dart';

class FixosScreen extends ConsumerStatefulWidget {
  const FixosScreen({super.key});

  @override
  ConsumerState<FixosScreen> createState() => _FixosScreenState();
}

class _FixosScreenState extends ConsumerState<FixosScreen> {
  Future<void> _togglePago(String id, bool val) async {
    try {
      // REGRA SPEC-01/02: Usar o backend para gerenciar o toggle e o saldo atômico
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

  // Mesma lógica de deleção simplificada
  Future<void> _deletarFixoPago(String id, String nome) => _liberarFixo(id, nome);

  @override
  Widget build(BuildContext context) {
    final fixosAsync = ref.watch(fixosStreamProvider);

    return fixosAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erro: $e'))),
      data: (fixos) => _buildBody(fixos),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> fixos) {
    final fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final fmtS = NumberFormat.simpleCurrency(locale: 'pt_BR', decimalDigits: 0);
    double totalVal = fixos.fold(0.0, (s, f) => s + (f['valor'] as num).toDouble());
    double paidVal = fixos.where((f) => f['pago'] == true).fold(0.0, (s, f) => s + (f['valor'] as num).toDouble());
    double pendVal = totalVal - paidVal;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GASTOS FIXOS', style: TextStyle(fontSize: 11, color: AppColors.mu, letterSpacing: 0.5)),
            Text('Separados dos envelopes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        children: [
          // Summary cards
          Row(children: [
            _miniCard('TOTAL/MÊS', fmtS.format(totalVal), AppColors.tx),
            const SizedBox(width: 8),
            _miniCard('✓ PAGO', fmtS.format(paidVal), AppColors.grn),
            const SizedBox(width: 8),
            _miniCard('🔒 RESERVADO', fmtS.format(pendVal), AppColors.org),
          ]),
          const SizedBox(height: 14),

          // List
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: fixos.asMap().entries.map((entry) {
              final i = entry.key;
              final f = entry.value;
              return _buildFixoItem(f, i > 0, fmt);
            }).toList()),
          ),

          const SizedBox(height: 12),

          // Info card
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const FormFixoSheet(),
        ),
        backgroundColor: AppColors.acc,
        child: const Icon(Icons.add, color: AppColors.bg),
      ),
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
          child: Text(isPago ? 'Excluir 🗑️' : 'Liberar ⚡', style: TextStyle(color: isPago ? AppColors.red : AppColors.acc, fontWeight: FontWeight.bold)),
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
    child: Card(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.mu)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
      ]),
    )),
  );
}
