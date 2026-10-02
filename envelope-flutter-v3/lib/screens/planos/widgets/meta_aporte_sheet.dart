import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/metas_provider.dart';
import '../../../core/services/financeiro_ext_service.dart';
import '../../../core/utils/moeda.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';
import '../../sheets/comum.dart';

/// Aporte numa meta de economia. O backend só aceita contribuições positivas
/// (PATCH /metas-economia/{id}/contribuir), então não há retirada aqui.
class MetaAporteSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> meta;

  const MetaAporteSheet({super.key, required this.meta});

  @override
  ConsumerState<MetaAporteSheet> createState() => _MetaAporteSheetState();
}

class _MetaAporteSheetState extends ConsumerState<MetaAporteSheet> {
  final _valorCtrl = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _valorCtrl.dispose();
    super.dispose();
  }

  double get _valor => parseMoeda(_valorCtrl.text);

  Future<void> _salvar() async {
    if (_valor <= 0) return avisar('Informe um valor maior que zero.', erro: true);

    setState(() => _salvando = true);
    final valorAtual = (widget.meta['valor_atual'] as num?)?.toDouble() ?? 0.0;
    final valorMeta = (widget.meta['valor_meta'] as num?)?.toDouble() ?? 0.0;
    try {
      await FinanceiroExtService.contribuirMeta(idMongo(widget.meta), valor: _valor, descricao: 'Aporte');
      ref.invalidate(metasProvider);
      if (valorMeta > 0 && valorAtual < valorMeta && valorAtual + _valor >= valorMeta) {
        ref.sweet('Meta ${widget.meta['nome'] ?? ''} concluída! Que conquista!', mood: UnicornMood.celebrate);
      } else {
        avisar('Aporte de ${brl(_valor)} registrado.');
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
    final nome = widget.meta['nome'] as String? ?? 'Meta';
    final emoji = widget.meta['emoji'] as String? ?? '🎯';

    return CascaSheet(
      filhos: [
        TopoSheet(titulo: '$emoji $nome', subtitulo: 'Quanto vai guardar nesta meta?'),
        const SizedBox(height: NBSpacing.l),
        CampoValor(
          controller: _valorCtrl,
          rotulo: 'Valor do aporte',
          corValor: NBColors.verde,
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),
      ],
      botao: BotaoPrincipal(
        rotulo: _valor > 0 ? 'Guardar ${brl(_valor)}' : 'Confirmar aporte',
        carregando: _salvando,
        onPressed: _salvar,
      ),
    );
  }
}
