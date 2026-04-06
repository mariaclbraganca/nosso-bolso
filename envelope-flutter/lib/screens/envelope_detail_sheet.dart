import 'package:envelope_flutter/screens/form_fixo_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../constants.dart';
import '../providers/envelopes_provider.dart';
import 'form_gasto_sheet.dart';
import 'form_envelope_sheet.dart';
import 'remanejar_sheet.dart';

class EnvelopeDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> envelope;
  final bool isAdmin;
  const EnvelopeDetailSheet({super.key, required this.envelope, required this.isAdmin});

  @override
  ConsumerState<EnvelopeDetailSheet> createState() => _EnvelopeDetailSheetState();
}

class _EnvelopeDetailSheetState extends ConsumerState<EnvelopeDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final id = widget.envelope['id'];
    
    // Assinar as mudanças do envelope específico em tempo real
    final envelopesAsync = ref.watch(envelopesProvider);
    
    return envelopesAsync.when(
      data: (lista) {
        final env = lista.firstWhere((e) => e['id'] == id, orElse: () => widget.envelope);
        final saldo = (env['saldo_atual'] as num).toDouble();
        final plan = (env['valor_planejado'] as num).toDouble();
        final pct = plan > 0 ? (saldo / plan).clamp(0.0, 1.0) : 0.0;
        final isNeg = saldo < 0;
        final spent = plan - saldo;

        Color color = AppColors.grn;
        if (pct <= 0.2) {
          color = AppColors.red;
        } else if (pct <= 0.5) {
          color = AppColors.org;
        }
        if (isNeg) {
          color = AppColors.dred;
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _buildHeader(env, color, isNeg, pct),
              _buildBalanceStats(saldo, plan, spent, color, pct),
              const Divider(color: AppColors.bord, height: 1),
              Expanded(child: _buildTransactionList(id)),
              _buildBottomAction(id, color, isNeg),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
    );
  }

  Widget _buildHeader(Map<String, dynamic> env, Color color, bool isNeg, double pct) => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    child: Column(
      children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(bottom: 20)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(env['emoji'] ?? '📦', style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(env['nome_envelope'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(50)),
                      child: Text(
                        isNeg ? 'NEGATIVO' : '${(pct * 100).toInt()}% restante',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                if (widget.isAdmin)
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => FormEnvelopeSheet(envelope: env),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined, color: AppColors.mu, size: 20),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.mu),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildBalanceStats(double saldo, double plan, double spent, Color color, double pct) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatCard('SALDO', NumberFormat.simpleCurrency(locale: 'pt_BR').format(saldo), color),
              const SizedBox(width: 10),
              _buildStatCard('PLANEJADO', NumberFormat.simpleCurrency(locale: 'pt_BR', decimalDigits: 0).format(plan), AppColors.mu),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.bord,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${NumberFormat.simpleCurrency(locale: "pt_BR").format(spent > 0 ? spent : 0)} gasto de ${NumberFormat.simpleCurrency(locale: "pt_BR").format(plan)} planejado',
              style: const TextStyle(fontSize: 12, color: AppColors.mu),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    ),
  );

  Widget _buildBottomAction(String id, Color color, bool isNeg) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.bg,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -5))],
    ),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => FormGastoSheet(initialEnvelopeId: id),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              minimumSize: const Size.fromHeight(55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              foregroundColor: isNeg ? Colors.white : AppColors.bg,
            ),
            child: const Text('+ Gasto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => RemanejarSheet(origem: widget.envelope),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surf,
              minimumSize: const Size.fromHeight(55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: const BorderSide(color: AppColors.bord),
            ),
            child: const Text('Mover', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
  );

  Widget _buildTransactionList(String envelopeId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('transacoes')
          .stream(primaryKey: ['id'])
          .eq('envelope_id', envelopeId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('Nenhuma transação neste envelope', style: TextStyle(color: AppColors.mu)));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(color: AppColors.bord, height: 1),
          itemBuilder: (context, index) {
            final t = list[index];
            return Dismissible(
              key: Key(t['id']),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => supabase.from('transacoes').delete().eq('id', t['id']),
              background: Container(color: AppColors.red.withOpacity(0.1), alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete_outline, color: AppColors.red)),
              child: _buildSimpleTransacaoItem(t),
            );
          },
        );
      },
    );
  }

  Widget _buildSimpleTransacaoItem(Map<String, dynamic> t) {
    final valor = (t['valor'] as num).toDouble();
    final isDsp = t['tipo'] == 'despesa';
    final date = DateFormat('dd MMM').format(DateTime.parse(t['created_at']));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t['descricao'] ?? (isDsp ? 'Gasto' : 'Abastecimento'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
              const SizedBox(height: 4),
              Text(date, style: const TextStyle(fontSize: 11, color: AppColors.mu)),
            ],
          ),
          Text(
            '${isDsp ? '-' : '+'} ${NumberFormat.simpleCurrency(locale: 'pt_BR').format(valor)}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDsp ? AppColors.red : AppColors.acc),
          ),
        ],
      ),
    );
  }
}
