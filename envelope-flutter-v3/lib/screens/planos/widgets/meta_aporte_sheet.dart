import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../core/providers/metas_provider.dart';
import '../../../core/services/financeiro_ext_service.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../sheets/comum.dart';

class MetaAporteSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> meta;

  const MetaAporteSheet({super.key, required this.meta});

  @override
  ConsumerState<MetaAporteSheet> createState() => _MetaAporteSheetState();
}

class _MetaAporteSheetState extends ConsumerState<MetaAporteSheet> {
  final _valorCtrl = TextEditingController();
  bool _isAporte = true;
  bool _salvando = false;

  @override
  void dispose() {
    _valorCtrl.dispose();
    super.dispose();
  }

  double get _valorNumerico {
    final t = _valorCtrl.text.replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(t) ?? 0.0;
  }

  Future<void> _salvar() async {
    if (_valorNumerico <= 0) {
      avisar('Informe um valor válido maior que zero.', erro: true);
      return;
    }

    setState(() => _salvando = true);
    final id = widget.meta['id'] as String;
    final valorAtual = (widget.meta['valor_atual'] as num?)?.toDouble() ?? 0.0;
    final novoSaldo = _isAporte ? (valorAtual + _valorNumerico) : (valorAtual - _valorNumerico);

    if (novoSaldo < 0) {
      avisar('O saldo da meta não pode ficar negativo.', erro: true);
      setState(() => _salvando = false);
      return;
    }

    try {
      try {
        await FinanceiroExtService.contribuirMeta(
          id,
          valor: _isAporte ? _valorNumerico : -_valorNumerico,
          descricao: _isAporte ? 'Aporte' : 'Retirada',
        );
      } catch (_) {
        await supabase.from('metas_economia').update({'valor_atual': novoSaldo}).eq('id', id);
      }
      ref.invalidate(metasProvider);

      final valorAlvo = (widget.meta['valor_alvo'] as num?)?.toDouble() ?? 0.0;
      if (_isAporte && novoSaldo >= valorAlvo && valorAtual < valorAlvo) {
        avisar('PARABÉNS! Você atingiu sua meta! 🎉🦄');
      } else {
        avisar(_isAporte ? 'Aporte registrado com sucesso!' : 'Retirada registrada.');
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
    final titulo = widget.meta['titulo'] as String? ?? 'Meta';
    final emoji = widget.meta['emoji'] as String? ?? '🎯';

    return CascaSheet(
      filhos: [
        TopoSheet(
          titulo: '$emoji $titulo',
          subtitulo: 'Deposite ou retire valores acumulados nesta meta',
        ),
        const SizedBox(height: NBSpacing.l),
        Row(
          children: [
            Expanded(
              child: ChipNB(
                rotulo: 'Aporte (+)',
                selecionado: _isAporte,
                onTap: () => setState(() => _isAporte = true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChipNB(
                rotulo: 'Retirada (-)',
                selecionado: !_isAporte,
                onTap: () => setState(() => _isAporte = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: NBSpacing.l),
        CampoValor(
          controller: _valorCtrl,
          rotulo: _isAporte ? 'VALOR DO APORTE' : 'VALOR DA RETIRADA',
          corValor: _isAporte ? NBColors.verde : NBColors.tinta,
        ),
      ],
      botao: BotaoPrincipal(
        rotulo: _isAporte ? 'Confirmar aporte' : 'Confirmar retirada',
        carregando: _salvando,
        onPressed: _salvar,
      ),
    );
  }
}
