import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/envelopes_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/moeda.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';
import 'comum.dart';
import 'sheet_abastecer.dart';

enum TipoLancamento { gasto, receita }

Future<void> abrirLancamento(BuildContext context,
        {TipoLancamento tipo = TipoLancamento.gasto, String? envelopeId}) =>
    abrirSheet(context, SheetLancamento(tipoInicial: tipo, envelopeInicial: envelopeId));

class SheetLancamento extends ConsumerStatefulWidget {
  const SheetLancamento({super.key, this.tipoInicial = TipoLancamento.gasto, this.envelopeInicial});
  final TipoLancamento tipoInicial;
  final String? envelopeInicial;

  @override
  ConsumerState<SheetLancamento> createState() => _SheetLancamentoState();
}

class _SheetLancamentoState extends ConsumerState<SheetLancamento> {
  late TipoLancamento _tipo = widget.tipoInicial;
  late String? _envelopeId = widget.envelopeInicial;
  final _valor = TextEditingController();
  final _descricao = TextEditingController();
  String _forma = 'pix';
  bool _salvando = false;

  static const _formas = {'pix': 'Pix', 'credito': 'Crédito', 'debito': 'Débito', 'dinheiro': 'Dinheiro'};

  @override
  void dispose() {
    _valor.dispose();
    _descricao.dispose();
    super.dispose();
  }

  double get _v => parseMoeda(_valor.text);

  Future<void> _lancarGasto(Map<String, dynamic> env) async {
    final p = perfilOuErro(ref);
    final antes = EstadoEnvelope(env);
    await ApiService.post('/transacoes/', {
      'valor': _v,
      'tipo': 'despesa',
      'envelope_id': _envelopeId,
      'usuario_id': p['id'],
      'familia_id': p['familia_id'],
      'descricao': _descricao.text.trim().isEmpty ? null : _descricao.text.trim(),
      'forma_pagamento': _forma,
    });
    final depois = antes.saldo - _v;
    if (depois < 0 && antes.natureza == NaturezaEnvelope.consumo) {
      ref.geronimo('${antes.nome} estourou em ${brl(-depois)}. Dá pra cobrir remanejando de outro envelope.');
    }
    avisar('${brl(_v)} lançado em ${antes.nome}');
  }

  Future<bool> _lancarReceita() async {
    final p = perfilOuErro(ref);
    await ApiService.post('/transacoes/receita', {
      'valor': _v,
      'usuario_id': p['id'],
      'familia_id': p['familia_id'],
      'descricao': _descricao.text.trim().isEmpty ? 'Receita' : _descricao.text.trim(),
    });
    ref.astrix('Entrou ${brl(_v)} no saldo geral. Agora é distribuir nos envelopes.', mood: UnicornMood.celebrate);
    return true;
  }

  Future<void> _salvar({bool abastecerDepois = false}) async {
    if (_v <= 0) return avisar('Digite um valor maior que zero.', erro: true);
    final envelopes = ref.read(envelopesViseisProvider);
    Map<String, dynamic>? env;
    if (_tipo == TipoLancamento.gasto) {
      env = envelopes.where((e) => e['id'] == _envelopeId).firstOrNull;
      if (env == null) return avisar('Escolha de qual envelope sai o gasto.', erro: true);
    }
    final nav = Navigator.of(context);
    setState(() => _salvando = true);
    try {
      if (_tipo == TipoLancamento.gasto) {
        await _lancarGasto(env!);
      } else {
        await _lancarReceita();
      }
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      nav.pop(true);
      if (abastecerDepois && nav.mounted) abrirSheet(nav.context, const SheetAbastecer());
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final envelopes = ref.watch(envelopesViseisProvider);
    final gasto = _tipo == TipoLancamento.gasto;
    final env = envelopes.where((e) => e['id'] == _envelopeId).firstOrNull;
    final estado = env == null ? null : EstadoEnvelope(env);

    return CascaSheet(
      filhos: [
        const TopoSheet(titulo: 'Novo lançamento'),
        const SizedBox(height: NBSpacing.l),
        Segmentado<TipoLancamento>(
          opcoes: const {TipoLancamento.gasto: 'Gasto', TipoLancamento.receita: 'Receita'},
          valor: _tipo,
          onChanged: (t) => setState(() => _tipo = t),
        ),
        const SizedBox(height: NBSpacing.xl),
        CampoValor(
          controller: _valor,
          autofocus: true,
          rotulo: gasto ? 'Valor' : 'Valor recebido',
          prefixo: gasto ? 'R\$' : '+R\$',
          corValor: gasto ? NBColors.tinta : NBColors.verde,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: NBSpacing.l),
        if (gasto) ...[
          const Rotulo('De qual envelope?'),
          SeletorEnvelope(
            envelopes: envelopes,
            selecionadoId: _envelopeId,
            onSelect: (id) => setState(() => _envelopeId = id),
          ),
          if (estado != null && _v > 0) ...[
            const SizedBox(height: NBSpacing.s),
            Text(
              estado.saldo - _v < 0
                  ? '${estado.nome} fica com ${brl(estado.saldo - _v)} e estoura'
                  : '${estado.nome} fica com ${brl(estado.saldo - _v)}',
              style: NBText.rotulo.copyWith(
                color: estado.saldo - _v < 0 ? NBColors.estouro : NBColors.verde,
              ),
            ),
          ],
        ] else
          Container(
            padding: const EdgeInsets.all(NBSpacing.m),
            decoration: BoxDecoration(color: NBColors.verdeClaro, borderRadius: BorderRadius.circular(NBRadius.campo)),
            child: Text(
              'Receita entra no saldo geral, não em um envelope. Depois você distribui com Abastecer.',
              style: NBText.corpo.copyWith(fontSize: 14, color: NBColors.verdeProfundo),
            ),
          ),
        const SizedBox(height: NBSpacing.l),
        TextField(
          controller: _descricao,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: gasto ? 'Descrição (ex.: iFood)' : 'Descrição (ex.: Salário)'),
        ),
        if (gasto) ...[
          const SizedBox(height: NBSpacing.l),
          const Rotulo('Forma de pagamento'),
          Wrap(
            spacing: NBSpacing.s,
            runSpacing: NBSpacing.s,
            children: [
              for (final f in _formas.entries)
                ChipNB(rotulo: f.value, selecionado: _forma == f.key, onTap: () => setState(() => _forma = f.key)),
            ],
          ),
        ],
      ],
      botao: gasto
          ? BotaoPrincipal(
              rotulo: estado == null || _v <= 0 ? 'Lançar gasto' : 'Lançar ${brl(_v)} em ${estado.nome}',
              carregando: _salvando,
              onPressed: _salvar,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BotaoPrincipal(
                  rotulo: 'Lançar e abastecer envelopes',
                  carregando: _salvando,
                  onPressed: () => _salvar(abastecerDepois: true),
                ),
                const SizedBox(height: NBSpacing.s),
                OutlinedButton(
                  onPressed: _salvando ? null : _salvar,
                  child: const Text('Só lançar no saldo geral'),
                ),
              ],
            ),
    );
  }
}
