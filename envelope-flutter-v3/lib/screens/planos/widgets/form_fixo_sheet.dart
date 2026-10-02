import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/mes_provider.dart';
import '../../../core/providers/usuarios_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../sheets/comum.dart';

class FormFixoSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? fixoParaEditar;

  const FormFixoSheet({super.key, this.fixoParaEditar});

  @override
  ConsumerState<FormFixoSheet> createState() => _FormFixoSheetState();
}

class _FormFixoSheetState extends ConsumerState<FormFixoSheet> {
  final _nomeCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  int _diaVencimento = 10;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final f = widget.fixoParaEditar;
    if (f != null) {
      _nomeCtrl.text = f['nome'] as String? ?? '';
      final val = (f['valor'] as num?)?.toDouble() ?? 0.0;
      _valorCtrl.text = val > 0 ? val.toStringAsFixed(2).replaceAll('.', ',') : '';
      _diaVencimento = (f['dia_vencimento'] as int?) ?? 10;
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  double get _valorNumerico {
    final t = _valorCtrl.text.replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(t) ?? 0.0;
  }

  Future<void> _salvar() async {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) {
      avisar('Informe o nome da despesa fixa.', erro: true);
      return;
    }
    if (_valorNumerico <= 0) {
      avisar('Informe um valor válido maior que zero.', erro: true);
      return;
    }

    setState(() => _salvando = true);
    final perfil = ref.read(perfilUsuarioLogadoProvider).value;
    final familiaId = perfil?['familia_id'] as String? ?? '';
    final mes = ref.read(mesAtualProvider);

    try {
      final f = widget.fixoParaEditar;
      if (f != null) {
        final id = f['id'] as String;
        await ApiService.patch('/fixos/$id', {
          'nome': nome,
          'valor': _valorNumerico,
          'dia_vencimento': _diaVencimento,
        });
        avisar('Gasto fixo atualizado com sucesso!');
      } else {
        await ApiService.post('/fixos/', {
          'nome': nome,
          'valor': _valorNumerico,
          'dia_vencimento': _diaVencimento,
          'mes': mes,
          'familia_id': familiaId,
        });
        avisar('Gasto fixo criado com sucesso!');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.fixoParaEditar != null;

    return CascaSheet(
      filhos: [
        TopoSheet(
          titulo: editando ? 'Editar Gasto Fixo' : 'Novo Gasto Fixo',
          subtitulo: 'Despesas recorrentes do mês (aluguel, internet, etc.)',
        ),
        const SizedBox(height: NBSpacing.l),
        CampoValor(
          controller: _valorCtrl,
          rotulo: 'VALOR DA PARCELA',
          corValor: NBColors.tinta,
        ),
        const SizedBox(height: NBSpacing.l),
        TextField(
          controller: _nomeCtrl,
          style: NBText.corpo,
          decoration: const InputDecoration(
            labelText: 'NOME DO GASTO FIXO',
            hintText: 'Ex: Aluguel, Condomínio, Escola...',
          ),
        ),
        const SizedBox(height: NBSpacing.l),
        Text('DIA DO VENCIMENTO', style: NBText.eyebrow),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 31,
            itemBuilder: (ctx, i) {
              final dia = i + 1;
              final sel = _diaVencimento == dia;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChipNB(
                  rotulo: '$dia',
                  selecionado: sel,
                  onTap: () => setState(() => _diaVencimento = dia),
                ),
              );
            },
          ),
        ),
      ],
      botao: BotaoPrincipal(
        rotulo: editando ? 'Salvar alterações' : 'Criar gasto fixo',
        carregando: _salvando,
        onPressed: _salvar,
      ),
    );
  }
}
