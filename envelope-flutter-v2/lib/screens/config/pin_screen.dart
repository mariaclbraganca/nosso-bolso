import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/pin_provider.dart';

enum PinMode { setup, verify }

/// Tela de PIN numérico de 6 dígitos.
/// mode=setup: define o PIN pela primeira vez (pede 2x para confirmar)
/// mode=verify: verifica o PIN e chama onSuccess ao acertar
class PinScreen extends ConsumerStatefulWidget {
  final PinMode mode;
  final VoidCallback? onSuccess;
  final String? titulo;

  const PinScreen({
    super.key,
    required this.mode,
    this.onSuccess,
    this.titulo,
  });

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  String _pin = '';
  String _pinConfirm = '';
  bool _confirmando = false;
  bool _erro = false;
  bool _loading = false;

  void _onDigit(String d) {
    if (_loading) return;
    setState(() {
      _erro = false;
      if (_confirmando) {
        if (_pinConfirm.length < 6) _pinConfirm += d;
      } else {
        if (_pin.length < 6) _pin += d;
      }
    });
    _verificarAuto();
  }

  void _onDelete() {
    if (_loading) return;
    setState(() {
      _erro = false;
      if (_confirmando) {
        if (_pinConfirm.isNotEmpty) _pinConfirm = _pinConfirm.substring(0, _pinConfirm.length - 1);
      } else {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  Future<void> _verificarAuto() async {
    final atual = _confirmando ? _pinConfirm : _pin;
    if (atual.length < 6) return;

    if (widget.mode == PinMode.setup) {
      if (!_confirmando) {
        // Primeiro PIN digitado — pede confirmação
        await Future.delayed(const Duration(milliseconds: 150));
        setState(() => _confirmando = true);
      } else {
        // Confirmação digitada — compara
        if (_pin == _pinConfirm) {
          setState(() => _loading = true);
          await ref.read(pinNotifierProvider.notifier).salvarPin(_pin);
          if (mounted) widget.onSuccess?.call();
        } else {
          setState(() {
            _erro = true;
            _pinConfirm = '';
          });
        }
      }
    } else {
      // Modo verify
      setState(() => _loading = true);
      final ok = await ref.read(pinNotifierProvider.notifier).verificarPin(_pin);
      if (ok) {
        if (mounted) widget.onSuccess?.call();
      } else {
        setState(() {
          _erro = true;
          _pin = '';
          _loading = false;
        });
      }
    }
  }

  String get _subtitulo {
    if (widget.mode == PinMode.setup) {
      return _confirmando ? 'Confirme o PIN' : 'Defina um PIN de 6 dígitos';
    }
    return 'Digite seu PIN para continuar';
  }

  String get _pinAtual => _confirmando ? _pinConfirm : _pin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: widget.mode == PinMode.setup
          ? AppBar(
              backgroundColor: AppColors.bg,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.mu, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            // Ícone
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.acc.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, color: AppColors.acc, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              widget.titulo ?? (widget.mode == PinMode.setup ? 'Configurar PIN Admin' : 'Área Restrita'),
              style: AppTextStyles.title,
            ),
            const SizedBox(height: 8),
            Text(_subtitulo, style: AppTextStyles.bodySm.copyWith(color: AppColors.mu)),
            const SizedBox(height: 40),

            // Indicadores de dígitos
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                final filled = i < _pinAtual.length;
                final isErro = _erro;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isErro
                        ? AppColors.red
                        : filled
                            ? AppColors.acc
                            : AppColors.bord,
                    border: Border.all(
                      color: isErro ? AppColors.red : filled ? AppColors.acc : AppColors.mu.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                );
              }),
            ),

            if (_erro) ...[
              const SizedBox(height: 12),
              Text(
                widget.mode == PinMode.setup ? 'PINs não coincidem. Tente novamente.' : 'PIN incorreto. Tente novamente.',
                style: AppTextStyles.caption.copyWith(color: AppColors.red),
              ),
            ],

            const Spacer(),

            // Teclado numérico
            if (!_loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  children: [
                    for (var row in [
                      ['1', '2', '3'],
                      ['4', '5', '6'],
                      ['7', '8', '9'],
                      ['', '0', '⌫'],
                    ])
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: row.map((d) => _KeyButton(
                          label: d,
                          onTap: d.isEmpty ? null : d == '⌫' ? _onDelete : () => _onDigit(d),
                        )).toList(),
                      ),
                  ],
                ),
              )
            else
              const CircularProgressIndicator(color: AppColors.acc),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _KeyButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: label.isEmpty ? Colors.transparent : AppColors.card,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: label == '⌫'
            ? const Icon(Icons.backspace_outlined, color: AppColors.tx, size: 22)
            : Text(
                label,
                style: AppTextStyles.title.copyWith(fontSize: 24),
              ),
      ),
    );
  }
}
