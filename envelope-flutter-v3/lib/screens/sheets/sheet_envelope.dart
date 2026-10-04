import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/envelopes_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/moeda.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import 'comum.dart';
import 'sheet_remanejar.dart';

const _emojis = ['📦', '🛒', '🏠', '🚗', '⛽', '💊', '🍔', '🎮', '💡', '🧼', '🎓', '✈️', '🐕', '🎵', '💄', '🏋️', '🎁', '💰'];

Future<void> abrirEnvelope(BuildContext context, {Map<String, dynamic>? envelope}) =>
    abrirSheet(context, SheetEnvelope(envelope: envelope));

/// Criar (envelope == null) ou editar/excluir um envelope.
class SheetEnvelope extends ConsumerStatefulWidget {
  const SheetEnvelope({super.key, this.envelope});
  final Map<String, dynamic>? envelope;

  @override
  ConsumerState<SheetEnvelope> createState() => _SheetEnvelopeState();
}

class _SheetEnvelopeState extends ConsumerState<SheetEnvelope> {
  static final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: '', decimalDigits: 2);
  final _nome = TextEditingController();
  final _planejado = TextEditingController();
  final _objetivo = TextEditingController();
  String _emoji = '📦';
  NaturezaEnvelope _natureza = NaturezaEnvelope.consumo;
  bool _salvando = false;

  bool get _editando => widget.envelope != null;

  @override
  void initState() {
    super.initState();
    final e = widget.envelope;
    if (e != null) {
      _nome.text = e['nome_envelope'] as String? ?? '';
      _emoji = e['emoji'] as String? ?? '📦';
      _natureza = NaturezaEnvelope.from(e);
      final plan = (e['valor_planejado'] as num?)?.toDouble() ?? 0;
      final obj = (e['valor_objetivo'] as num?)?.toDouble() ?? 0;
      if (plan > 0) _planejado.text = _fmt.format(plan).trim();
      if (obj > 0) _objetivo.text = _fmt.format(obj).trim();
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _planejado.dispose();
    _objetivo.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    if (nome.isEmpty) return avisar('Dê um nome ao envelope.', erro: true);
    final planejado = parseMoeda(_planejado.text);
    final objetivo = parseMoeda(_objetivo.text);
    if (_natureza == NaturezaEnvelope.objetivo && objetivo <= 0) {
      return avisar('Informe quanto quer juntar neste objetivo.', erro: true);
    }
    setState(() => _salvando = true);
    try {
      final p = perfilOuErro(ref);
      final dados = {
        'nome_envelope': nome,
        'emoji': _emoji,
        'valor_planejado': planejado,
        'natureza': _natureza.name,
        'is_reserva': _natureza == NaturezaEnvelope.reserva,
        'valor_objetivo': _natureza == NaturezaEnvelope.consumo ? null : (objetivo > 0 ? objetivo : null),
      };
      if (_editando) {
        await ApiService.put('/envelopes/${widget.envelope!['id']}?familia_id=${p['familia_id']}', dados);
      } else {
        await ApiService.post('/envelopes/', {...dados, 'familia_id': p['familia_id']});
      }
      ref.invalidate(envelopesProvider);
      avisar(_editando ? 'Envelope "$nome" atualizado.' : 'Envelope "$nome" criado. Abasteça para começar a usar.');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluir() async {
    final env = widget.envelope!;
    final estado = EstadoEnvelope(env);
    final resposta = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NBColors.cartao,
        title: Text('Excluir ${estado.nome}?', style: NBText.secao),
        content: Text(
          estado.saldo != 0
              ? 'Ele ainda tem ${brl(estado.saldo)}. Esse valor fica preso no envelope arquivado. '
                  'Remaneje para outro envelope antes de excluir.'
              : 'Ele sai da lista. Os lançamentos antigos continuam no extrato.',
          style: NBText.corpo,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          if (estado.saldo > 0)
            TextButton(onPressed: () => Navigator.pop(ctx, 'remanejar'), child: const Text('Transferir orçamento')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'excluir'),
            child: const Text('Excluir', style: TextStyle(color: NBColors.estouro)),
          ),
        ],
      ),
    );
    if (!mounted || resposta == null) return;
    final nav = Navigator.of(context);
    if (resposta == 'remanejar') {
      nav.pop();
      abrirSheet(nav.context, SheetRemanejar(origemId: env['id'] as String));
      return;
    }
    try {
      final p = perfilOuErro(ref);
      await ApiService.delete('/envelopes/${env['id']}', familiaId: p['familia_id'] as String);
      ref.invalidate(envelopesProvider);
      avisar('${estado.nome} arquivado.');
      nav.pop(true);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final acumula = _natureza != NaturezaEnvelope.consumo;
    return CascaSheet(
      filhos: [
        TopoSheet(
          titulo: _editando ? 'Editar envelope' : 'Novo envelope',
          subtitulo: _editando ? null : 'Todo envelope nasce vazio. Depois você abastece com o saldo geral.',
        ),
        const SizedBox(height: NBSpacing.l),
        TextField(
          controller: _nome,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nome (ex.: Mercado)'),
        ),
        const SizedBox(height: NBSpacing.l),
        const Rotulo('Ícone'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in _emojis)
              InkWell(
                onTap: () => setState(() => _emoji = e),
                borderRadius: BorderRadius.circular(NBRadius.chip),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _emoji == e ? NBColors.verdeClaro : NBColors.afundado,
                    borderRadius: BorderRadius.circular(NBRadius.chip),
                    border: Border.all(color: _emoji == e ? NBColors.verde : Colors.transparent, width: 1.5),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 20)),
                ),
              ),
          ],
        ),
        const SizedBox(height: NBSpacing.l),
        const Rotulo('Tipo'),
        Segmentado<NaturezaEnvelope>(
          opcoes: const {
            NaturezaEnvelope.consumo: 'Consumo',
            NaturezaEnvelope.reserva: 'Reserva',
            NaturezaEnvelope.objetivo: 'Objetivo',
          },
          valor: _natureza,
          onChanged: (n) => setState(() => _natureza = n),
        ),
        const SizedBox(height: NBSpacing.s),
        Text(
          switch (_natureza) {
            NaturezaEnvelope.consumo => 'Despesas do mês. O orçamento recomeça a cada mês.',
            NaturezaEnvelope.reserva => 'Segurança da família. O saldo acumula de um mês para o outro.',
            NaturezaEnvelope.objetivo => 'Algo para juntar (viagem, compra). Acumula até a meta.',
          },
          style: NBText.legenda,
        ),
        const SizedBox(height: NBSpacing.l),
        CampoValor(
          controller: _planejado,
          rotulo: acumula ? 'Quanto guardar por mês' : 'Planejado por mês',
        ),
        if (acumula) ...[
          const SizedBox(height: NBSpacing.l),
          CampoValor(
            controller: _objetivo,
            rotulo: _natureza == NaturezaEnvelope.objetivo ? 'Meta total' : 'Meta total (opcional)',
          ),
        ],
        if (_editando) ...[
          const SizedBox(height: NBSpacing.l),
          TextButton.icon(
            onPressed: _salvando ? null : _excluir,
            icon: const Icon(Icons.archive_outlined, color: NBColors.estouro),
            label: const Text('Excluir envelope', style: TextStyle(color: NBColors.estouro)),
          ),
        ],
      ],
      botao: BotaoPrincipal(
        rotulo: _editando ? 'Salvar alterações' : 'Criar envelope',
        carregando: _salvando,
        onPressed: _salvar,
      ),
    );
  }
}
