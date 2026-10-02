import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/metas_provider.dart';
import '../../../core/providers/usuarios_provider.dart';
import '../../../core/services/financeiro_ext_service.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../sheets/comum.dart';

class FormMetaSheet extends ConsumerStatefulWidget {
  const FormMetaSheet({super.key});

  @override
  ConsumerState<FormMetaSheet> createState() => _FormMetaSheetState();
}

class _FormMetaSheetState extends ConsumerState<FormMetaSheet> {
  final _tituloCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  String _emoji = '🎯';
  DateTime? _prazo;
  bool _salvando = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  double get _valorNumerico {
    final t = _valorCtrl.text.replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(t) ?? 0.0;
  }

  Future<void> _salvar() async {
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      avisar('Informe o objetivo da meta.', erro: true);
      return;
    }
    if (_valorNumerico <= 0) {
      avisar('Informe um valor alvo válido maior que zero.', erro: true);
      return;
    }

    setState(() => _salvando = true);
    final perfil = ref.read(perfilUsuarioLogadoProvider).value;
    final familiaId = perfil?['familia_id'] as String? ?? '';

    try {
      await FinanceiroExtService.criarMeta({
        'familia_id': familiaId,
        'titulo': titulo,
        'valor_alvo': _valorNumerico,
        'valor_atual': 0.0,
        'emoji': _emoji,
        'data_prazo': _prazo != null ? DateFormat('yyyy-MM-dd').format(_prazo!) : null,
      });

      avisar('Meta criada com sucesso! 🎯');
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
          titulo: 'Nova Meta Financeira',
          subtitulo: 'Defina um objetivo para você ou para a família poupar',
        ),
        const SizedBox(height: NBSpacing.l),
        CampoValor(
          controller: _valorCtrl,
          rotulo: 'VALOR ALVO DO OBJETIVO',
          corValor: NBColors.tinta,
        ),
        const SizedBox(height: NBSpacing.l),
        TextField(
          controller: _tituloCtrl,
          style: NBText.corpo,
          decoration: const InputDecoration(
            labelText: 'NOME DA META',
            hintText: 'Ex: Férias de Verão, Carro Novo, Reserva...',
          ),
        ),
        const SizedBox(height: NBSpacing.l),
        Text('ÍCONE REPRESENTATIVO', style: NBText.eyebrow),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final s in emojisMetaSugestao)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChipNB(
                    rotulo: s['nome']!,
                    icone: Text(s['emoji']!, style: const TextStyle(fontSize: 14)),
                    selecionado: _emoji == s['emoji'],
                    onTap: () => setState(() => _emoji = s['emoji']!),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: NBSpacing.l),
        Text('DATA LIMITE / PRAZO (OPCIONAL)', style: NBText.eyebrow),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final escolhida = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 180)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
            );
            if (escolhida != null) setState(() => _prazo = escolhida);
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
                const Icon(Icons.event_outlined, size: 18, color: NBColors.tintaSuave),
                const SizedBox(width: 10),
                Text(
                  _prazo != null
                      ? DateFormat("d 'de' MMMM 'de' yyyy", 'pt_BR').format(_prazo!)
                      : 'Sem prazo determinado',
                  style: NBText.corpo,
                ),
                const Spacer(),
                if (_prazo != null)
                  GestureDetector(
                    onTap: () => setState(() => _prazo = null),
                    child: const Icon(Icons.close_rounded, size: 16, color: NBColors.tintaSuave),
                  ),
              ],
            ),
          ),
        ),
      ],
      botao: BotaoPrincipal(
        rotulo: 'Criar meta',
        carregando: _salvando,
        onPressed: _salvar,
      ),
    );
  }
}
