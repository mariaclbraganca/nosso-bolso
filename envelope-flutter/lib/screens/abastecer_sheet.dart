import 'package:envelope_flutter/providers/usuarios_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/envelopes_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/fixos_provider.dart';
import '../theme/app_theme.dart';
import '../constants.dart';
import '../widgets/abastecer_item.dart';

class AbastecerSheet extends ConsumerStatefulWidget {
  const AbastecerSheet({super.key});
  @override
  ConsumerState<AbastecerSheet> createState() => _AbastecerSheetState();
}

// Margem de meio centavo para neutralizar erros de IEEE 754 ao comparar totais
const double _kToleranciaCentavo = 0.005;

class _AbastecerSheetState extends ConsumerState<AbastecerSheet> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _calcularTotal() {
    double total = 0;
    _controllers.forEach((_, c) {
      total += double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
    });
    return total;
  }

  void _usarRestante(String envelopeId) {
    double outrosTotal = 0;
    _controllers.forEach((id, c) {
      if (id != envelopeId) {
        outrosTotal += double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
      }
    });
    final saldoGeral = ref.read(saldoGeralProvider).value ?? 0.0;
    final reservado = ref.read(totalReservadoProvider);
    final livre = saldoGeral - reservado;
    final disponivel = livre - outrosTotal;
    if (disponivel <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sem saldo livre para distribuir.'),
        backgroundColor: AppColors.org,
      ));
      return;
    }
    _controllers[envelopeId]?.text = disponivel.toStringAsFixed(2).replaceAll('.', ',');
    setState(() {});
  }

  void _confirmar() async {
    final saldoGeral = ref.read(saldoGeralProvider).value ?? 0.0;
    final reservado = ref.read(totalReservadoProvider);
    final livre = saldoGeral - reservado;
    final total = _calcularTotal();
    
    final perfil = ref.read(perfilUsuarioLogadoProvider).value;
    if (perfil == null || perfil['familia_id'] == null) throw 'Usuário sem família';

    if (total > livre + _kToleranciaCentavo) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excede o saldo livre para envelopes.'), backgroundColor: AppColors.red));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final List<Map<String, dynamic>> bodies = [];
      _controllers.forEach((id, controller) {
        final val = double.tryParse(controller.text.replaceAll(',', '.'));
        if (val != null && val > 0) {
          bodies.add({
            'valor': val, 
            'tipo': 'abastecimento', 
            'envelope_id': id, 
            'usuario_id': perfil['id'], 
            'descricao': 'Abastecimento',
            'familia_id': perfil['familia_id'],
          });
        }
      });

      if (bodies.isNotEmpty) await supabase.from('transacoes').insert(bodies);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final envelopes = ref.watch(envelopesProvider).value ?? [];
    final saldoGeral = ref.watch(saldoGeralProvider).value ?? 0.0;
    final reservado = ref.watch(totalReservadoProvider);
    final livre = saldoGeral - reservado;
    final total = _calcularTotal();
    final isExceeded = total > livre + _kToleranciaCentavo;
    final fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(bottom: 20)),
          const Text('Distribuir saldo ⚡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          // Show saldo breakdown
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.acc.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.acc.withOpacity(0.2)),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Saldo geral', style: TextStyle(fontSize: 11, color: AppColors.mu)),
                Text(fmt.format(saldoGeral), style: const TextStyle(fontSize: 11, color: AppColors.tx, fontWeight: FontWeight.bold)),
              ]),
              if (reservado > 0) ...[
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('🔒 Reservado fixos', style: TextStyle(fontSize: 11, color: AppColors.org)),
                  Text('- ${fmt.format(reservado)}', style: const TextStyle(fontSize: 11, color: AppColors.org, fontWeight: FontWeight.bold)),
                ]),
              ],
              const Divider(color: AppColors.bord, height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('⚡ Livre p/ envelopes', style: TextStyle(fontSize: 12, color: AppColors.acc, fontWeight: FontWeight.bold)),
                Text(fmt.format(livre > 0 ? livre : 0), style: const TextStyle(fontSize: 14, color: AppColors.acc, fontWeight: FontWeight.bold)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: envelopes.length,
              itemBuilder: (ctx, i) {
                final e = envelopes[i];
                final id = e['id'];
                if (!_controllers.containsKey(id)) _controllers[id] = TextEditingController();
                return AbastecerItem(
                  envelope: e,
                  controller: _controllers[id]!,
                  onChanged: () => setState(() {}),
                  onUsarRestante: () => _usarRestante(id),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _buildSummary(total, isExceeded, livre),
        ],
      ),
    );
  }

  Widget _buildSummary(double total, bool isExceeded, double livre) => Column(
    children: [
      if (total > 0) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Total: ${NumberFormat.simpleCurrency(locale: "pt_BR").format(total)} ${isExceeded ? "(Excede o livre)" : ""}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isExceeded ? AppColors.red : AppColors.tx))),
      ElevatedButton(
        onPressed: (_isSaving || isExceeded || total <= 0) ? null : _confirmar,
        style: ElevatedButton.styleFrom(backgroundColor: isExceeded ? AppColors.red.withOpacity(0.5) : AppColors.acc, minimumSize: const Size.fromHeight(55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: _isSaving ? const CircularProgressIndicator(color: AppColors.bg) : Text(isExceeded ? 'Excede saldo livre' : 'Confirmar abastecimento', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.bg)),
      ),
    ],
  );
}
