import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../core/providers/patrimonio_provider.dart';
import '../../../core/providers/usuarios_provider.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../sheets/comum.dart';

class FormPatrimonioSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? contaParaEditar;

  const FormPatrimonioSheet({super.key, this.contaParaEditar});

  @override
  ConsumerState<FormPatrimonioSheet> createState() => _FormPatrimonioSheetState();
}

class _FormPatrimonioSheetState extends ConsumerState<FormPatrimonioSheet> {
  final _nomeCtrl = TextEditingController();
  final _saldoCtrl = TextEditingController();
  String _tipo = 'investimento';
  bool _salvando = false;

  static const _tipos = [
    {'id': 'investimento', 'nome': 'Investimento', 'emoji': '📈'},
    {'id': 'conta_corrente', 'nome': 'Conta Bancária', 'emoji': '🏦'},
    {'id': 'reserva', 'nome': 'Reserva Emergência', 'emoji': '🛡️'},
    {'id': 'imovel', 'nome': 'Imóvel / Bem', 'emoji': '🏠'},
    {'id': 'veiculo', 'nome': 'Veículo', 'emoji': '🚗'},
    {'id': 'outro', 'nome': 'Outro Ativo', 'emoji': '💎'},
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.contaParaEditar;
    if (c != null) {
      _nomeCtrl.text = c['nome'] as String? ?? '';
      final saldo = (c['saldo_atual'] as num?)?.toDouble() ?? 0.0;
      _saldoCtrl.text = saldo > 0 ? saldo.toStringAsFixed(2).replaceAll('.', ',') : '';
      _tipo = c['tipo'] as String? ?? 'investimento';
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _saldoCtrl.dispose();
    super.dispose();
  }

  double get _saldoNumerico {
    final t = _saldoCtrl.text.replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(t) ?? 0.0;
  }

  Future<void> _salvar() async {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) {
      avisar('Informe o nome da conta ou do bem.', erro: true);
      return;
    }
    if (_saldoNumerico <= 0) {
      avisar('Informe um saldo ou valor estimado maior que zero.', erro: true);
      return;
    }

    setState(() => _salvando = true);
    final perfil = ref.read(perfilUsuarioLogadoProvider).valueOrNull;
    final familiaId = perfil?['familia_id'] as String? ?? '';

    try {
      final c = widget.contaParaEditar;
      if (c != null) {
        final id = c['id'] as String;
        await supabase.from('contas_patrimonio').update({
          'nome': nome,
          'tipo': _tipo,
          'saldo_atual': _saldoNumerico,
        }).eq('id', id);
        avisar('Conta patrimonial atualizada!');
      } else {
        await supabase.from('contas_patrimonio').insert({
          'familia_id': familiaId,
          'nome': nome,
          'tipo': _tipo,
          'saldo_atual': _saldoNumerico,
        });
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
          subtitulo: 'Cadastre investimentos, contas bancárias, imóveis ou veículos',
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
            hintText: 'Ex: Tesouro Selic, Nubank, Apto Centro...',
          ),
        ),
        const SizedBox(height: NBSpacing.l),
        Text('TIPO DE ATIVO', style: NBText.eyebrow),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in _tipos)
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
