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

/// Move dinheiro do saldo geral para um envelope (POST /abastecer).
class SheetAbastecer extends ConsumerStatefulWidget {
  const SheetAbastecer({super.key, this.envelopeId});
  final String? envelopeId;

  @override
  ConsumerState<SheetAbastecer> createState() => _SheetAbastecerState();
}

class _SheetAbastecerState extends ConsumerState<SheetAbastecer> {
  late String? _envelopeId = widget.envelopeId;
  final _valor = TextEditingController();
  bool _salvando = false;
  bool _trocando = false;

  static final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: '', decimalDigits: 2);

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  double get _v => parseMoeda(_valor.text);

  void _definir(double v) {
    _valor.text = _fmt.format(v).trim();
    setState(() {});
  }

  Future<void> _salvar(Map<String, dynamic> env, double saldoGeral) async {
    if (_v <= 0) return avisar('Digite um valor maior que zero.', erro: true);
    if (_v > saldoGeral + 0.01) {
      return avisar('O saldo geral tem ${brl(saldoGeral)}. Abasteça até esse valor.', erro: true);
    }
    setState(() => _salvando = true);
    try {
      final p = perfilOuErro(ref);
      await ApiService.post('/abastecer/', {
        'envelope_id': env['id'],
        'valor': _v,
        'usuario_id': p['id'],
        'familia_id': p['familia_id'],
      });
      HapticFeedback.mediumImpact();
      final e = EstadoEnvelope(env);
      if (e.estourado && e.saldo + _v >= 0) {
        ref.sweet('${e.nome} saiu do vermelho!', mood: UnicornMood.celebrate);
      }
      avisar('${e.nome} abastecido com ${brl(_v)}');
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
    final saldoGeral = ref.watch(saldoGeralProvider).value ?? 0;
    _envelopeId ??= envelopes.isEmpty ? null : envelopes.first['id'] as String;
    final env = envelopes.where((e) => e['id'] == _envelopeId).firstOrNull;
    final estado = env == null ? null : EstadoEnvelope(env);
    final faltaPlano = estado == null ? 0.0 : (estado.planejado - estado.saldo);

    return CascaSheet(
      filhos: [
        const TopoSheet(titulo: 'Abastecer envelope'),
        const SizedBox(height: NBSpacing.l),
        CartaoNB(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _LinhaOrigem(rotulo: 'Sai do', nome: 'Saldo geral', valor: saldoGeral),
              const Divider(),
              _LinhaOrigem(
                rotulo: 'Entra no envelope',
                nome: estado?.nome ?? 'Escolha um envelope',
                valor: estado?.saldo,
                acao: TextButton(
                  onPressed: () => setState(() => _trocando = !_trocando),
                  child: Text(_trocando ? 'Pronto' : 'Trocar'),
                ),
              ),
            ],
          ),
        ),
        if (_trocando) ...[
          const SizedBox(height: NBSpacing.m),
          SeletorEnvelope(
            envelopes: envelopes,
            selecionadoId: _envelopeId,
            onSelect: (id) => setState(() {
              _envelopeId = id;
              _trocando = false;
            }),
          ),
        ],
        const SizedBox(height: NBSpacing.xl),
        CampoValor(controller: _valor, rotulo: 'Quanto abastecer', autofocus: true, onChanged: (_) => setState(() {})),
        const SizedBox(height: NBSpacing.m),
        Wrap(
          spacing: NBSpacing.s,
          runSpacing: NBSpacing.s,
          children: [
            ChipNB(rotulo: '+R\$ 100', selecionado: false, onTap: () => _definir(_v + 100)),
            ChipNB(rotulo: '+R\$ 300', selecionado: false, onTap: () => _definir(_v + 300)),
            if (faltaPlano > 0)
              ChipNB(rotulo: 'Completar plano', selecionado: false, onTap: () => _definir(faltaPlano)),
          ],
        ),
        if (estado != null) ...[
          const SizedBox(height: NBSpacing.l),
          LinhaPrevia(rotulo: 'Saldo geral fica', valor: saldoGeral - _v),
          LinhaPrevia(rotulo: '${estado.nome} fica', valor: estado.saldo + _v, corValor: NBColors.verde),
        ],
      ],
      botao: BotaoPrincipal(
        rotulo: estado == null ? 'Abastecer' : 'Abastecer ${estado.nome}',
        carregando: _salvando,
        onPressed: env == null ? null : () => _salvar(env, saldoGeral),
      ),
    );
  }
}

class _LinhaOrigem extends StatelessWidget {
  const _LinhaOrigem({required this.rotulo, required this.nome, this.valor, this.acao});
  final String rotulo;
  final String nome;
  final double? valor;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(NBSpacing.l, NBSpacing.m, NBSpacing.s, NBSpacing.m),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rotulo, style: NBText.legenda),
                Text(nome, style: NBText.rotulo.copyWith(fontSize: 15)),
              ],
            ),
          ),
          if (valor != null)
            Text(brl(valor!), style: NBText.corpo.copyWith(fontWeight: FontWeight.w700, color: valor! < 0 ? NBColors.estouro : NBColors.tinta)),
          if (acao != null) acao! else const SizedBox(width: NBSpacing.s),
        ],
      ),
    );
  }
}
