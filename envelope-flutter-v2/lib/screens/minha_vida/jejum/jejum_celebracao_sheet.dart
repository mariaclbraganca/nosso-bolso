import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/jejum_provider.dart';
import '../../../services/jejum_api_service.dart';
import '../../../services/jejum_notification_service.dart';
import '../../../widgets/unicorn/unicorn_system.dart';

/// Sheet de celebração + micro-reflexão exibido ao concluir um jejum.
/// "Você cuidou de você mesma hoje. Isso é tudo." — nunca fala de peso.
/// Coleta sentimento e o que ajudou (ambos opcionais) e finaliza como 'completo'.
class JejumCelebracaoSheet extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;
  final String registroId;
  final Duration duracao;

  const JejumCelebracaoSheet({
    super.key,
    required this.membroId,
    required this.familiaId,
    required this.registroId,
    required this.duracao,
  });

  @override
  ConsumerState<JejumCelebracaoSheet> createState() =>
      _JejumCelebracaoSheetState();
}

class _JejumCelebracaoSheetState extends ConsumerState<JejumCelebracaoSheet> {
  String? _sentimento;
  final Set<String> _ajudou = {};
  bool _salvando = false;

  static const _sentimentos = [
    ('leve', '😊 Leve e bem'),
    ('dificuldade', '😤 Com dificuldade'),
    ('cansada_firme', '😴 Cansada mas firme'),
    ('energia', '⚡ Com energia!'),
  ];

  static const _ajudas = [
    ('hidratacao', '💧 Hidratação'),
    ('cafe', '☕ Café'),
    ('app', '📱 App'),
    ('parceiro', '👭 Parceiro'),
    ('musica', '🎵 Música'),
    ('exercicio', '🏃 Exercício'),
  ];

  String get _duracaoFmt {
    final h = widget.duracao.inHours;
    final m = widget.duracao.inMinutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePad, 12, AppSpacing.pagePad,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.bord,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Celebração ────────────────────────────────────────────
            const Center(
                child: UnicornWidget(type: UnicornType.sweet, size: 72)),
            const SizedBox(height: 8),
            Center(
              child: Text('$_duracaoFmt completados!',
                  style: AppTextStyles.title.copyWith(
                    fontSize: 20,
                    color: AppColors.acc,
                    fontWeight: FontWeight.w800,
                  )),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Você cuidou de você mesma hoje.\nIsso é tudo.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.mu,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: AppColors.bord, height: 1),
            const SizedBox(height: 18),

            // ── Como se sentiu ────────────────────────────────────────
            Text('Como você se sentiu?',
                style: AppTextStyles.bodySm
                    .copyWith(fontWeight: FontWeight.bold)),
            Text('Opcional · ajuda o unicórnio a entender você',
                style: AppTextStyles.caption),
            const SizedBox(height: 10),
            ..._sentimentos.map((s) {
              final sel = _sentimento == s.$1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _sentimento = sel ? null : s.$1);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.acc.withOpacity(0.08)
                          : AppColors.surf,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusBtn),
                      border: Border.all(
                        color: sel ? AppColors.acc : AppColors.bord,
                        width: sel ? 1.2 : 0.8,
                      ),
                    ),
                    child: Center(
                      child: Text(s.$2,
                          style: AppTextStyles.bodySm.copyWith(
                            color: sel ? AppColors.acc : AppColors.tx,
                            fontWeight:
                                sel ? FontWeight.w700 : FontWeight.normal,
                          )),
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // ── O que ajudou ──────────────────────────────────────────
            Text('O que te ajudou hoje?',
                style: AppTextStyles.bodySm
                    .copyWith(fontWeight: FontWeight.bold)),
            Text('Opcional · vai melhorar seus próximos jejuns',
                style: AppTextStyles.caption),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _ajudas.map((a) {
                final sel = _ajudou.contains(a.$1);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      sel ? _ajudou.remove(a.$1) : _ajudou.add(a.$1);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.acc.withOpacity(0.15)
                          : AppColors.surf,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? AppColors.acc : AppColors.bord,
                        width: 0.8,
                      ),
                    ),
                    child: Text(a.$2,
                        style: AppTextStyles.caption.copyWith(
                          color: sel ? AppColors.acc : AppColors.mu,
                          fontWeight:
                              sel ? FontWeight.w700 : FontWeight.normal,
                          fontSize: 11,
                        )),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Ações ─────────────────────────────────────────────────
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _salvando ? null : () => _finalizar(pular: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.acc,
                  foregroundColor: AppColors.bg,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                  ),
                ),
                child: Text(_salvando ? 'Salvando…' : 'Finalizar ✨',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _salvando ? null : () => _finalizar(pular: true),
              child: Text('Pular reflexão',
                  style: AppTextStyles.caption.copyWith(color: AppColors.mu)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finalizar({required bool pular}) async {
    HapticFeedback.mediumImpact();
    setState(() => _salvando = true);
    try {
      // O essencial: salvar no banco (com timeout de segurança).
      await JejumApiService.finalizar(
        widget.registroId,
        status: 'completo',
        sentimento: pular ? null : _sentimento,
        oQueAjudou: pular ? null : _ajudou.toList(),
      ).timeout(const Duration(seconds: 20));

      ref.invalidate(jejumHistoricoProvider(widget.membroId));
      ref.invalidate(jejumConfigProvider(
          (membroId: widget.membroId, familiaId: widget.familiaId)));

      // Limpa a notificação SEM bloquear o fechamento da tela (fire-and-forget).
      JejumNotificationService.encerrar();

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao finalizar: ${'$e'.replaceFirst('Exception: ', '')}'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }
}
