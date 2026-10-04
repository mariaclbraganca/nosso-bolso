import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/envelopes_provider.dart';
import '../../core/providers/plano_provider.dart';
import '../../core/providers/transacoes_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/moeda.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import 'comum.dart';

/// Transfere orçamento de um envelope para outro no mês: o total orçado não
/// muda, só a divisão (ex.: tirar R$ 50 de Lazer para cobrir o Mercado).
class SheetRemanejar extends ConsumerStatefulWidget {
  const SheetRemanejar({super.key, this.origemId, this.destinoId});
  final String? origemId;
  final String? destinoId;

  @override
  ConsumerState<SheetRemanejar> createState() => _SheetRemanejarState();
}

class _SheetRemanejarState extends ConsumerState<SheetRemanejar> {
  late String? _origemId = widget.origemId;
  late String? _destinoId = widget.destinoId;
  final _valor = TextEditingController();
  bool _salvando = false;

  static final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: '', decimalDigits: 2);

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  double get _v => parseMoeda(_valor.text);

  Future<void> _salvar(Map<String, dynamic> origem, Map<String, dynamic> destino, double dispOrigem) async {
    if (_v <= 0) return avisar('Informe um valor maior que zero.', erro: true);
    if (_v > dispOrigem + 0.01) {
      return avisar('${origem['nome_envelope']} tem ${brl(dispOrigem)} disponível. Transfira até esse valor.', erro: true);
    }
    setState(() => _salvando = true);
    try {
      final p = perfilOuErro(ref);
      double orc(Map<String, dynamic> e) => (e['valor_planejado'] as num?)?.toDouble() ?? 0;
      await ApiService.put('/envelopes/${origem['id']}?familia_id=${p['familia_id']}', {'valor_planejado': orc(origem) - _v});
      await ApiService.put('/envelopes/${destino['id']}?familia_id=${p['familia_id']}', {'valor_planejado': orc(destino) + _v});
      ref.invalidate(envelopesProvider);
      HapticFeedback.mediumImpact();
      avisar('${brl(_v)} de orçamento: ${origem['nome_envelope']} → ${destino['nome_envelope']}');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final envelopes = ref.watch(envelopesViseisProvider).where((e) => e['is_reserva'] != true && !ehEnvelopeVa(e)).toList();
    final gastos = ref.watch(gastosPorEnvelopeNoMesProvider);
    double disp(Map<String, dynamic> e) => ((e['valor_planejado'] as num?)?.toDouble() ?? 0) - (gastos[e['id']] ?? 0);
    Map<String, dynamic>? achar(String? id) => envelopes.where((e) => e['id'] == id).firstOrNull;
    final o = achar(_origemId);
    final d = achar(_destinoId);

    return CascaSheet(
      filhos: [
        const TopoSheet(
          titulo: 'Transferir orçamento',
          subtitulo: 'Move parte do orçamento de um envelope para outro. O total orçado do mês não muda.',
        ),
        const SizedBox(height: NBSpacing.xl),
        const Rotulo('De'),
        SeletorEnvelope(
          envelopes: envelopes,
          selecionadoId: _origemId,
          excluirId: _destinoId,
          onSelect: (id) => setState(() => _origemId = id),
        ),
        const SizedBox(height: NBSpacing.l),
        const Rotulo('Para'),
        SeletorEnvelope(
          envelopes: envelopes,
          selecionadoId: _destinoId,
          excluirId: _origemId,
          onSelect: (id) => setState(() => _destinoId = id),
        ),
        const SizedBox(height: NBSpacing.xl),
        CampoValor(controller: _valor, onChanged: (_) => setState(() {})),
        if (d != null && disp(d) < 0) ...[
          const SizedBox(height: NBSpacing.m),
          Align(
            alignment: Alignment.centerLeft,
            child: ChipNB(
              rotulo: 'Cobrir o excesso · ${brl(-disp(d))}',
              selecionado: false,
              onTap: () => setState(() => _valor.text = _fmt.format(-disp(d)).trim()),
            ),
          ),
        ],
        if (o != null && d != null) ...[
          const SizedBox(height: NBSpacing.l),
          LinhaPrevia(rotulo: '${o['nome_envelope']}: disponível fica', valor: disp(o) - _v),
          LinhaPrevia(rotulo: '${d['nome_envelope']}: disponível fica', valor: disp(d) + _v, corValor: NBColors.verde),
        ],
      ],
      botao: BotaoPrincipal(
        rotulo: _v > 0 ? 'Transferir ${brl(_v)}' : 'Transferir',
        carregando: _salvando,
        onPressed: o == null || d == null ? null : () => _salvar(o, d, disp(o)),
      ),
    );
  }
}
