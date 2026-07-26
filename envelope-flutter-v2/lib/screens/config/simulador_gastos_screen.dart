import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../utils/moeda.dart';

/// Simulador de orçamento — 100% isolado, não toca em nenhum dado real
/// (saldo, envelopes, fixos, transações). Serve para planejar gastos de um
/// cenário futuro (ex: mudança de cidade). Cada simulação é uma lista livre de
/// itens (nome + valor) com total automático. Persiste localmente
/// (SharedPreferences) — permite salvar vários cenários e voltar depois.
class SimuladorGastosScreen extends StatefulWidget {
  const SimuladorGastosScreen({super.key});

  @override
  State<SimuladorGastosScreen> createState() => _SimuladorGastosScreenState();
}

class _SimuladorGastosScreenState extends State<SimuladorGastosScreen> {
  static const _storeKey = 'simulacoes_gastos_v1';

  List<_Simulacao> _simulacoes = [];
  bool _carregando = true;

  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storeKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        _simulacoes =
            list.map((e) => _Simulacao.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      _simulacoes = [];
    }
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _salvar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storeKey, jsonEncode(_simulacoes.map((s) => s.toJson()).toList()));
  }

  Future<void> _novaSimulacao() async {
    final nome = await _pedirNome();
    if (nome == null || nome.trim().isEmpty) return;
    setState(() => _simulacoes.add(_Simulacao(nome: nome.trim(), itens: [])));
    await _salvar();
    if (!mounted) return;
    _abrirSimulacao(_simulacoes.length - 1);
  }

  Future<String?> _pedirNome({String? inicial}) {
    final ctrl = TextEditingController(text: inicial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: const BorderSide(color: AppColors.bord, width: 0.5),
        ),
        title: Text(inicial == null ? 'Nova simulação' : 'Renomear',
            style: AppTextStyles.titleSm),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: 'Ex: Goiânia econômico',
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.mu),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.mu)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.acc,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text('Salvar',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.bg)),
          ),
        ],
      ),
    );
  }

  Future<void> _excluirSimulacao(int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: const BorderSide(color: AppColors.bord, width: 0.5),
        ),
        title: Text('Excluir simulação?', style: AppTextStyles.titleSm),
        content: Text('"${_simulacoes[i].nome}" será removida.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.mu)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: AppTextStyles.bodySm),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Excluir',
                style: AppTextStyles.bodySm.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _simulacoes.removeAt(i));
    await _salvar();
  }

  void _abrirSimulacao(int i) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DetalheSimulacaoScreen(
          simulacao: _simulacoes[i],
          onChanged: (nova) {
            setState(() => _simulacoes[i] = nova);
            _salvar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.mu, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Simulador de gastos', style: AppTextStyles.titleSm),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_nova_simulacao',
        backgroundColor: AppColors.acc,
        foregroundColor: AppColors.bg,
        onPressed: _novaSimulacao,
        icon: const Icon(Icons.add_rounded),
        label: Text('Nova simulação',
            style: AppTextStyles.bodySm.copyWith(
                color: AppColors.bg, fontWeight: FontWeight.bold)),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.acc))
          : _simulacoes.isEmpty
              ? _vazio()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePad, 12, AppSpacing.pagePad, 100),
                  itemCount: _simulacoes.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.cardGap),
                  itemBuilder: (context, i) {
                    final s = _simulacoes[i];
                    return _card(s, i);
                  },
                ),
    );
  }

  Widget _vazio() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔮', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text('Simule seus gastos',
                  style: AppTextStyles.title, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Monte um cenário de gastos (ex: mudança para outra cidade) '
                'e veja o total. Nada aqui afeta suas finanças reais.',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _card(_Simulacao s, int i) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      onTap: () => _abrirSimulacao(i),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.nome,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${s.itens.length} item(ns)',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_fmt.format(s.total),
                    style: AppTextStyles.mono.copyWith(
                        color: AppColors.acc, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('total/mês', style: AppTextStyles.caption),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.mu, size: 20),
              onPressed: () => _excluirSimulacao(i),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Detalhe de uma simulação (itens nome + valor) ────────────────────────────

class _DetalheSimulacaoScreen extends StatefulWidget {
  final _Simulacao simulacao;
  final ValueChanged<_Simulacao> onChanged;

  const _DetalheSimulacaoScreen(
      {required this.simulacao, required this.onChanged});

  @override
  State<_DetalheSimulacaoScreen> createState() =>
      _DetalheSimulacaoScreenState();
}

class _DetalheSimulacaoScreenState extends State<_DetalheSimulacaoScreen> {
  late _Simulacao _s;
  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _s = widget.simulacao;
  }

  void _persistir() => widget.onChanged(_s);

  Future<void> _adicionarItem() async {
    final item = await _editarItemDialog();
    if (item == null) return;
    setState(() => _s = _s.copyWith(itens: [..._s.itens, item]));
    _persistir();
  }

  Future<void> _editarItem(int idx) async {
    final item = await _editarItemDialog(inicial: _s.itens[idx]);
    if (item == null) return;
    final novos = [..._s.itens];
    novos[idx] = item;
    setState(() => _s = _s.copyWith(itens: novos));
    _persistir();
  }

  void _removerItem(int idx) {
    final novos = [..._s.itens]..removeAt(idx);
    setState(() => _s = _s.copyWith(itens: novos));
    _persistir();
  }

  Future<void> _editarReceita() async {
    final ctrl = TextEditingController(
        text: _s.receita > 0 ? _fmt.format(_s.receita) : '');
    final novo = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: const BorderSide(color: AppColors.bord, width: 0.5),
        ),
        title: Text('Renda mensal', style: AppTextStyles.titleSm),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppTextStyles.body,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,R$ ]')),
          ],
          decoration: InputDecoration(
            hintText: 'Ex: 5.000,00',
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.mu),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, parseMoeda(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.mu)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.acc,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, parseMoeda(ctrl.text)),
            child: Text('Salvar',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.bg)),
          ),
        ],
      ),
    );
    if (novo == null) return;
    setState(() => _s = _s.copyWith(receita: novo));
    _persistir();
  }

  Future<_ItemGasto?> _editarItemDialog({_ItemGasto? inicial}) {
    final nomeCtrl = TextEditingController(text: inicial?.nome);
    final valorCtrl = TextEditingController(
        text: inicial != null ? _fmt.format(inicial.valor) : '');
    return showDialog<_ItemGasto>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: const BorderSide(color: AppColors.bord, width: 0.5),
        ),
        title: Text(inicial == null ? 'Novo gasto' : 'Editar gasto',
            style: AppTextStyles.titleSm),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeCtrl,
              autofocus: true,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                labelText: 'Nome',
                hintText: 'Ex: Aluguel',
                labelStyle: AppTextStyles.caption,
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.mu),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valorCtrl,
              style: AppTextStyles.body,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,R$ ]')),
              ],
              decoration: InputDecoration(
                labelText: 'Valor mensal',
                hintText: 'Ex: 1.500,00',
                labelStyle: AppTextStyles.caption,
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.mu),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.mu)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.acc,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
              ),
            ),
            onPressed: () {
              final nome = nomeCtrl.text.trim();
              final valor = parseMoeda(valorCtrl.text);
              if (nome.isEmpty || valor <= 0) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx, _ItemGasto(nome: nome, valor: valor));
            },
            child: Text('Salvar',
                style: AppTextStyles.bodySm.copyWith(color: AppColors.bg)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.mu, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_s.nome, style: AppTextStyles.titleSm),
      ),
      body: Column(
        children: [
          Expanded(
            child: _s.itens.isEmpty
                ? Center(
                    child: Text('Nenhum gasto ainda.\nToque em "Adicionar gasto".',
                        textAlign: TextAlign.center,
                        style:
                            AppTextStyles.bodySm.copyWith(color: AppColors.mu)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pagePad, 12, AppSpacing.pagePad, 100),
                    itemCount: _s.itens.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final it = _s.itens[idx];
                      return Dismissible(
                        key: ValueKey('${it.nome}_${idx}_${it.valor}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.red.withOpacity(0.15),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusCard),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.red),
                        ),
                        onDismissed: (_) => _removerItem(idx),
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusCard),
                          onTap: () => _editarItem(idx),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusCard),
                              border: Border.all(
                                  color: AppColors.bord, width: 0.5),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(it.nome,
                                      style: AppTextStyles.body),
                                ),
                                Text(_fmt.format(it.valor),
                                    style: AppTextStyles.mono),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Painel de resumo: receita · gastos · sobra + botão adicionar
          Container(
            padding: EdgeInsets.fromLTRB(AppSpacing.pagePad, 14,
                AppSpacing.pagePad, MediaQuery.of(context).padding.bottom + 14),
            decoration: const BoxDecoration(
              color: AppColors.surf,
              border: Border(top: BorderSide(color: AppColors.bord, width: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Renda mensal (editável)
                InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  onTap: _editarReceita,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Text('Renda mensal', style: AppTextStyles.bodySm),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_outlined,
                              size: 14, color: AppColors.mu),
                        ]),
                        Text(
                          _s.receita > 0 ? _fmt.format(_s.receita) : 'toque p/ definir',
                          style: _s.receita > 0
                              ? AppTextStyles.mono
                              : AppTextStyles.caption
                                  .copyWith(color: AppColors.mu),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Total de gastos
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total de gastos', style: AppTextStyles.bodySm),
                    Text(_fmt.format(_s.total),
                        style: AppTextStyles.mono
                            .copyWith(color: AppColors.red)),
                  ],
                ),
                // Sobra (só aparece se houver renda informada)
                if (_s.receita > 0) ...[
                  const Divider(color: AppColors.bord, height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_s.sobra >= 0 ? 'Sobra' : 'Falta',
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text(_fmt.format(_s.sobra.abs()),
                          style: AppTextStyles.monoLg.copyWith(
                              color: _s.sobra >= 0
                                  ? AppColors.acc
                                  : AppColors.red,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                // Botão adicionar gasto (dentro do painel — não flutua sobre o total)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _adicionarItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.acc,
                      foregroundColor: AppColors.bg,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusBtn),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text('Adicionar gasto',
                        style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.bg,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modelos ──────────────────────────────────────────────────────────────────

class _ItemGasto {
  final String nome;
  final double valor;
  const _ItemGasto({required this.nome, required this.valor});

  Map<String, dynamic> toJson() => {'nome': nome, 'valor': valor};
  factory _ItemGasto.fromJson(Map<String, dynamic> j) => _ItemGasto(
        nome: j['nome'] as String? ?? '',
        valor: (j['valor'] as num?)?.toDouble() ?? 0,
      );
}

class _Simulacao {
  final String nome;
  final List<_ItemGasto> itens;
  final double receita; // renda mensal informada (0 = não informada)
  const _Simulacao({required this.nome, required this.itens, this.receita = 0});

  double get total => itens.fold(0.0, (s, it) => s + it.valor);
  double get sobra => receita - total; // pode ser negativo (falta)

  _Simulacao copyWith(
          {String? nome, List<_ItemGasto>? itens, double? receita}) =>
      _Simulacao(
        nome: nome ?? this.nome,
        itens: itens ?? this.itens,
        receita: receita ?? this.receita,
      );

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'receita': receita,
        'itens': itens.map((e) => e.toJson()).toList(),
      };
  factory _Simulacao.fromJson(Map<String, dynamic> j) => _Simulacao(
        nome: j['nome'] as String? ?? 'Simulação',
        receita: (j['receita'] as num?)?.toDouble() ?? 0,
        itens: ((j['itens'] as List?) ?? [])
            .map((e) => _ItemGasto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
