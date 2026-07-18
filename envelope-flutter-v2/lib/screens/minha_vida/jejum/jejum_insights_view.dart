import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/jejum_provider.dart';
import '../../../widgets/unicorn/unicorn_system.dart';
import 'jejum_together_sheet.dart';
import 'jejum_together_dupla_view.dart';

/// Aba Insights: observações IA da semana + card Fast Together.
/// REGRA: nenhum insight menciona peso, dinheiro ou linguagem punitiva
/// (garantido pelo prompt do backend).
class JejumInsightsView extends ConsumerWidget {
  final String membroId;
  final String familiaId;

  const JejumInsightsView({
    super.key,
    required this.membroId,
    required this.familiaId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(jejumInsightsProvider(membroId));
    final togetherAsync = ref.watch(
        jejumTogetherProvider((membroId: membroId, familiaId: familiaId)));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePad, 0, AppSpacing.pagePad, 100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Fast Together ─────────────────────────────────────────
          _buildTogetherCard(context, ref, togetherAsync),
          const SizedBox(height: AppSpacing.sectionGap),

          // ── Insights IA ───────────────────────────────────────────
          Text('Sua semana ✨',
              style: AppTextStyles.title.copyWith(fontSize: 16)),
          const SizedBox(height: AppSpacing.cardGap),
          insightsAsync.when(
            loading: () => const Center(child: UnicornLoading()),
            error: (_, __) => _cardTexto(
              'Não consegui gerar os insights agora. Tenta de novo daqui a pouco!',
            ),
            data: (dados) {
              final principal = dados['insight_principal'] as String?;
              final insights = (dados['insights'] as List?) ?? const [];
              final sugestao = dados['sugestao'] as String?;

              if (principal == null && insights.isEmpty) {
                return _cardTexto(
                  'Complete alguns jejuns e volto aqui com observações sobre a sua semana! 🦄',
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Insight principal — card destacado (Happy analisa)
                  if (principal != null && principal.isNotEmpty)
                    _cardPrincipal(principal),
                  // Insights com ícone temático colorido
                  ...insights.map((raw) {
                    final it = (raw as Map).cast<String, dynamic>();
                    return _cardInsight(
                      it['icone'] as String? ?? '💡',
                      it['titulo'] as String? ?? '',
                      it['texto'] as String? ?? '',
                      _corPorTipo(it['tipo'] as String?),
                    );
                  }),
                  if (sugestao != null && sugestao.isNotEmpty)
                    _cardSugestao(sugestao),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Fast Together ──────────────────────────────────────────────────────────

  Widget _buildTogetherCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Map<String, dynamic>?> togetherAsync,
  ) {
    final vinculo = togetherAsync.asData?.value;

    return GestureDetector(
      onTap: () => _abrirTogether(context, ref),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(
            color: vinculo != null
                ? AppColors.pur.withOpacity(0.4)
                : AppColors.bord,
            width: vinculo != null ? 1 : 0.5,
          ),
        ),
        child: vinculo == null
            ? Row(
                children: [
                  const Text('🤝', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fast Together',
                            style: AppTextStyles.bodySm.copyWith(
                              fontWeight: FontWeight.w700,
                            )),
                        Text(
                          'Convide alguém da família para jejuar junto — motivação em dobro!',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.mu),
                ],
              )
            : _buildParceiroAtivo(vinculo),
      ),
    );
  }

  Widget _buildParceiroAtivo(Map<String, dynamic> vinculo) {
    final parceiro = vinculo['parceiro'] as Map<String, dynamic>? ?? {};
    final nome = parceiro['nome'] as String? ?? '';
    final jejumAtivo = parceiro['jejum_ativo'] as Map<String, dynamic>?;
    final sequencia = parceiro['sequencia'] as int? ?? 0;
    final mensagemIa = vinculo['mensagem_ia'] as String?;

    String statusParceiro;
    if (jejumAtivo != null) {
      final inicio =
          DateTime.tryParse(jejumAtivo['iniciado_em'] ?? '')?.toLocal();
      final h = inicio != null
          ? DateTime.now().difference(inicio).inHours
          : 0;
      statusParceiro = 'em jejum há ${h}h ⏱️';
    } else {
      statusParceiro =
          sequencia > 0 ? 'sequência de $sequencia dias 🔥' : 'por aqui 🦄';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🤝', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fast Together com $nome',
                      style: AppTextStyles.bodySm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.pur,
                      )),
                  Text('$nome está $statusParceiro',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.mu),
          ],
        ),
        if (mensagemIa != null && mensagemIa.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.pur.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('💜 $mensagemIa',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.tx.withOpacity(0.85),
                )),
          ),
        ],
      ],
    );
  }

  void _abrirTogether(BuildContext context, WidgetRef ref) {
    final vinculo = ref
        .read(jejumTogetherProvider((membroId: membroId, familiaId: familiaId)))
        .asData
        ?.value;

    if (vinculo != null) {
      // Já pareado → tela rica com os dois timers
      Navigator.of(context)
          .push(MaterialPageRoute(
            builder: (_) => JejumTogetherDuplaView(
              membroId: membroId,
              familiaId: familiaId,
            ),
          ))
          .then((_) {
        ref.invalidate(
            jejumTogetherProvider((membroId: membroId, familiaId: familiaId)));
        ref.invalidate(jejumTogetherDuplaProvider(
            (membroId: membroId, familiaId: familiaId)));
      });
      return;
    }

    // Sem parceiro → sheet de convite
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JejumTogetherSheet(
        membroId: membroId,
        familiaId: familiaId,
      ),
    ).then((_) => ref.invalidate(
        jejumTogetherProvider((membroId: membroId, familiaId: familiaId))));
  }

  // ── Insight principal em destaque (Happy analisa) ───────────────────────────

  Widget _cardPrincipal(String texto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.acc.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.acc.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const UnicornWidget(type: UnicornType.happy, size: 28),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Análise de hoje',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.acc,
                        fontWeight: FontWeight.bold,
                      )),
                  Text('Baseado nos seus últimos dias',
                      style: AppTextStyles.caption.copyWith(fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(texto, style: AppTextStyles.bodySm.copyWith(height: 1.6)),
        ],
      ),
    );
  }

  // ── Insight temático com ícone colorido ─────────────────────────────────────

  Widget _cardInsight(String icone, String titulo, String texto, Color cor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(icone, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(titulo,
                    style: AppTextStyles.bodySm
                        .copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (texto.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(texto,
                style: AppTextStyles.caption.copyWith(height: 1.5)),
          ],
        ],
      ),
    );
  }

  Widget _cardSugestao(String sugestao) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pur.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
        border: Border.all(color: AppColors.pur.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(sugestao,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.pur,
                  height: 1.4,
                )),
          ),
        ],
      ),
    );
  }

  Color _corPorTipo(String? tipo) {
    switch (tipo) {
      case 'sono':
        return AppColors.blu;
      case 'proteina':
        return AppColors.org;
      case 'melhor_dia':
        return AppColors.acc;
      case 'padrao':
      case 'deficit':
        return AppColors.acc;
      default:
        return AppColors.gold;
    }
  }

  Widget _cardTexto(String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Text(texto, style: AppTextStyles.bodySm.copyWith(height: 1.4)),
    );
  }
}
