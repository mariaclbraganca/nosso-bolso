import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/jejum_provider.dart';
import '../../../services/jejum_api_service.dart';
import '../../../widgets/unicorn/unicorn_system.dart';
import 'jejum_personalizado_sheet.dart';
import 'jejum_janela_sheet.dart';

/// Sheet de escolha de protocolo com sugestão da IA no topo.
/// Protocolos: 16:8 / 14:10 / 18:6 / OMAD / 5:2 / Personalizado.
/// Ao continuar, encadeia para a configuração de horário da janela.
class JejumConfigSheet extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;

  const JejumConfigSheet({
    super.key,
    required this.membroId,
    required this.familiaId,
  });

  @override
  ConsumerState<JejumConfigSheet> createState() => _JejumConfigSheetState();
}

class _JejumConfigSheetState extends ConsumerState<JejumConfigSheet> {
  String? _selecionado;
  bool _salvando = false;

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(jejumConfigProvider(
        (membroId: widget.membroId, familiaId: widget.familiaId)));
    _selecionado ??=
        configAsync.asData?.value['protocolo'] as String? ?? '16_8';

    final sugestaoAsync =
        ref.watch(jejumSugestaoProtocoloProvider(widget.membroId));

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24,
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
            Text('Configure seu jejum',
                style: AppTextStyles.caption.copyWith(color: AppColors.mu)),
            const SizedBox(height: 2),
            Text('Escolha seu protocolo',
                style: AppTextStyles.title.copyWith(fontSize: 18)),
            const SizedBox(height: 16),

            // ── Card SUGERIDO PELA IA ─────────────────────────────────
            sugestaoAsync.when(
              loading: () => _cardSugestaoSkeleton(),
              error: (_, __) => const SizedBox.shrink(),
              data: (s) => _cardSugestao(s),
            ),
            const SizedBox(height: 16),

            Text('TODOS OS PROTOCOLOS',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.mu,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                )),
            const SizedBox(height: 8),

            ...ProtocoloJejum.todos.map(_protocoloTile),

            const SizedBox(height: 8),
            _botaoContinuar(),
          ],
        ),
      ),
    );
  }

  // ── Card de sugestão da IA ──────────────────────────────────────────────────

  Widget _cardSugestao(Map<String, dynamic> s) {
    final protocolo = s['protocolo'] as String? ?? '16_8';
    final label = s['label'] as String? ?? '16:8';
    final aderencia = s['aderencia_pct'];
    final justificativa = s['justificativa'] as String? ?? '';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selecionado = protocolo);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.acc.withOpacity(0.10), AppColors.card],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.acc.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.acc.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('✨ SUGERIDO PELA IA',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.acc,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      )),
                ),
                const UnicornWidget(type: UnicornType.happy, size: 32),
              ],
            ),
            const SizedBox(height: 8),
            Text(label,
                style: AppTextStyles.mono.copyWith(
                  fontSize: 24,
                  color: AppColors.acc,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 6),
            Text(
              justificativa,
              style: AppTextStyles.caption.copyWith(height: 1.5),
            ),
            if (aderencia != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('📈 ', style: TextStyle(fontSize: 12)),
                  Text('$aderencia% de aderência estimada',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.acc,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cardSugestaoSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Row(
        children: [
          const UnicornWidget(type: UnicornType.happy, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Analisando seu perfil para sugerir o melhor protocolo…',
                style: AppTextStyles.caption),
          ),
        ],
      ),
    );
  }

  // ── Tile de protocolo ───────────────────────────────────────────────────────

  Widget _protocoloTile(ProtocoloJejum p) {
    final selecionado = p.id == _selecionado;
    final personalizado = p.horas == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: _salvando ? null : () => _tapProtocolo(p),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selecionado ? AppColors.acc.withOpacity(0.08) : AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
            border: Border.all(
              color: selecionado ? AppColors.acc : AppColors.bord,
              width: selecionado ? 1.2 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      personalizado ? '✏️ ${p.label}' : p.label,
                      style: AppTextStyles.bodySm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selecionado
                            ? AppColors.acc
                            : (personalizado ? AppColors.gold : AppColors.tx),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(p.descricao, style: AppTextStyles.caption),
                  ],
                ),
              ),
              if (selecionado)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.acc.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Selecionado',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.acc,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                      )),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: AppColors.mu),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botaoContinuar() {
    final p = ProtocoloJejum.porId(_selecionado);
    final label = p?.horas != null ? 'Continuar com ${p!.label}' : 'Continuar';
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _salvando ? null : _continuar,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.acc,
          foregroundColor: AppColors.bg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
          ),
        ),
        child: Text(_salvando ? 'Salvando…' : label,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Ações ───────────────────────────────────────────────────────────────────

  void _tapProtocolo(ProtocoloJejum p) {
    HapticFeedback.selectionClick();
    if (p.id == 'personalizado') {
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => JejumPersonalizadoSheet(
          membroId: widget.membroId,
          familiaId: widget.familiaId,
        ),
      );
      return;
    }
    setState(() => _selecionado = p.id);
  }

  Future<void> _continuar() async {
    final p = ProtocoloJejum.porId(_selecionado);
    if (p == null) return;

    if (p.id == 'personalizado') {
      _tapProtocolo(p);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _salvando = true);
    try {
      await JejumApiService.salvarConfig(widget.membroId, {
        'familia_id': widget.familiaId,
        'protocolo': p.id,
        'modalidade': 'com_meta',
      });
      ref.invalidate(jejumConfigProvider(
          (membroId: widget.membroId, familiaId: widget.familiaId)));
      if (!mounted) return;
      Navigator.pop(context);
      // Encadeia para a configuração de horário da janela
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => JejumJanelaSheet(
          membroId: widget.membroId,
          familiaId: widget.familiaId,
          protocolo: p.id,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }
}
