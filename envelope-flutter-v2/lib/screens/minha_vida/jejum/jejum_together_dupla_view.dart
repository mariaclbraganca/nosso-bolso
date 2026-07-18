import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/jejum_provider.dart';
import '../../../services/jejum_api_service.dart';
import '../../../widgets/unicorn/unicorn_system.dart';

/// Visão dedicada do Fast Together: os dois timers lado a lado + stats do mês.
/// Só dados POSITIVOS — interrupções do parceiro nunca aparecem.
class JejumTogetherDuplaView extends ConsumerWidget {
  final String membroId;
  final String familiaId;

  const JejumTogetherDuplaView({
    super.key,
    required this.membroId,
    required this.familiaId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duplaAsync = ref.watch(jejumTogetherDuplaProvider(
        (membroId: membroId, familiaId: familiaId)));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.mu),
        ),
        title: Text('Fast Together 👭',
            style: AppTextStyles.title.copyWith(fontSize: 18)),
      ),
      body: duplaAsync.when(
        loading: () => const Center(child: UnicornLoading()),
        error: (_, __) => Center(
          child: Text('Não consegui carregar agora.',
              style: AppTextStyles.bodySm),
        ),
        data: (dados) {
          if (dados == null) {
            return const UnicornEmpty(
              type: UnicornType.happy,
              title: 'Sem parceiro ainda',
              subtitle: 'Convide alguém da família para jejuar junto',
            );
          }
          return _conteudo(context, ref, dados);
        },
      ),
    );
  }

  Widget _conteudo(
      BuildContext context, WidgetRef ref, Map<String, dynamic> d) {
    final eu = (d['eu'] as Map?)?.cast<String, dynamic>() ?? {};
    final parc = (d['parceiro'] as Map?)?.cast<String, dynamic>() ?? {};
    final mes = (d['mes'] as Map?)?.cast<String, dynamic>() ?? {};
    final mensagemIa = d['mensagem_ia'] as String?;
    final togetherId = d['together_id'] as String?;

    final ambosEmJejum =
        eu['jejum_ativo'] != null && parc['jejum_ativo'] != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePad, 0, AppSpacing.pagePad, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Card dos dois timers ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.acc.withOpacity(0.06),
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: AppColors.acc.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Text(
                  ambosEmJejum
                      ? 'Vocês dois estão em jejum agora ✨'
                      : 'Vocês estão nessa juntos 💚',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.acc,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _pessoaTimer(eu, AppColors.acc, 'Você')),
                    Container(
                      width: 1, height: 90,
                      color: AppColors.bord,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    Expanded(
                        child: _pessoaTimer(
                            parc, AppColors.gold, parc['nome'] as String? ?? '')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Mensagem de apoio (Happy) ─────────────────────────────
          if (mensagemIa != null && mensagemIa.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.pur.withOpacity(0.06),
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                border: Border.all(color: AppColors.pur.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const UnicornWidget(type: UnicornType.happy, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Força compartilhada',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.pur,
                              fontWeight: FontWeight.bold,
                            )),
                        const SizedBox(height: 2),
                        Text(mensagemIa,
                            style: AppTextStyles.caption.copyWith(height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // ── Esse mês juntas ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: AppColors.bord, width: 0.5),
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('ESSE MÊS JUNTAS',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.mu,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        fontSize: 10,
                      )),
                ),
                const SizedBox(height: 10),
                _statLinha('Jejuns sincronizados',
                    '${mes['sincronizados'] ?? 0} dias', AppColors.acc),
                _divisor(),
                _statLinha('Melhor sequência juntas',
                    '${mes['melhor_sequencia_juntas'] ?? 0} dias 🔥',
                    AppColors.gold),
                _divisor(),
                _statLinha('Taxa combinada',
                    '${mes['taxa_combinada'] ?? 0}%', AppColors.pur),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Mandar apoio ──────────────────────────────────────────
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: togetherId == null
                  ? null
                  : () => _mandarApoio(context, togetherId),
              icon: const Icon(Icons.favorite_rounded, size: 18),
              label: Text('Mandar apoio para ${parc['nome'] ?? ''}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.acc,
                side: BorderSide(color: AppColors.acc.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pessoaTimer(Map<String, dynamic> p, Color cor, String nome) {
    final ativo = (p['jejum_ativo'] as Map?)?.cast<String, dynamic>();
    final sequencia = p['sequencia'] as int? ?? 0;
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';

    String tempo = '—';
    double progresso = 0;
    String faseNome = 'por aqui 🦄';
    if (ativo != null) {
      final inicio =
          DateTime.tryParse(ativo['iniciado_em'] ?? '')?.toLocal();
      if (inicio != null) {
        final dec = DateTime.now().difference(inicio);
        tempo = '${dec.inHours}:${(dec.inMinutes % 60).toString().padLeft(2, '0')}';
        final fase = FaseMetabolica.atual(dec);
        faseNome = '${fase.emoji} ${fase.nome}';
        final meta = (ativo['meta_horas'] as num?)?.toDouble();
        if (meta != null && meta > 0) {
          progresso = (dec.inMinutes / (meta * 60)).clamp(0.0, 1.0);
        }
      }
    } else if (sequencia > 0) {
      faseNome = 'sequência de $sequencia dias 🔥';
    }

    return Column(
      children: [
        Container(
          width: 40, height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cor.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: cor, width: 1.5),
          ),
          child: Text(inicial,
              style: TextStyle(
                  color: cor, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(height: 6),
        Text(nome,
            style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(tempo,
            style: AppTextStyles.mono.copyWith(color: cor, fontSize: 18)),
        const SizedBox(height: 2),
        Text(faseNome,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(fontSize: 9)),
        if (ativo != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 5,
              backgroundColor: AppColors.bord,
              valueColor: AlwaysStoppedAnimation(cor),
            ),
          ),
        ],
      ],
    );
  }

  Widget _statLinha(String label, String valor, Color cor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySm),
        Text(valor,
            style: AppTextStyles.monoSm.copyWith(color: cor)),
      ],
    );
  }

  Widget _divisor() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(color: AppColors.bord, height: 1),
      );

  Future<void> _mandarApoio(BuildContext context, String togetherId) async {
    HapticFeedback.mediumImpact();
    try {
      await JejumApiService.togetherMotivar(
        togetherId: togetherId,
        remetenteId: membroId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apoio enviado! 💜'),
          backgroundColor: AppColors.grn,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.org,
        ),
      );
    }
  }
}
