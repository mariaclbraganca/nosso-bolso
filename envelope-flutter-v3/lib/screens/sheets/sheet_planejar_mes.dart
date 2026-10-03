import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/envelopes_provider.dart';
import '../../core/providers/fixos_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/moeda.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import 'comum.dart';

/// Define o valor planejado de todos os envelopes de uma vez (o "orçamento"
/// do mês). Não move dinheiro: isso é o Abastecer.
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
      avisar('Plano do mês salvo (${mudados.length} ${mudados.length == 1 ? 'envelope' : 'envelopes'}).');
      Navigator.pop(context, true);
    } else {
      avisar('${falhas.length} envelope(s) não salvaram. Tente de novo.', erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final envelopes = ref.watch(envelopesViseisProvider);
    final saldoLivre = ref.watch(saldoLivreProvider);
    for (final env in envelopes) {
      _ctrl(env); // cria os campos antes de somar, senão o 1º frame mostra total zero
    }
    final total = _total;
    final sobra = saldoLivre - total;

    return CascaSheet(
      filhos: [
        const TopoSheet(
          titulo: 'Planejar o mês',
          subtitulo: 'Quanto cada envelope deve receber. Depois é só abastecer.',
        ),
        const SizedBox(height: NBSpacing.l),
        CartaoNB(
          child: Column(
            children: [
              LinhaPrevia(rotulo: 'Saldo geral livre (sem fixos pendentes)', valor: saldoLivre),
              LinhaPrevia(rotulo: 'Total planejado', valor: total),
              const Divider(height: 16),
              LinhaPrevia(rotulo: sobra >= 0 ? 'Sobra para distribuir' : 'Planejado acima do saldo', valor: sobra,
                  corValor: NBColors.verde),
            ],
          ),
        ),
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
      botao: BotaoPrincipal(rotulo: 'Salvar plano', carregando: _salvando, onPressed: _salvar),
    );
  }
}
