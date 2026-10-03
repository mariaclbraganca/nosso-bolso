import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/pin_provider.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../sheets/comum.dart';

class PatrimonioPinSheet extends ConsumerStatefulWidget {
  const PatrimonioPinSheet({super.key});

  @override
  ConsumerState<PatrimonioPinSheet> createState() => _PatrimonioPinSheetState();
}

class _PatrimonioPinSheetState extends ConsumerState<PatrimonioPinSheet> {
  final _pinCtrl = TextEditingController();
  bool _verificando = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _verificar() async {
    final pin = _pinCtrl.text.trim();
    if (pin.length < 4) {
      avisar('Digite o PIN de 4 dígitos.', erro: true);
      return;
    }

    setState(() => _verificando = true);
    final pinNotifier = ref.read(pinNotifierProvider.notifier);
    final configurado = await ref.read(pinConfiguradoProvider.future);

    if (!configurado) {
      // Configura pela primeira vez
      await pinNotifier.salvarPin(pin);
      avisar('PIN configurado com sucesso!');
      if (mounted) Navigator.pop(context, true);
    } else {
      final correto = await pinNotifier.verificarPin(pin);
      if (correto) {
        avisar('Patrimônio desbloqueado.');
        if (mounted) Navigator.pop(context, true);
      } else {
        avisar('PIN incorreto.', erro: true);
      }
    }
    if (mounted) setState(() => _verificando = false);
  }

  @override
  Widget build(BuildContext context) {
    final configuradoAsync = ref.watch(pinConfiguradoProvider);
    final configurado = configuradoAsync.valueOrNull ?? false;

    return CascaSheet(
      filhos: [
        TopoSheet(
          titulo: configurado ? 'Desbloquear Patrimônio' : 'Criar PIN de Segurança',
          subtitulo: configurado
              ? 'Digite seu PIN de 4 dígitos para acessar seus bens e contas'
              : 'Defina uma senha de 4 dígitos para proteger suas informações confidenciais',
        ),
        const SizedBox(height: NBSpacing.xxl),
        Center(
          child: SizedBox(
            width: 200,
            child: TextField(
              controller: _pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
              style: NBText.saldo.copyWith(letterSpacing: 12, fontSize: 32),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '••••',
              ),
              onSubmitted: (_) => _verificar(),
            ),
          ),
        ),
        const SizedBox(height: NBSpacing.l),
      ],
      botao: BotaoPrincipal(
        rotulo: configurado ? 'Desbloquear' : 'Salvar PIN',
        carregando: _verificando,
        onPressed: _verificar,
      ),
    );
  }
}
