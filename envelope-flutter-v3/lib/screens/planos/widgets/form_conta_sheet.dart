import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/contas_provider.dart';
import '../../../core/providers/usuarios_provider.dart';
import '../../../core/services/financeiro_ext_service.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../sheets/comum.dart';

class FormContaSheet extends ConsumerStatefulWidget {
  const FormContaSheet({super.key});

  @override
  ConsumerState<FormContaSheet> createState() => _FormContaSheetState();
}

class _FormContaSheetState extends ConsumerState<FormContaSheet> {
  final _nomeCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  String _categoria = 'energia';
  DateTime _vencimento = DateTime.now().add(const Duration(days: 7));
  bool _salvando = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _valorCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  double get _valorNumerico {
    final t = _valorCtrl.text.replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(t) ?? 0.0;
  }

  Future<void> _salvar() async {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) {
      avisar('Informe o nome da conta ou concessionária.', erro: true);
      return;
    }
    if (_valorNumerico <= 0) {
      avisar('Informe um valor válido maior que zero.', erro: true);
      return;
    }

    setState(() => _salvando = true);
    final perfil = ref.read(perfilUsuarioLogadoProvider).value;
    final familiaId = perfil?['familia_id'] as String? ?? '';

    try {
      await FinanceiroExtService.criarConta({
        'familia_id': familiaId,
        'nome': nome,
        'valor': _valorNumerico,
        'categoria': _categoria,
        'vencimento': DateFormat('yyyy-MM-dd').format(_vencimento),
        'observacao': _codigoCtrl.text.trim(),
      });

      avisar('Conta registrada com sucesso!');
      if (mounted) Navigator.pop(context, true);
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
        const TopoSheet(
          titulo: 'Nova Conta / Boleto',
          subtitulo: 'Cadastre faturas de água, luz, internet e cartões',
        ),
        const SizedBox(height: NBSpacing.l),
        CampoValor(
          controller: _valorCtrl,
          rotulo: 'VALOR DO BOLETO',
          corValor: NBColors.tinta,
        ),
        const SizedBox(height: NBSpacing.l),
        TextField(
          controller: _nomeCtrl,
          style: NBText.corpo,
          decoration: const InputDecoration(
            labelText: 'DESCRIÇÃO DA CONTA',
            hintText: 'Ex: Enel, Sabesp, Vivo Fibra...',
          ),
        ),
        const SizedBox(height: NBSpacing.l),
        Text('CATEGORIA', style: NBText.eyebrow),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final c in categoriasContas)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChipNB(
                    rotulo: c['nome']!,
                    icone: Text(c['emoji']!, style: const TextStyle(fontSize: 12)),
                    selecionado: _categoria == c['id'],
                    onTap: () => setState(() => _categoria = c['id']!),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: NBSpacing.l),
        Text('DATA DE VENCIMENTO', style: NBText.eyebrow),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final escolhida = await showDatePicker(
              context: context,
              initialDate: _vencimento,
              firstDate: DateTime.now().subtract(const Duration(days: 60)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (escolhida != null) setState(() => _vencimento = escolhida);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: NBColors.cartao,
              borderRadius: BorderRadius.circular(NBRadius.campo),
              border: Border.all(color: NBColors.linha),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 18, color: NBColors.tintaSuave),
                const SizedBox(width: 10),
                Text(
                  DateFormat("d 'de' MMMM 'de' yyyy", 'pt_BR').format(_vencimento),
                  style: NBText.corpo,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: NBSpacing.l),
        TextField(
          controller: _codigoCtrl,
          style: NBText.corpo,
          decoration: const InputDecoration(
            labelText: 'CÓDIGO DE BARRAS OU PIX (OPCIONAL)',
            hintText: 'Cole a linha digitável ou chave PIX',
          ),
        ),
      ],
      botao: BotaoPrincipal(
        rotulo: 'Salvar boleto',
        carregando: _salvando,
        onPressed: _salvar,
      ),
    );
  }
}
