import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/pin_provider.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../sheets/comum.dart';

enum _Acao { trocar, remover }

/// Criar, trocar ou remover o PIN que protege o Patrimônio.
class PinConfigScreen extends ConsumerStatefulWidget {
  const PinConfigScreen({super.key});

  @override
  ConsumerState<PinConfigScreen> createState() => _PinConfigScreenState();
}

class _PinConfigScreenState extends ConsumerState<PinConfigScreen> {
  final _atual = TextEditingController();
  final _novo = TextEditingController();
  final _confirma = TextEditingController();
  _Acao _acao = _Acao.trocar;
  bool _salvando = false;

  @override
  void dispose() {
    _atual.dispose();
    _novo.dispose();
    _confirma.dispose();
    super.dispose();
  }

  Future<void> _salvar(bool configurado) async {
    final pin = ref.read(pinNotifierProvider.notifier);
    if (configurado && !await pin.verificarPin(_atual.text)) {
      return avisar('PIN atual não confere.', erro: true);
    }
    if (configurado && _acao == _Acao.remover) {
      await pin.removerPin();
      ref.invalidate(pinConfiguradoProvider);
      avisar('PIN removido. O Patrimônio fica sem bloqueio.');
      if (mounted) Navigator.pop(context);
      return;
    }
    if (_novo.text.length != 4) return avisar('O PIN precisa ter 4 dígitos.', erro: true);
    if (_novo.text != _confirma.text) return avisar('A confirmação não bate com o PIN novo.', erro: true);
    setState(() => _salvando = true);
    try {
      await pin.salvarPin(_novo.text);
      ref.invalidate(pinConfiguradoProvider);
      avisar(configurado ? 'PIN trocado.' : 'PIN criado. O Patrimônio agora pede o PIN.');
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _campo(TextEditingController c, String rotulo) => Padding(
        padding: const EdgeInsets.only(bottom: NBSpacing.m),
        child: TextField(
          controller: c,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: NBText.valorCartao.copyWith(letterSpacing: 8),
          decoration: InputDecoration(labelText: rotulo, counterText: ''),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final configurado = ref.watch(pinConfiguradoProvider).valueOrNull;
    if (configurado == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final removendo = configurado && _acao == _Acao.remover;

    return Scaffold(
      appBar: AppBar(title: const Text('PIN do Patrimônio')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
        children: [
          Text(
            configurado
                ? 'O PIN protege o Patrimônio neste celular. Para trocar ou remover, confirme o PIN atual.'
                : 'Crie um PIN de 4 dígitos para proteger o Patrimônio neste celular.',
            style: NBText.corpo.copyWith(color: NBColors.tintaSuave),
          ),
          const SizedBox(height: NBSpacing.l),
          if (configurado) ...[
            Segmentado<_Acao>(
              opcoes: const {_Acao.trocar: 'Trocar PIN', _Acao.remover: 'Remover PIN'},
              valor: _acao,
              onChanged: (a) => setState(() => _acao = a),
            ),
            const SizedBox(height: NBSpacing.l),
            _campo(_atual, 'PIN atual'),
          ],
          if (!removendo) ...[
            _campo(_novo, configurado ? 'PIN novo' : 'PIN'),
            _campo(_confirma, 'Repita o PIN'),
          ],
          const SizedBox(height: NBSpacing.s),
          BotaoPrincipal(
            rotulo: removendo ? 'Remover PIN' : (configurado ? 'Trocar PIN' : 'Criar PIN'),
            cor: removendo ? NBColors.estouro : null,
            carregando: _salvando,
            onPressed: () => _salvar(configurado),
          ),
        ],
      ),
    );
  }
}
