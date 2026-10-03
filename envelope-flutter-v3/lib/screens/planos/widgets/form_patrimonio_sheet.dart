import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../core/providers/patrimonio_provider.dart';
import '../../../core/providers/usuarios_provider.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../sheets/comum.dart';

abstract final class FormPatrimonioSheetTipos {
  static String nome(String? id) =>
      _FormPatrimonioSheetState.tipos.firstWhere((t) => t['id'] == id, orElse: () => {'nome': id ?? 'Outro'})['nome']!;
}

class FormPatrimonioSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? contaParaEditar;

  const FormPatrimonioSheet({super.key, this.contaParaEditar});

  @override
  ConsumerState<FormPatrimonioSheet> createState() => _FormPatrimonioSheetState();
}

class _FormPatrimonioSheetState extends ConsumerState<FormPatrimonioSheet> {
  final _nomeCtrl = TextEditingController();
  final _saldoCtrl = TextEditingController();
  final _bancoCtrl = TextEditingController();
  final _rendimentoCtrl = TextEditingController();
  final _metaCtrl = TextEditingController();
  String _tipo = 'conta_corrente';
  bool _salvando = false;

  // Mesmos tipos da v2 (os que a tabela contas_patrimonio já recebe).
  static const tipos = [
    {'id': 'conta_corrente', 'nome': 'Conta corrente', 'emoji': '🏦'},
    {'id': 'poupanca', 'nome': 'Poupança', 'emoji': '🐷'},
    {'id': 'investimento', 'nome': 'Investimento', 'emoji': '📈'},
    {'id': 'caixinha', 'nome': 'Caixinha', 'emoji': '📦'},
    {'id': 'carteira', 'nome': 'Carteira física', 'emoji': '👛'},
  ];

  static String _num(num? v) => v == null || v == 0 ? '' : v.toStringAsFixed(2).replaceAll('.', ',');

  @override
  void initState() {
    super.initState();
    final c = widget.contaParaEditar;
    if (c != null) {
      _nomeCtrl.text = c['nome'] as String? ?? '';
      final saldo = (c['saldo_atual'] as num?)?.toDouble() ?? 0.0;
      _saldoCtrl.text = saldo > 0 ? saldo.toStringAsFixed(2).replaceAll('.', ',') : '';
      _tipo = c['tipo'] as String? ?? 'conta_corrente';
      _bancoCtrl.text = c['banco'] as String? ?? '';
      _rendimentoCtrl.text = _num(c['rendimento_mensal'] as num?);
      _metaCtrl.text = _num(c['meta_saldo'] as num?);
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _saldoCtrl.dispose();
    _bancoCtrl.dispose();
    _rendimentoCtrl.dispose();
    _metaCtrl.dispose();
    super.dispose();
  }

  static double? _parse(String s) =>
      double.tryParse(s.replaceAll('.', '').replaceAll(',', '.').trim());

  double get _saldoNumerico => _parse(_saldoCtrl.text) ?? 0.0;

  /// Campos gravados em contas_patrimonio (iguais aos da v2).
  Map<String, dynamic> dadosConta(String nome) {
    final meta = _parse(_metaCtrl.text);
    return {
      'nome': nome,
      'tipo': _tipo,
      'emoji': tipos.firstWhere((t) => t['id'] == _tipo, orElse: () => tipos.first)['emoji'],
      'saldo_atual': _saldoNumerico,
      'banco': _bancoCtrl.text.trim().isEmpty ? null : _bancoCtrl.text.trim(),
      'rendimento_mensal': double.tryParse(_rendimentoCtrl.text.replaceAll(',', '.').trim()),
      'meta_saldo': meta == null || meta <= 0 ? null : meta,
    };
  }

  Future<void> _salvar() async {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) {
      avisar('Informe o nome da conta ou do bem.', erro: true);
      return;
    }
    if (_saldoNumerico < 0) {
      avisar('O saldo não pode ser negativo.', erro: true);
      return;
    }

    setState(() => _salvando = true);
    final perfil = ref.read(perfilUsuarioLogadoProvider).valueOrNull;
    final familiaId = perfil?['familia_id'] as String? ?? '';

    try {
      final c = widget.contaParaEditar;
      if (c != null) {
        final id = c['id'] as String;
        await supabase.from('contas_patrimonio').update(dadosConta(nome)).eq('id', id);
        avisar('Conta patrimonial atualizada!');
      } else {
        await supabase.from('contas_patrimonio').insert({'familia_id': familiaId, ...dadosConta(nome)});
        avisar('Conta patrimonial adicionada!');
      }

      final contas = await supabase.from('contas_patrimonio').select().eq('familia_id', familiaId);
      await salvarSnapshotMesAtual(List<Map<String, dynamic>>.from(contas), familiaId);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.contaParaEditar != null;

    return CascaSheet(
      filhos: [
        TopoSheet(
          titulo: editando ? 'Editar Conta / Ativo' : 'Novo Ativo Patrimonial',
          subtitulo: 'Contas, poupança, investimentos e caixinhas. Defina uma meta para acompanhar o prazo.',
        ),
        const SizedBox(height: NBSpacing.l),
        CampoValor(
          controller: _saldoCtrl,
          rotulo: 'VALOR ATUAL ESTIMADO',
          corValor: NBColors.tinta,
        ),
        const SizedBox(height: NBSpacing.l),
        TextField(
          controller: _nomeCtrl,
          style: NBText.corpo,
          decoration: const InputDecoration(
            labelText: 'NOME DO ATIVO',
            hintText: 'Ex: Reserva, Caixinha viagem, Tesouro Selic...',
          ),
        ),
        const SizedBox(height: NBSpacing.l),
        TextField(
          controller: _bancoCtrl,
          style: NBText.corpo,
          decoration: const InputDecoration(labelText: 'BANCO (opcional)', hintText: 'Ex: Nubank, Inter, Caixa'),
        ),
        const SizedBox(height: NBSpacing.l),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _rendimentoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: NBText.corpo,
                decoration: const InputDecoration(labelText: 'RENDIMENTO', suffixText: '% a.m.', hintText: '0,85'),
              ),
            ),
            const SizedBox(width: NBSpacing.m),
            Expanded(
              child: TextField(
                controller: _metaCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: NBText.corpo,
                decoration: const InputDecoration(labelText: 'META DE SALDO', prefixText: 'R\$ ', hintText: 'opcional'),
              ),
            ),
          ],
        ),
        const SizedBox(height: NBSpacing.l),
        Text('TIPO DE ATIVO', style: NBText.eyebrow),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in tipos)
              ChipNB(
                rotulo: t['nome']!,
                icone: Text(t['emoji']!, style: const TextStyle(fontSize: 14)),
                selecionado: _tipo == t['id'],
                onTap: () => setState(() => _tipo = t['id']!),
              ),
          ],
        ),
      ],
      botao: BotaoPrincipal(
        rotulo: editando ? 'Salvar alterações' : 'Salvar ativo',
        carregando: _salvando,
        onPressed: _salvar,
      ),
    );
  }
}
