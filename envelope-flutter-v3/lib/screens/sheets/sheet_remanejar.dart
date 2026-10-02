import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/envelopes_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/moeda.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';
import 'comum.dart';

/// Transfere de um envelope direto para outro (POST /remanejar, RPC atômica).
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

  Future<void> _salvar(EstadoEnvelope origem, EstadoEnvelope destino) async {
    if (_v <= 0) return avisar('Digite um valor maior que zero.', erro: true);
    if (_v > origem.saldo + 0.01) {
      return avisar('${origem.nome} tem ${brl(origem.saldo)}. Remaneje até esse valor.', erro: true);
    }
    setState(() => _salvando = true);
    try {
      final p = perfilOuErro(ref);
      await ApiService.post('/remanejar/', {
        'origem_id': _origemId,
        'destino_id': _destinoId,
        'valor': _v,
        'familia_id': p['familia_id'],
        'usuario_id': p['id'],
      });
      HapticFeedback.mediumImpact();
      if (destino.estourado && destino.saldo + _v >= 0) {
        ref.sweet('${destino.nome} voltou para o azul. Boa!', mood: UnicornMood.celebrate);
      }
      avisar('${brl(_v)} de ${origem.nome} para ${destino.nome}');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final envelopes = ref.watch(envelopesViseisProvider);
    Map<String, dynamic>? achar(String? id) => envelopes.where((e) => e['id'] == id).firstOrNull;
    final o = achar(_origemId);
    final d = achar(_destinoId);
    final origem = o == null ? null : EstadoEnvelope(o);
    final destino = d == null ? null : EstadoEnvelope(d);

    return CascaSheet(
      filhos: [
        const TopoSheet(
          titulo: 'Remanejar',
          subtitulo: 'De um envelope direto para outro, sem passar pelo saldo geral.',
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
        if (destino != null && destino.estourado) ...[
          const SizedBox(height: NBSpacing.m),
          Align(
            alignment: Alignment.centerLeft,
            child: ChipNB(
              rotulo: 'Só cobrir o estouro · ${brl(-destino.saldo)}',
              selecionado: false,
              onTap: () => setState(() => _valor.text = _fmt.format(-destino.saldo).trim()),
            ),
          ),
        ],
        if (origem != null && destino != null) ...[
          const SizedBox(height: NBSpacing.l),
          LinhaPrevia(rotulo: '${origem.nome} fica', valor: origem.saldo - _v),
          LinhaPrevia(rotulo: '${destino.nome} fica', valor: destino.saldo + _v, corValor: NBColors.verde),
        ],
      ],
      botao: BotaoPrincipal(
        rotulo: _v > 0 ? 'Remanejar ${brl(_v)}' : 'Remanejar',
        carregando: _salvando,
        onPressed: origem == null || destino == null ? null : () => _salvar(origem, destino),
      ),
    );
  }
}
