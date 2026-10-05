import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/envelopes_provider.dart';
import '../../core/plano/plano_mes.dart';
import '../../core/providers/mes_provider.dart';
import '../../core/providers/plano_provider.dart';
import '../../core/providers/transacoes_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/moeda.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../planos/widgets/limite_resumo_card.dart';
import 'comum.dart';
import 'sheet_envelope.dart';

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
  final Set<String> _ativados = {}; // envelopes zerados que a pessoa trouxe para a lista
  bool _salvando = false;

  /// Envelopes sem valor planejado: escolher um para dar valor, ou criar um novo.
  Future<void> _adicionar(List<Map<String, dynamic>> inativos) async {
    final escolha = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
          const TopoSheet(titulo: 'Adicionar envelope', subtitulo: 'Envelopes sem valor planejado neste mês.'),
          const SizedBox(height: 8),
          for (final e in inativos)
            ListTile(
              leading: Text(e['emoji'] as String? ?? '📦', style: const TextStyle(fontSize: 22)),
              title: Text(e['nome_envelope'] as String? ?? ''),
              onTap: () => Navigator.pop(ctx, e['id'] as String),
            ),
          ListTile(
            leading: const Icon(Icons.add_rounded, color: NBColors.verde),
            title: const Text('Criar envelope novo', style: TextStyle(color: NBColors.verde)),
            onTap: () => Navigator.pop(ctx, '_novo'),
          ),
        ]),
      ),
    );
    if (escolha == null || !mounted) return;
    if (escolha == '_novo') {
      await abrirSheet(context, const SheetEnvelope());
    } else {
      setState(() => _ativados.add(escolha));
    }
  }

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
    final todos = ref.watch(envelopesViseisProvider).where((e) => e['is_reserva'] != true && !ehEnvelopeVa(e)).toList();
    for (final env in todos) {
      _ctrl(env); // cria os campos antes de somar, senão o 1º frame mostra total zero
    }
    bool ativo(Map<String, dynamic> e) => (_original[e['id']] ?? 0) > 0 || _ativados.contains(e['id']);
    final envelopes = todos.where(ativo).toList();
    final inativos = todos.where((e) => !ativo(e)).toList();
    final total = envelopes.fold(0.0, (s, e) => s + parseMoeda(_ctrl(e).text));
    final limite = ref.watch(limiteMesProvider).valueOrNull;
    final medias = mediaUltimosMeses(
      ref.watch(transacoesStreamProvider).valueOrNull ?? const [],
      ref.watch(mesAtualProvider),
    );

    final filhos = <Widget>[
      if (limite != null) TopoOrcamento(limite: limite, totalOrcado: total),
      const SizedBox(height: NBSpacing.l),
      Row(children: [
        Expanded(child: Text('ENVELOPES ATIVOS', style: NBText.eyebrow)),
        Text(brl(total), style: NBText.secao),
      ]),
      const SizedBox(height: NBSpacing.s),
      for (final env in envelopes)
        Padding(
          padding: const EdgeInsets.only(bottom: NBSpacing.s),
          child: Row(
            children: [
              Text(env['emoji'] as String? ?? '📦', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: NBSpacing.s),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(env['nome_envelope'] as String? ?? '', style: NBText.corpo, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if ((medias[env['id']] ?? 0) > 0)
                    Text('Média 3 meses: ${brl(medias[env['id']]!)}', style: NBText.legenda.copyWith(fontSize: 12)),
                ]),
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
      if (inativos.isNotEmpty || todos.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: NBSpacing.m),
          child: OutlinedButton.icon(
            onPressed: () => _adicionar(inativos),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar outro envelope'),
          ),
        ),
      if (limite != null && limite.limiteVa > 0)
        CartaoNB(
          child: Row(children: [
            const Text('💳', style: TextStyle(fontSize: 22)),
            const SizedBox(width: NBSpacing.s),
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
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 4, NBSpacing.margemTela, NBSpacing.xl),
          children: filhos,
        ),
      ),
      // Salvar só aparece quando algum envelope mudou.
      if (_mudados.isNotEmpty || _salvando)
        Container(
          padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.m, NBSpacing.margemTela, NBSpacing.m),
          decoration: const BoxDecoration(color: NBColors.cartao, border: Border(top: BorderSide(color: NBColors.linha))),
          child: botao,
        ),
    ]);
  }
}

/// Folha do botão "Orçamento" da Início.
class SheetPlanejarMes extends StatelessWidget {
  const SheetPlanejarMes({super.key});

  @override
  Widget build(BuildContext context) => const OrcamentoMensal(emFolha: true);
}

/// Média gasta por envelope nos 3 meses anteriores a [mes] (só despesas).
Map<String, double> mediaUltimosMeses(List<Map<String, dynamic>> transacoes, String mes) {
  final meses = {for (var k = 1; k <= 3; k++) somarMeses(mes, -k)};
  final soma = <String, double>{};
  for (final t in transacoes) {
    if (t['deleted_at'] != null || t['tipo'] != 'despesa' || t['envelope_id'] == null) continue;
    final d = t['data']?.toString() ?? '';
    if (d.length < 7 || !meses.contains(d.substring(0, 7))) continue;
    final id = t['envelope_id'] as String;
    soma[id] = (soma[id] ?? 0) + ((t['valor'] as num?)?.toDouble() ?? 0);
  }
  return {for (final e in soma.entries) e.key: e.value / 3};
}
