import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/unicorn/unicorn_system.dart';
import '../widgets/unicorn/particle_system.dart';

class UnicornSplashScreen extends StatefulWidget {
  static bool _shown = false;
  static bool get hasShown => _shown;

  /// Rearma o splash para um novo login (chamar no logout) — senão o próximo
  /// usuário no mesmo aparelho não veria o splash, pois _shown fica true em RAM.
  static void resetParaNovoLogin() => _shown = false;

  const UnicornSplashScreen({super.key});

  @override
  State<UnicornSplashScreen> createState() => _UnicornSplashScreenState();
}

class _UnicornSplashScreenState extends State<UnicornSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  Timer? _navTimer;

  static const _data = [
    (UnicornType.astrix,   AstrixMood.wave,      'Astrix',   '💜',
     'Guardião das finanças! Vamos organizar cada centavo juntos?'),
    (UnicornType.sweet,    AstrixMood.idle,      'Sweet',    '🌸',
     'Com carinho cuido da sua saúde e bem-estar todos os dias!'),
    (UnicornType.happy,    AstrixMood.celebrate, 'Happy',    '⭐',
     'Foco total! Juntos vamos superar todas as metas!'),
    (UnicornType.geronimo, AstrixMood.idle,      'Geronimo', '🌀',
     'YOOOO! Esse app vai mudar sua vida! Bora nessa!'),
  ];

  static const _starts = [0.0, 0.20, 0.40, 0.60];

  @override
  void initState() {
    super.initState();
    UnicornSplashScreen._shown = true;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
    _navTimer = Timer(const Duration(milliseconds: 9000), _navigate);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _navTimer?.cancel();
    super.dispose();
  }

  void _navigate() {
    _navTimer?.cancel();
    if (!mounted) return;
    // Vai para o '/gate' (AuthGate) em vez de '/home' direto — o gate reavalia a
    // sessão e decide entre Login/Onboarding/Home. Como _shown já é true aqui, o
    // gate cai direto na Home (sem re-mostrar o splash).
    Navigator.of(context).pushReplacementNamed('/gate');
  }

  Animation<double> _cardAnim(int i) => CurvedAnimation(
        parent: _ctrl,
        curve: Interval(
          _starts[i],
          (_starts[i] + 0.45).clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final titleAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    final footerAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.78, 1.0, curve: Curves.easeIn),
    );

    return GestureDetector(
      onTap: _navigate,
      child: Scaffold(
        backgroundColor: const Color(0xFF050510),
        body: Stack(
          children: [
            const Positioned.fill(
              child: FullScreenParticles(type: ParticleType.teamBurst),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
                child: Column(
                  children: [
                    FadeTransition(
                      opacity: titleAnim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, -0.4),
                          end: Offset.zero,
                        ).animate(titleAnim),
                        child: Column(
                          children: [
                            const Text(
                              'Nosso Time Chegou!',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Seu esquadrão de apoio pessoal',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(child: _card(0, _cardAnim(0))),
                                const SizedBox(width: 10),
                                Expanded(child: _card(1, _cardAnim(1))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(child: _card(2, _cardAnim(2))),
                                const SizedBox(width: 10),
                                Expanded(child: _card(3, _cardAnim(3))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    FadeTransition(
                      opacity: footerAnim,
                      child: Text(
                        'Toque para entrar',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(int i, Animation<double> anim) {
    final d = _data[i];
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final v = anim.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - v)),
            child: _UnicornCard(
              type: d.$1,
              mood: d.$2,
              name: d.$3,
              badge: d.$4,
              message: d.$5,
            ),
          ),
        );
      },
    );
  }
}

class _UnicornCard extends StatelessWidget {
  final UnicornType type;
  final AstrixMood mood;
  final String name;
  final String badge;
  final String message;

  const _UnicornCard({
    required this.type,
    required this.mood,
    required this.name,
    required this.badge,
    required this.message,
  });

  static Color _accent(UnicornType t) => switch (t) {
        UnicornType.astrix   => const Color(0xFFAB47FF),
        UnicornType.sweet    => const Color(0xFFFF8FAB),
        UnicornType.happy    => const Color(0xFFFFCA28),
        UnicornType.geronimo => const Color(0xFFFF6D00),
      };

  @override
  Widget build(BuildContext context) {
    final accent = _accent(type);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.38), width: 0.8),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.12), blurRadius: 14),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withOpacity(0.22), width: 0.5),
            ),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 10, height: 1.4),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          UnicornWidget(type: type, mood: mood, size: 70),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(badge, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                name,
                style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
