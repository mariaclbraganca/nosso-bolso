import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/moeda.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';
import '../sheets/comum.dart';

/// Um cenário "e se": renda do mês e uma lista de gastos hipotéticos.
class SimulacaoGastos {
  const SimulacaoGastos({required this.nome, this.receita = 0, this.itens = const []});
  final String nome;
  final double receita;
  final List<({String nome, double valor})> itens;

  double get total => itens.fold(0.0, (s, i) => s + i.valor);
  double get sobra => receita - total;

  SimulacaoGastos copyWith({String? nome, double? receita, List<({String nome, double valor})>? itens}) =>
      SimulacaoGastos(nome: nome ?? this.nome, receita: receita ?? this.receita, itens: itens ?? this.itens);

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'receita': receita,
        'itens': [for (final i in itens) {'nome': i.nome, 'valor': i.valor}],
      };

  factory SimulacaoGastos.fromJson(Map<String, dynamic> j) => SimulacaoGastos(
        nome: j['nome'] as String? ?? 'Simulação',
        receita: (j['receita'] as num?)?.toDouble() ?? 0,
        itens: [
          for (final i in (j['itens'] as List? ?? const []))
            (nome: (i as Map)['nome'] as String? ?? '', valor: (i['valor'] as num?)?.toDouble() ?? 0),
        ],
      );
}

/// Mesmo formato e chave da v2 (simulacoes_gastos_v1), só no aparelho.
class SimulacoesStore {
  static const chave = 'simulacoes_gastos_v1';

  static Future<List<SimulacaoGastos>> carregar() async {
    final raw = (await SharedPreferences.getInstance()).getString(chave);
    if (raw == null) return [];
    try {
      return [for (final j in jsonDecode(raw) as List) SimulacaoGastos.fromJson((j as Map).cast<String, dynamic>())];
    } catch (_) {
      return [];
    }
  }

  static Future<void> salvar(List<SimulacaoGastos> lista) async =>
      (await SharedPreferences.getInstance()).setString(chave, jsonEncode([for (final s in lista) s.toJson()]));
}

class SimuladorGastosScreen extends StatefulWidget {
  const SimuladorGastosScreen({super.key});

  @override
  State<SimuladorGastosScreen> createState() => _SimuladorGastosScreenState();
}

class _SimuladorGastosScreenState extends State<SimuladorGastosScreen> {
  List<SimulacaoGastos>? _lista;

  @override
  void initState() {
    super.initState();
    SimulacoesStore.carregar().then((l) {
      if (mounted) setState(() => _lista = l);
    });
  }

  Future<void> _gravar(List<SimulacaoGastos> l) async {
    setState(() => _lista = l);
    await SimulacoesStore.salvar(l);
  }

  Future<void> _nova() async {
    final nome = await pedirTexto(context, titulo: 'Nome da simulação', dica: 'Ex: Mudar de apartamento');
    if (nome == null || nome.isEmpty) return;
    final l = [..._lista!, SimulacaoGastos(nome: nome)];
    await _gravar(l);
    if (mounted) _abrir(l.length - 1);
  }

  Future<void> _abrir(int i) async {
    final atualizada = await Navigator.of(context).push<SimulacaoGastos>(
      MaterialPageRoute(builder: (_) => DetalheSimulacaoScreen(simulacao: _lista![i])),
    );
    if (atualizada != null) await _gravar([..._lista!]..[i] = atualizada);
  }

  @override
  Widget build(BuildContext context) {
    final l = _lista;
    return Scaffold(
      appBar: AppBar(title: const Text('Simulador de gastos')),
      floatingActionButton: l == null
          ? null
          : FloatingActionButton.extended(onPressed: _nova, icon: const Icon(Icons.add), label: const Text('Nova simulação')),
      body: l == null
          ? const SizedBox.shrink()
          : l.isEmpty
              ? UnicornVazio(
                  titulo: 'E se…?',
                  texto: 'Monte cenários antes de decidir: um aluguel novo, um carro, um filho. Fica só neste celular.',
                  acao: _nova,
                  rotuloAcao: 'Criar simulação',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, 96),
                  children: [
                    for (var i = 0; i < l.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: NBSpacing.s),
                        child: Dismissible(
                          key: ValueKey('${l[i].nome}-$i'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete_outline, color: NBColors.estouro),
                          ),
                          onDismissed: (_) => _gravar([...l]..removeAt(i)),
                          child: CartaoNB(
                            onTap: () => _abrir(i),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(l[i].nome, style: NBText.rotulo),
                                      Text('${l[i].itens.length} gasto(s)', style: NBText.legenda),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(brl(l[i].total), style: NBText.valorCartao),
                                    Text('por mês', style: NBText.legenda),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class DetalheSimulacaoScreen extends StatefulWidget {
  const DetalheSimulacaoScreen({super.key, required this.simulacao});
  final SimulacaoGastos simulacao;

  @override
  State<DetalheSimulacaoScreen> createState() => _DetalheSimulacaoScreenState();
}

class _DetalheSimulacaoScreenState extends State<DetalheSimulacaoScreen> {
  late SimulacaoGastos _s = widget.simulacao;

  Future<void> _item([int? i]) async {
    final atual = i == null ? null : _s.itens[i];
    final nome = TextEditingController(text: atual?.nome);
    final valor = TextEditingController(text: atual == null ? '' : atual.valor.toStringAsFixed(2).replaceAll('.', ','));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i == null ? 'Novo gasto' : 'Editar gasto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nome, autofocus: true, decoration: const InputDecoration(labelText: 'O quê')),
            const SizedBox(height: 12),
            TextField(
              controller: valor,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quanto por mês', prefixText: 'R\$ '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );
    final v = parseMoeda(valor.text);
    if (ok != true || nome.text.trim().isEmpty || v <= 0) return;
    final itens = [..._s.itens];
    final novo = (nome: nome.text.trim(), valor: v);
    i == null ? itens.add(novo) : itens[i] = novo;
    setState(() => _s = _s.copyWith(itens: itens));
  }

  Future<void> _renda() async {
    final ctrl = TextEditingController(text: _s.receita > 0 ? _s.receita.toStringAsFixed(2).replaceAll('.', ',') : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renda mensal'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: 'R\$ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok == true) setState(() => _s = _s.copyWith(receita: parseMoeda(ctrl.text)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (pop, _) {
        if (!pop) Navigator.of(context).pop(_s);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_s.nome)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
          children: [
            CartaoNB(
              child: Column(
                children: [
                  InkWell(
                    onTap: _renda,
                    child: Row(
                      children: [
                        Expanded(child: Text('Renda mensal', style: NBText.corpo)),
                        Text(_s.receita > 0 ? brl(_s.receita) : 'Informar', style: NBText.rotulo.copyWith(color: NBColors.verde)),
                        const Icon(Icons.edit_outlined, size: 16, color: NBColors.tintaSuave),
                      ],
                    ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(child: Text('Total de gastos', style: NBText.corpo)),
                      Text(brl(_s.total), style: NBText.rotulo),
                    ],
                  ),
                  if (_s.receita > 0) ...[
                    const SizedBox(height: NBSpacing.s),
                    Row(
                      children: [
                        Expanded(child: Text(_s.sobra >= 0 ? 'Sobra' : 'Falta', style: NBText.rotulo)),
                        Text(brl(_s.sobra.abs()),
                            style: NBText.valorCartao.copyWith(color: _s.sobra >= 0 ? NBColors.verde : NBColors.estouro)),
                      ],
                    ),
                    const SizedBox(height: NBSpacing.s),
                    BarraProgresso(fracao: _s.total / _s.receita, cor: _s.sobra >= 0 ? NBColors.verde : NBColors.estouro),
                  ],
                ],
              ),
            ),
            const SizedBox(height: NBSpacing.l),
            for (var i = 0; i < _s.itens.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_s.itens[i].nome, style: NBText.corpo),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(brl(_s.itens[i].valor), style: NBText.rotulo),
                    IconButton(
                      tooltip: 'Remover',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _s = _s.copyWith(itens: [..._s.itens]..removeAt(i))),
                    ),
                  ],
                ),
                onTap: () => _item(i),
              ),
            const SizedBox(height: NBSpacing.s),
            BotaoSecundario(rotulo: '+ Adicionar gasto', onPressed: () => _item()),
          ],
        ),
      ),
    );
  }
}

Future<String?> pedirTexto(BuildContext context, {required String titulo, String? dica}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: dica)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Criar')),
      ],
    ),
  );
}
