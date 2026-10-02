import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/unicorn_team.dart';
import '../theme/nb_theme.dart';
import 'astrix_painter.dart';
import 'geronimo_painter.dart';
import 'happy_painter.dart';
import 'particle_system.dart';
import 'sweet_painter.dart';

export '../../core/providers/unicorn_team.dart' show UnicornType, UnicornMood, UnicornTrigger;

extension UnicornPersona on UnicornType {
  String get nome => switch (this) {
        UnicornType.astrix => 'Astrix',
        UnicornType.sweet => 'Sweet',
        UnicornType.happy => 'Happy',
        UnicornType.geronimo => 'Geronimo',
      };

  Color get acento => switch (this) {
        UnicornType.astrix => const Color(0xFF7B3FC4),
        UnicornType.sweet => const Color(0xFFC2456A),
        UnicornType.happy => NBColors.ambarTexto,
        UnicornType.geronimo => const Color(0xFFC25400),
      };
}

class UnicornWidget extends StatefulWidget {
  const UnicornWidget({
    super.key,
    required this.type,
    this.size = 120,
    this.mood = UnicornMood.idle,
    this.animate = true,
  });

  final UnicornType type;
  final double size;
  final UnicornMood mood;
  final bool animate;

  @override
  State<UnicornWidget> createState() => _UnicornWidgetState();
}

class _UnicornWidgetState extends State<UnicornWidget> with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _blink;
  late final AnimationController _enter;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 150))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _blink.reverse();
      });
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();
    if (widget.animate) {
      _idle.repeat(reverse: true);
      _agendarPiscada();
    }
  }

  void _agendarPiscada() {
    _blinkTimer = Timer(Duration(milliseconds: 3500 + Random().nextInt(2000)), () {
      if (!mounted) return;
      _blink.forward();
      _agendarPiscada();
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _idle.dispose();
    _blink.dispose();
    _enter.dispose();
    super.dispose();
  }

  static AstrixMood _astrixMood(UnicornMood m) => switch (m) {
        UnicornMood.celebrate || UnicornMood.love => AstrixMood.celebrate,
        UnicornMood.wave || UnicornMood.chaos => AstrixMood.wave,
        UnicornMood.thinking || UnicornMood.focus => AstrixMood.thinking,
        UnicornMood.sad => AstrixMood.sad,
        UnicornMood.idle => AstrixMood.idle,
      };

  CustomPainter _painter(double t, double blink) {
    final wag = sin(t * 2 * pi) * 0.8;
    final celebra = widget.mood == UnicornMood.celebrate || widget.mood == UnicornMood.love;
    final sparkle = celebra ? t : 0.0;
    return switch (widget.type) {
      UnicornType.astrix =>
        AstrixPainter(mood: _astrixMood(widget.mood), t: t, blink: blink, tailWag: wag, sparkle: sparkle),
      UnicornType.sweet => SweetPainter(mood: widget.mood, t: t, blink: blink, tailWag: wag, sparkle: sparkle),
      UnicornType.happy => HappyPainter(mood: widget.mood, t: t, blink: blink, tailWag: wag, sparkle: sparkle),
      UnicornType.geronimo =>
        GeronimoUnicornPainter(mood: widget.mood, t: t, blink: blink, tailWag: wag, sparkle: sparkle),
    };
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.size * 1.16;
    final enter = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
    return Semantics(
      label: 'Unicórnio ${widget.type.nome}',
      child: FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(enter),
          child: AnimatedBuilder(
            animation: Listenable.merge([_idle, _blink]),
            builder: (_, __) => Transform.scale(
              scale: 1 + Curves.easeInOut.transform(_idle.value) * 0.025,
              child: CustomPaint(size: Size(widget.size, h), painter: _painter(_idle.value, _blink.value)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Balão de fala no estilo papel: cartão claro, borda fina, ponta voltada ao unicórnio.
class UnicornFala extends StatelessWidget {
  const UnicornFala({super.key, required this.type, required this.texto, this.maxWidth = 240});
  final UnicornType type;
  final String texto;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: NBColors.cartao,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
        border: Border.all(color: NBColors.linha),
        boxShadow: const [BoxShadow(color: Color(0x1A1A2420), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(type.nome.toUpperCase(), style: NBText.eyebrow.copyWith(color: type.acento)),
          const SizedBox(height: 2),
          Text(texto, style: NBText.corpo.copyWith(fontSize: 14, height: 20 / 14)),
        ],
      ),
    );
  }
}

/// Camada global: escuta [unicornTeamProvider] e [unicornTeamMomentProvider]
/// e mostra o unicórnio falando sobre qualquer tela.
class UnicornStage extends ConsumerStatefulWidget {
  const UnicornStage({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<UnicornStage> createState() => _UnicornStageState();
}

class _UnicornStageState extends ConsumerState<UnicornStage> with SingleTickerProviderStateMixin {
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  UnicornMessage? _msg;
  TeamMoment? _time;
  Timer? _timer;

  void _mostrar({UnicornMessage? msg, TeamMoment? time}) {
    _timer?.cancel();
    setState(() {
      _msg = msg;
      _time = time;
    });
    _fade.forward(from: 0);
    _timer = Timer(msg?.duration ?? time!.duration, _fechar);
  }

  void _fechar() {
    _timer?.cancel();
    _fade.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _msg = null;
        _time = null;
      });
      ref.read(unicornTeamProvider.notifier).state = null;
      ref.read(unicornTeamMomentProvider.notifier).state = null;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  ParticleType _particulas() {
    if (_time != null) return ParticleType.teamBurst;
    final m = _msg!;
    if (m.mood != UnicornMood.celebrate && m.mood != UnicornMood.love) return ParticleType.stars;
    return particleTypeForUnicorn(m.type);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UnicornMessage?>(unicornTeamProvider, (_, n) {
      if (n != null) _mostrar(msg: n);
    });
    ref.listen<TeamMoment?>(unicornTeamMomentProvider, (_, n) {
      if (n != null) _mostrar(time: n);
    });

    final ativo = _msg != null || _time != null;
    final comemora = _time != null || _msg?.mood == UnicornMood.celebrate || _msg?.mood == UnicornMood.love;
    final anim = CurvedAnimation(parent: _fade, curve: Curves.easeOut);
    final inferior = MediaQuery.paddingOf(context).bottom + 84;

    return Stack(
      children: [
        widget.child,
        if (ativo && comemora)
          Positioned.fill(
            child: IgnorePointer(child: FadeTransition(opacity: anim, child: FullScreenParticles(type: _particulas()))),
          ),
        if (_msg != null)
          Positioned(
            right: 12,
            bottom: inferior,
            child: FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(anim),
                child: GestureDetector(
                  onTap: _fechar,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 36),
                          child: UnicornFala(type: _msg!.type, texto: _msg!.text, maxWidth: 220),
                        ),
                        UnicornWidget(type: _msg!.type, mood: _msg!.mood, size: 80),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_time != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: inferior,
            child: FadeTransition(
              opacity: anim,
              child: Material(
                type: MaterialType.transparency,
                child: _PainelTime(momento: _time!, onFechar: _fechar),
              ),
            ),
          ),
      ],
    );
  }
}

class _PainelTime extends StatelessWidget {
  const _PainelTime({required this.momento, required this.onFechar});
  final TeamMoment momento;
  final VoidCallback onFechar;

  static const _humor = {
    UnicornType.astrix: UnicornMood.celebrate,
    UnicornType.sweet: UnicornMood.love,
    UnicornType.happy: UnicornMood.focus,
    UnicornType.geronimo: UnicornMood.chaos,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onFechar,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
        decoration: BoxDecoration(
          color: NBColors.cartao,
          borderRadius: BorderRadius.circular(NBRadius.destaque),
          border: Border.all(color: NBColors.linha),
          boxShadow: const [BoxShadow(color: Color(0x1F1A2420), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final t in UnicornType.values)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if ((momento.messages[t] ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          momento.messages[t]!,
                          textAlign: TextAlign.center,
                          style: NBText.legenda.copyWith(color: NBColors.tinta, fontSize: 11),
                        ),
                      ),
                    UnicornWidget(type: t, mood: _humor[t]!, size: 54),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Estado vazio: unicórnio grande (≥160) + título + apoio + ação opcional.
class UnicornVazio extends StatelessWidget {
  const UnicornVazio({
    super.key,
    this.type = UnicornType.astrix,
    required this.titulo,
    this.texto = '',
    this.acao,
    this.rotuloAcao,
  });

  final UnicornType type;
  final String titulo;
  final String texto;
  final VoidCallback? acao;
  final String? rotuloAcao;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NBSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UnicornWidget(type: type, size: 160, mood: UnicornMood.wave),
            const SizedBox(height: NBSpacing.l),
            Text(titulo, style: NBText.secao, textAlign: TextAlign.center),
            if (texto.isNotEmpty) ...[
              const SizedBox(height: NBSpacing.s),
              Text(texto, style: NBText.corpo.copyWith(color: NBColors.tintaSuave), textAlign: TextAlign.center),
            ],
            if (acao != null && rotuloAcao != null) ...[
              const SizedBox(height: NBSpacing.xl),
              FilledButton(
                onPressed: acao,
                style: FilledButton.styleFrom(minimumSize: const Size(200, 50)),
                child: Text(rotuloAcao!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Substitui spinners. Happy fica em foco enquanto algo carrega.
class UnicornCarregando extends StatelessWidget {
  const UnicornCarregando({super.key, this.texto, this.type = UnicornType.happy, this.tamanho = 96});
  final String? texto;
  final UnicornType type;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UnicornWidget(type: type, size: tamanho, mood: UnicornMood.thinking),
          const SizedBox(height: NBSpacing.m),
          Text(texto ?? 'Carregando…', style: NBText.legenda),
        ],
      ),
    );
  }
}

/// Erro com Geronimo (alertas) e botão de tentar de novo.
class UnicornErro extends StatelessWidget {
  const UnicornErro({super.key, required this.mensagem, this.onTentar});
  final String mensagem;
  final VoidCallback? onTentar;

  @override
  Widget build(BuildContext context) {
    return UnicornVazio(
      type: UnicornType.geronimo,
      titulo: 'Algo deu errado',
      texto: mensagem,
      acao: onTentar,
      rotuloAcao: onTentar == null ? null : 'Tentar de novo',
    );
  }
}

/// Tela de celebração com partículas (Sweet comemora).
class UnicornCelebracao extends StatelessWidget {
  const UnicornCelebracao({
    super.key,
    required this.titulo,
    required this.texto,
    required this.onContinuar,
    this.type = UnicornType.sweet,
  });

  final String titulo;
  final String texto;
  final VoidCallback onContinuar;
  final UnicornType type;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NBColors.papel,
      child: Stack(
        children: [
          Positioned.fill(child: IgnorePointer(child: FullScreenParticles(type: particleTypeForUnicorn(type)))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(NBSpacing.x3),
              child: Column(
                children: [
                  const Spacer(),
                  UnicornWidget(type: type, size: 180, mood: UnicornMood.celebrate),
                  const SizedBox(height: NBSpacing.xxl),
                  Text(titulo, style: NBText.tituloTela, textAlign: TextAlign.center),
                  const SizedBox(height: NBSpacing.m),
                  Text(texto, style: NBText.corpo.copyWith(color: NBColors.tintaSuave), textAlign: TextAlign.center),
                  const Spacer(),
                  FilledButton(onPressed: onContinuar, child: const Text('Continuar')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
