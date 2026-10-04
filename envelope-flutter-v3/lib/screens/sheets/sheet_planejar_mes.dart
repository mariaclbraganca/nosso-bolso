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
import '../planos/widgets/limite_resumo_card.dart';
import 'comum.dart';

/// Orçamento mensal: quanto vai para cada envelope, comparado ao limite de
/// compras do mês. Usado como aba (Orçamento) e como folha (botão da Início).
class OrcamentoMensal extends ConsumerStatefulWidget {
  const OrcamentoMensal({super.key, this.emFolha = false});
  final bool emFolha;

  @override
  ConsumerState<OrcamentoMensal> createState() => _OrcamentoMensalState();
}

class _OrcamentoMensalState extends ConsumerState<OrcamentoMensal> {
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

  List<MapEntry<String, TextEditingController>> get _mudados =>
      _ctrls.entries.where((e) => (parseMoeda(e.value.text) - (_original[e.key] ?? 0)).abs() > 0.004).toList();

  Future<void> _salvar() async {
    final mudados = _mudados;
    if (mudados.isEmpty) {
      if (widget.emFolha) Navigator.pop(context);
      return;
    }
    setState(() => _salvando = true);
    final p = perfilOuErro(ref);
    final nomes = {for (final e in ref.read(envelopesProvider).valueOrNull ?? const <Map<String, dynamic>>[]) e['id']: e['nome_envelope']};
    final falhas = <String>[];
    for (final m in mudados) {
      try {
        await ApiService.put('/envelopes/${m.key}?familia_id=${p['familia_id']}', {'valor_planejado': parseMoeda(m.value.text)});
        _original[m.key] = parseMoeda(m.value.text);
      } catch (e) {
        debugPrint('[Orçamento] ${nomes[m.key]}: $e');
        falhas.add('${nomes[m.key] ?? 'Envelope'}: ${mensagemErro(e)}');
      }
    }
    ref.invalidate(envelopesProvider);
    if (!mounted) return;
    setState(() => _salvando = false);
    if (falhas.isEmpty) {
      avisar('Orçamento salvo (${mudados.length} ${mudados.length == 1 ? 'envelope' : 'envelopes'}).');
      if (widget.emFolha) Navigator.pop(context, true);
    } else {
      avisar('Não salvou — ${falhas.join(' · ')}', erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reserva e vale-alimentação ficam fora: o VA tem limite próprio.
    final envelopes = ref.watch(envelopesViseisProvider).where((e) => e['is_reserva'] != true && !ehEnvelopeVa(e)).toList();
    for (final env in envelopes) {
      _ctrl(env); // cria os campos antes de somar, senão o 1º frame mostra total zero
    }
    final total = envelopes.fold(0.0, (s, e) => s + parseMoeda(_ctrl(e).text));
    final limite = ref.watch(limiteMesProvider).valueOrNull;

    final filhos = <Widget>[
      if (limite != null)
        LimiteResumoCard(limite: limite, totalOrcado: total)
      else
        CartaoNB(child: LinhaValorNB('Total planejado dos envelopes', total, forte: true)),
      const SizedBox(height: NBSpacing.l),
      Text('Orçado por envelope', style: NBText.secao),
      Text('Compras no cartão ou Pix. Altere os valores e veja o saldo a distribuir mudar.', style: NBText.legenda),
      const SizedBox(height: NBSpacing.s),
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
                  inputFormatters: [ReaisInputFormatter()],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(prefixText: 'R\$ ', hintText: '0,00', isDense: true),
                ),
              ),
            ],
          ),
        ),
      if (limite != null && limite.limiteVa > 0)
        CartaoNB(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Vale-alimentação', style: NBText.rotulo),
                Text('Orçamento próprio, fora do salário: ${brl(limite.vaMensal)} + sobra do mês anterior', style: NBText.legenda),
              ]),
            ),
            Text(brl(limite.limiteVa), style: NBText.valorCartao.copyWith(fontSize: 18)),
          ]),
        ),
    ];
    final botao = BotaoPrincipal(rotulo: 'Salvar orçamento', carregando: _salvando, onPressed: _salvar);

    if (widget.emFolha) {
      return CascaSheet(filhos: [const TopoSheet(titulo: 'Orçamento mensal'), const SizedBox(height: NBSpacing.l), ...filhos], botao: botao);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 4, NBSpacing.margemTela, 120),
      children: [
        ...filhos,
        if (_mudados.isNotEmpty || _salvando) ...[const SizedBox(height: NBSpacing.l), botao],
      ],
    );
  }
}

/// Folha do botão "Orçamento" da Início.
class SheetPlanejarMes extends StatelessWidget {
  const SheetPlanejarMes({super.key});

  @override
  Widget build(BuildContext context) => const OrcamentoMensal(emFolha: true);
}
