import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';

/// Já viu o time nesta sessão? Volta a false ao sair da conta.
final splashVistoProvider = StateProvider<bool>((ref) => false);

/// Apresentação do time ao entrar: cada unicórnio chega com o seu papel.
class SplashUnicornios extends ConsumerStatefulWidget {
  const SplashUnicornios({super.key, this.duracao = const Duration(seconds: 7)});
  final Duration duracao;

  static const time = [
    (UnicornType.astrix, UnicornMood.wave, 'Astrix', 'Cuido das finanças: cada centavo no envelope certo.'),
    (UnicornType.sweet, UnicornMood.love, 'Sweet', 'Comemoro cada conquista de vocês, grande ou pequena.'),
    (UnicornType.happy, UnicornMood.celebrate, 'Happy', 'Trago o foco e a energia para bater as metas.'),
    (UnicornType.geronimo, UnicornMood.focus, 'Geronimo', 'Aviso antes de o dinheiro apertar. Pode contar comigo!'),
  ];

  @override
  ConsumerState<SplashUnicornios> createState() => _SplashUnicorniosState();
}

class _SplashUnicorniosState extends ConsumerState<SplashUnicornios> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..forward();
  Timer? _fim;

  @override
  void initState() {
    super.initState();
    _fim = Timer(widget.duracao, _entrar);
  }

  void _entrar() {
    _fim?.cancel();
    if (mounted) ref.read(splashVistoProvider.notifier).state = true;
  }

  @override
  void dispose() {
    _fim?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _entrar,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: NBSpacing.margemTela),
            child: Column(
              children: [
                const SizedBox(height: NBSpacing.x3),
                Text('O time chegou!', style: NBText.tituloTela, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Quatro unicórnios cuidando do bolso e de vocês', style: NBText.legenda, textAlign: TextAlign.center),
                const SizedBox(height: NBSpacing.xl),
                Expanded(
                  // 2×2 que encolhe junto com a tela (nada fica fora em celular baixo).
                  child: Column(
                    children: [
                      for (final linha in const [0, 2]) ...[
                        if (linha > 0) const SizedBox(height: NBSpacing.m),
                        Expanded(
                          child: Row(
                            children: [
                              for (final i in [linha, linha + 1]) ...[
                                if (i.isOdd) const SizedBox(width: NBSpacing.m),
                                Expanded(
                                  child: _Chegada(
                                    animacao: CurvedAnimation(
                                      parent: _ctrl,
                                      curve: Interval(i * 0.2, i * 0.2 + 0.4, curve: Curves.easeOutBack),
                                    ),
                                    dados: SplashUnicornios.time[i],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text('Toque para entrar', style: NBText.legenda),
                const SizedBox(height: NBSpacing.l),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chegada extends StatelessWidget {
  const _Chegada({required this.animacao, required this.dados});
  final Animation<double> animacao;
  final (UnicornType, UnicornMood, String, String) dados;

  @override
  Widget build(BuildContext context) {
    final (tipo, mood, nome, fala) = dados;
    return AnimatedBuilder(
      animation: animacao,
      builder: (context, child) => Opacity(
        opacity: animacao.value.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 24 * (1 - animacao.value)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(NBSpacing.m),
        decoration: BoxDecoration(
          color: NBColors.cartao,
          borderRadius: BorderRadius.circular(NBRadius.cartao),
          border: Border.all(color: NBColors.linha),
        ),
        child: Column(
          children: [
            Expanded(child: FittedBox(child: UnicornWidget(type: tipo, mood: mood, size: 72))),
            Text(nome, style: NBText.rotulo),
            const SizedBox(height: 2),
            Text(fala, style: NBText.legenda.copyWith(fontSize: 11), textAlign: TextAlign.center, maxLines: 3),
          ],
        ),
      ),
    );
  }
}
