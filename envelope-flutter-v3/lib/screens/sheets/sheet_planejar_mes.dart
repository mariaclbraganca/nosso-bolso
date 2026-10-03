import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/envelopes_provider.dart';
import '../../core/providers/plano_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/moeda.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../core/plano/plano_mes.dart';
import 'comum.dart';

/// Teto de cada envelope no mês (o dia a dia). Compara com o que sobra das
/// entradas depois das contas e do cartão — as mesmas contas da aba Mês.
class SheetPlanejarMes extends ConsumerStatefulWidget {
  const SheetPlanejarMes({super.key});

  @override
  ConsumerState<SheetPlanejarMes> createState() => _SheetPlanejarMesState();
}

class _SheetPlanejarMesState extends ConsumerState<SheetPlanejarMes> {
  static final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: '', decimalDigits: 2);
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, double> _original = {};
  bool _salvando = false;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(Map<String, dynamic> env) {
    final id = env['id'] as String;
    return _ctrls.putIfAbsent(id, () {
      final v = (env['valor_planejado'] as num?)?.toDouble() ?? 0;
      _original[id] = v;
      return TextEditingController(text: v > 0 ? _fmt.format(v).trim() : '');
    });
  }

  double get _total => _ctrls.values.fold(0.0, (s, c) => s + parseMoeda(c.text));

  Future<void> _salvar() async {
    final mudados = _ctrls.entries.where((e) => (parseMoeda(e.value.text) - (_original[e.key] ?? 0)).abs() > 0.004).toList();
    if (mudados.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _salvando = true);
    final p = perfilOuErro(ref);
    final falhas = <String>[];
    for (final m in mudados) {
      try {
        await ApiService.put('/envelopes/${m.key}?familia_id=${p['familia_id']}', {'valor_planejado': parseMoeda(m.value.text)});
      } catch (_) {
        falhas.add(m.key);
      }
    }
    ref.invalidate(envelopesProvider);
    if (!mounted) return;
    setState(() => _salvando = false);
    if (falhas.isEmpty) {
      avisar('Tetos salvos (${mudados.length} ${mudados.length == 1 ? 'envelope' : 'envelopes'}).');
      Navigator.pop(context, true);
    } else {
      avisar('${falhas.length} envelope(s) não salvaram. Tente de novo.', erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Envelope de reserva não é dia a dia: fica fora dos tetos do mês.
    final envelopes = ref.watch(envelopesViseisProvider).where((e) => e['is_reserva'] != true).toList();
    for (final env in envelopes) {
      _ctrl(env); // cria os campos antes de somar, senão o 1º frame mostra total zero
    }
    final total = _total;
    final plano = ref.watch(planoMesProvider).valueOrNull;

    return CascaSheet(
      filhos: [
        const TopoSheet(
          titulo: 'Tetos do mês',
          subtitulo: 'Quanto vocês se permitem gastar em cada envelope no dia a dia.',
        ),
        const SizedBox(height: NBSpacing.l),
        ResumoTetos(plano: plano, totalTetos: total),
        const SizedBox(height: NBSpacing.l),
        for (final env in envelopes)
          Padding(
            padding: const EdgeInsets.only(bottom: NBSpacing.s),
            child: Row(
              children: [
                Text(env['emoji'] as String? ?? '📦', style: const TextStyle(fontSize: 22)),
                const SizedBox(width: NBSpacing.s),
                Expanded(
                  child: Text(env['nome_envelope'] as String? ?? '', style: NBText.corpo, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _ctrl(env),
                    textAlign: TextAlign.end,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, MoedaInputFormatter()],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(prefixText: 'R\$ ', hintText: '0,00', isDense: true),
                  ),
                ),
              ],
            ),
          ),
      ],
      botao: BotaoPrincipal(rotulo: 'Salvar tetos', carregando: _salvando, onPressed: _salvar),
    );
  }
}

/// Entradas − contas − cartão = o que sobra para o dia a dia; menos os tetos
/// dá o resultado do mês (negativo = sai da reserva). Igual à aba Mês.
class ResumoTetos extends StatelessWidget {
  const ResumoTetos({super.key, required this.plano, required this.totalTetos});
  final PlanoMes? plano;
  final double totalTetos;

  @override
  Widget build(BuildContext context) {
    final p = plano;
    if (p == null) {
      return CartaoNB(child: LinhaPrevia(rotulo: 'Total dos tetos', valor: totalTetos));
    }
    final sobra = p.totalEntradas.previsto - p.totalContas.previsto - p.cartaoComprometido;
    final resultado = sobra - totalTetos;
    return CartaoNB(
      child: Column(
        children: [
          LinhaPrevia(rotulo: 'Entradas previstas', valor: p.totalEntradas.previsto),
          LinhaPrevia(rotulo: '(−) Contas do mês', valor: -p.totalContas.previsto),
          LinhaPrevia(rotulo: '(−) Cartão já comprometido', valor: -p.cartaoComprometido),
          const Divider(height: 16),
          LinhaPrevia(rotulo: 'Sobra para o dia a dia', valor: sobra),
          LinhaPrevia(rotulo: '(−) Seus tetos', valor: -totalTetos),
          const Divider(height: 16),
          LinhaPrevia(
            rotulo: resultado >= 0 ? 'Ainda dá para distribuir' : 'Vai faltar (sai da reserva)',
            valor: resultado,
            corValor: resultado >= 0 ? NBColors.verde : NBColors.estouro,
          ),
        ],
      ),
    );
  }
}
