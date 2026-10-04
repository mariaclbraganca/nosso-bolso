import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/plano/plano_mes.dart';
import '../../../core/providers/mes_provider.dart';
import '../../../core/providers/plano_provider.dart';
import '../../../core/providers/usuarios_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/moeda.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';
import '../../sheets/comum.dart';

String _valorTexto(num? v) => v == null || v == 0 ? '' : v.toStringAsFixed(2).replaceAll('.', ',');

/// Nova entrada prevista (salário, aluguel recebido, vale…) ou edição.
class SheetEntrada extends ConsumerStatefulWidget {
  const SheetEntrada({super.key, required this.mes, this.entrada});
  final String mes;
  final Map<String, dynamic>? entrada;

  @override
  ConsumerState<SheetEntrada> createState() => _SheetEntradaState();
}

class _SheetEntradaState extends ConsumerState<SheetEntrada> {
  late final _nome = TextEditingController(text: widget.entrada?['nome'] as String?);
  late final _valor = TextEditingController(text: _valorTexto(widget.entrada?['valor'] as num?));
  late final _recebido = TextEditingController(text: _valorTexto(widget.entrada?['valor_recebido'] as num?));
  late final _dia = TextEditingController(text: widget.entrada?['dia']?.toString() ?? '');
  late String _tipo = widget.entrada?['tipo'] as String? ?? 'dinheiro';
  late bool _recorrente = widget.entrada?['recorrente'] as bool? ?? true;
  bool _salvando = false;

  @override
  void dispose() {
    for (final c in [_nome, _valor, _recebido, _dia]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    final valor = parseMoeda(_valor.text);
    final dia = int.tryParse(_dia.text);
    if (nome.isEmpty || valor <= 0) return avisar('Informe a descrição e o valor.', erro: true);
    if (dia != null && (dia < 1 || dia > 31)) return avisar('Informe um dia entre 1 e 31.', erro: true);
    setState(() => _salvando = true);
    try {
      final dados = {'nome': nome, 'valor': valor, 'dia': dia, 'tipo': _tipo, 'recorrente': _recorrente};
      if (widget.entrada == null) {
        final fam = ref.read(perfilUsuarioLogadoProvider).valueOrNull?['familia_id'];
        await ApiService.post('/plano/entradas', {...dados, 'familia_id': fam, 'mes': widget.mes});
      } else {
        await ApiService.patch('/plano/entradas/${widget.entrada!['id']}', {
          ...dados,
          if (_recebido.text.trim().isNotEmpty) 'valor_recebido': parseMoeda(_recebido.text),
        });
      }
      ref.invalidate(entradasMesProvider(widget.mes));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluir() async {
    try {
      await ApiService.delete('/plano/entradas/${widget.entrada!['id']}');
      ref.invalidate(entradasMesProvider(widget.mes));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.entrada != null;
    return CascaSheet(
      filhos: [
        TopoSheet(
          titulo: editando ? 'Editar receita prevista' : 'Nova receita prevista',
          subtitulo: 'Competência: ${mesLabelLongo(widget.mes).toLowerCase()}',
        ),
        const SizedBox(height: NBSpacing.l),
        CampoValor(controller: _valor, rotulo: 'VALOR PREVISTO'),
        const SizedBox(height: NBSpacing.l),
        TextField(
          controller: _nome,
          decoration: const InputDecoration(labelText: 'DESCRIÇÃO', hintText: 'Ex.: Salário, Aluguel recebido, Vale-alimentação'),
        ),
        const SizedBox(height: NBSpacing.l),
        TextField(
          controller: _dia,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'DIA DO RECEBIMENTO (opcional)'),
        ),
        if (editando) ...[
          const SizedBox(height: NBSpacing.l),
          TextField(
            controller: _recebido,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'VALOR RECEBIDO (se diferente do previsto)', prefixText: 'R\$ '),
          ),
        ],
        const SizedBox(height: NBSpacing.l),
        Wrap(
          spacing: 8,
          children: [
            ChipNB(rotulo: 'Dinheiro', selecionado: _tipo == 'dinheiro', onTap: () => setState(() => _tipo = 'dinheiro')),
            ChipNB(rotulo: 'Vale (VA/VR)', selecionado: _tipo == 'vale', onTap: () => setState(() => _tipo = 'vale')),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _recorrente,
          onChanged: (v) => setState(() => _recorrente = v),
          title: Text('Recorrente (todo mês)', style: NBText.corpo),
        ),
        if (editando)
          TextButton(
            onPressed: _excluir,
            child: const Text('Excluir receita prevista', style: TextStyle(color: NBColors.estouro)),
          ),
      ],
      botao: BotaoPrincipal(rotulo: 'Salvar', carregando: _salvando, onPressed: _salvar),
    );
  }
}

/// Parcela ou assinatura do cartão, com a fatura em que cai a parcela atual.
class SheetCompromisso extends ConsumerStatefulWidget {
  const SheetCompromisso({super.key, required this.mesFatura});
  final String mesFatura;

  @override
  ConsumerState<SheetCompromisso> createState() => _SheetCompromissoState();
}

class _SheetCompromissoState extends ConsumerState<SheetCompromisso> {
  final _descricao = TextEditingController();
  final _valor = TextEditingController();
  final _atual = TextEditingController();
  final _total = TextEditingController();
  bool _assinatura = false;
  bool _salvando = false;

  @override
  void dispose() {
    for (final c in [_descricao, _valor, _atual, _total]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    final valor = parseMoeda(_valor.text);
    final atual = int.tryParse(_atual.text);
    final total = int.tryParse(_total.text);
    if (_descricao.text.trim().isEmpty || valor <= 0) return avisar('Informe a descrição e o valor.', erro: true);
    if (!_assinatura && (atual == null || total == null || atual < 1 || atual > total)) {
      return avisar('Informe a parcela. Ex.: 2 de 5.', erro: true);
    }
    setState(() => _salvando = true);
    try {
      await ApiService.post('/plano/cartao', {
        'familia_id': ref.read(perfilUsuarioLogadoProvider).valueOrNull?['familia_id'],
        'descricao': _descricao.text.trim(),
        'valor': valor,
        'mes_fatura': widget.mesFatura,
        if (!_assinatura) 'parcela_atual': atual,
        if (!_assinatura) 'total_parcelas': total,
      });
      ref.invalidate(compromissosCartaoProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CascaSheet(
      filhos: [
        TopoSheet(
          titulo: 'Novo lançamento futuro',
          subtitulo: 'Na fatura de ${mesLabelLongo(widget.mesFatura).toLowerCase()}',
        ),
        const SizedBox(height: NBSpacing.l),
        CampoValor(controller: _valor, rotulo: 'VALOR POR MÊS'),
        const SizedBox(height: NBSpacing.l),
        TextField(controller: _descricao, decoration: const InputDecoration(labelText: 'DESCRIÇÃO', hintText: 'Ex.: Clínica odontológica, Netflix')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _assinatura,
          onChanged: (v) => setState(() => _assinatura = v),
          title: Text('Assinatura (cobrança mensal recorrente)', style: NBText.corpo),
        ),
        if (!_assinatura)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _atual,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'PARCELA NESTA FATURA'),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('de')),
              Expanded(
                child: TextField(
                  controller: _total,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'TOTAL'),
                ),
              ),
            ],
          ),
      ],
      botao: BotaoPrincipal(rotulo: 'Salvar', carregando: _salvando, onPressed: _salvar),
    );
  }
}

/// Lista de parcelas e assinaturas ativas, com quantas faltam e o fim.
class CompromissosScreen extends StatelessWidget {
  const CompromissosScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Lançamentos futuros')),
        body: const ListaCompromissos(),
      );
}

/// Parcelas e assinaturas das próximas faturas (arrastar para remover).
class ListaCompromissos extends ConsumerWidget {
  const ListaCompromissos({super.key});

  Future<void> _remover(WidgetRef ref, Map<String, dynamic> c) async {
    try {
      await ApiService.delete('/plano/cartao/${c['id']}');
      ref.invalidate(compromissosCartaoProvider);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesFatura = somarMeses(ref.watch(mesAtualProvider), 1);
    return ref.watch(compromissosCartaoProvider).when(
            loading: () => const UnicornCarregando(),
            error: (e, _) => UnicornErro(mensagem: mensagemErro(e), onTentar: () => ref.invalidate(compromissosCartaoProvider)),
            data: (lista) {
              final ativos = [
                for (final c in lista)
                  if (itemNaFatura(c, mesFatura) != null || mesesEntre(mesFatura, c['mes_fatura'] as String) > 0) c,
              ];
              if (ativos.isEmpty) {
                return const UnicornVazio(titulo: 'Nenhum lançamento futuro', texto: 'Não há parcelas nem assinaturas nas próximas faturas.');
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
                children: [
                  for (final c in ativos)
                    Dismissible(
                      key: ValueKey(c['id']),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_outline, color: NBColors.estouro),
                      ),
                      onDismissed: (_) => _remover(ref, c),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c['descricao'] as String? ?? '', style: NBText.corpo),
                        subtitle: Text(_fimDoCompromisso(c), style: NBText.legenda),
                        trailing: Text(brl((c['valor'] as num?) ?? 0), style: NBText.rotulo),
                      ),
                    ),
                ],
              );
            },
          );
  }
}

/// "assinatura" ou "última parcela na fatura de março de 2027".
String _fimDoCompromisso(Map<String, dynamic> c) {
  final total = (c['total_parcelas'] as num?)?.toInt();
  if (total == null) return 'Assinatura · cobrança mensal';
  final atual = (c['parcela_atual'] as num).toInt();
  final ultima = somarMeses(c['mes_fatura'] as String, total - atual);
  return 'Última parcela na fatura de ${mesLabelLongo(ultima).toLowerCase()}';
}
