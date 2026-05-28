import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/astrix_provider.dart';
import '../../providers/unicorn_team.dart';
import 'astrix_painter.dart' show AstrixMood;
import 'particle_system.dart';
import 'unicorn_bubble.dart';
import 'unicorn_widget.dart';

/// Drop-in replacement for [AstrixOverlay].
/// Handles all four unicorns individually AND team moments.
/// Still listens to [astrixProvider] for full backward compatibility.
class UnicornOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const UnicornOverlay({super.key, required this.child});

  @override
  ConsumerState<UnicornOverlay> createState() => _UnicornOverlayState();
}

enum _Mode { none, individual, team }

class _UnicornOverlayState extends ConsumerState<UnicornOverlay>
    with TickerProviderStateMixin {
  _Mode          _mode = _Mode.none;
  UnicornMessage? _msg;
  TeamMoment?    _team;
  Timer?         _timer;
  late AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _fade.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── Show / dismiss ──────────────────────────────────────────────────────────

  void _showIndividual(UnicornMessage msg) {
    _timer?.cancel();
    setState(() {
      _mode = _Mode.individual;
      _msg  = msg;
      _team = null;
    });
    _fade.forward(from: 0);
    _timer = Timer(msg.duration, _dismiss);
  }

  void _showTeam(TeamMoment moment) {
    _timer?.cancel();
    setState(() {
      _mode = _Mode.team;
      _team = moment;
      _msg  = null;
    });
    _fade.forward(from: 0);
    _timer = Timer(moment.duration, _dismiss);
  }

  void _dismiss() {
    _timer?.cancel();
    _fade.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _mode = _Mode.none;
        _msg  = null;
        _team = null;
      });
      ref.read(astrixProvider.notifier).state            = null;
      ref.read(unicornTeamProvider.notifier).state       = null;
      ref.read(unicornTeamMomentProvider.notifier).state = null;
    });
  }

  // ── Mood conversion ─────────────────────────────────────────────────────────

  UnicornMood _fromAstrix(AstrixMood m) => switch (m) {
        AstrixMood.idle      => UnicornMood.idle,
        AstrixMood.wave      => UnicornMood.wave,
        AstrixMood.celebrate => UnicornMood.celebrate,
        AstrixMood.sad       => UnicornMood.sad,
        AstrixMood.thinking  => UnicornMood.thinking,
      };

  ParticleType _particleType(UnicornType? type) => switch (type) {
        UnicornType.sweet    => ParticleType.hearts,
        UnicornType.happy    => ParticleType.lightning,
        UnicornType.geronimo => ParticleType.confetti,
        _                    => ParticleType.stars,
      };

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Listen to all three providers
    ref.listen<AstrixMessage?>(astrixProvider, (_, next) {
      if (next != null) {
        _showIndividual(UnicornMessage(
          type:     UnicornType.astrix,
          text:     next.text,
          mood:     _fromAstrix(next.mood),
          duration: next.duration,
        ));
      }
    });

    ref.listen<UnicornMessage?>(unicornTeamProvider, (_, next) {
      if (next != null) _showIndividual(next);
    });

    ref.listen<TeamMoment?>(unicornTeamMomentProvider, (_, next) {
      if (next != null) _showTeam(next);
    });

    return Stack(
      children: [
        widget.child,

        // ── Full-screen particles ────────────────────────────────────────────
        if (_mode != _Mode.none)
          Positioned.fill(
            child: FadeTransition(
              opacity: _fade,
              child: FullScreenParticles(
                type: _mode == _Mode.team
                    ? ParticleType.teamBurst
                    : _particleType(_msg?.type),
              ),
            ),
          ),

        // ── Individual unicorn (bottom-right) ────────────────────────────────
        if (_mode == _Mode.individual && _msg != null)
          Positioned(
            bottom: 16,
            right:  12,
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.25),
                  end:   Offset.zero,
                ).animate(CurvedAnimation(parent: _fade, curve: Curves.easeOut)),
                child: GestureDetector(
                  onTap: _current != null ? _dismiss : null,
                  child: Column(
                    mainAxisSize:     MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, right: 6),
                        child: UnicornBubble(
                          text:      _msg!.text,
                          type:      _msg!.type,
                          onDismiss: _dismiss,
                        ),
                      ),
                      UnicornWidget(
                        type: _msg!.type,
                        mood: _msg!.mood,
                        size: 72,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── Team moment (bottom sheet) ───────────────────────────────────────
        if (_mode == _Mode.team && _team != null)
          Positioned(
            left:   0,
            right:  0,
            bottom: 0,
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.5),
                  end:   Offset.zero,
                ).animate(CurvedAnimation(parent: _fade, curve: Curves.easeOut)),
                child: _TeamMomentPanel(
                  moment:    _team!,
                  onDismiss: _dismiss,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Convenience: non-null only while a message is displayed
  UnicornMessage? get _current => _msg;
}

// ── Team moment panel ─────────────────────────────────────────────────────────

class _TeamMomentPanel extends StatelessWidget {
  final TeamMoment moment;
  final VoidCallback onDismiss;

  const _TeamMomentPanel({required this.moment, required this.onDismiss});

  static const _order = [
    UnicornType.astrix,
    UnicornType.sweet,
    UnicornType.happy,
    UnicornType.geronimo,
  ];

  static const _moods = {
    UnicornType.astrix:   UnicornMood.celebrate,
    UnicornType.sweet:    UnicornMood.love,
    UnicornType.happy:    UnicornMood.focus,
    UnicornType.geronimo: UnicornMood.chaos,
  };

  static Color _accent(UnicornType t) => switch (t) {
        UnicornType.astrix   => const Color(0xFFAB47FF),
        UnicornType.sweet    => const Color(0xFFFF8FAB),
        UnicornType.happy    => const Color(0xFFFFCA28),
        UnicornType.geronimo => const Color(0xFFFF6D00),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF080810).withOpacity(0.93),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 0.5),
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle + close button
          Row(
            children: [
              const Spacer(),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(
                  Icons.close_rounded,
                  size:  18,
                  color: Colors.white.withOpacity(0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 4 unicorns in a row, each with an optional mini bubble above
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _order.map((type) {
              final msg    = moment.messages[type];
              final accent = _accent(type);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (msg != null && msg.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxWidth: 82),
                      margin:  const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color:        accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border:       Border.all(color: accent.withOpacity(0.4), width: 0.7),
                      ),
                      child: Text(
                        msg,
                        style: const TextStyle(
                          color:  Colors.white,
                          fontSize: 9.5,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  UnicornWidget(
                    type: type,
                    mood: _moods[type]!,
                    size: 54,
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
