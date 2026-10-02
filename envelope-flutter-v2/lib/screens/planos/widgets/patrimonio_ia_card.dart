import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/patrimonio_provider.dart';
import '../../../services/gemini_patrimonio_service.dart';
import '../../../widgets/unicorn/unicorn_system.dart';
import 'patrimonio_ia_widgets.dart';

/// Card de análise inteligente de portfólio pelo Astrix
class PatrimonioIACard extends ConsumerStatefulWidget {
  const PatrimonioIACard({super.key});

  @override
  ConsumerState<PatrimonioIACard> createState() => _PatrimonioIACardState();
}

class _PatrimonioIACardState extends ConsumerState<PatrimonioIACard> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final analiseAsync = ref.watch(patrimonioAnaliseProvider);
    final contas = ref.watch(patrimonioProvider).value ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.acc.withOpacity(0.25), width: 0.5),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expandido = !_expandido),
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.acc.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text('✨', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Análise do Astrix', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            contas.isEmpty ? 'Adicione contas para analisar' : 'IA analisa seus rendimentos e sugere melhorias',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    if (contas.isNotEmpty) ...[
                      if (!_expandido && analiseAsync.hasValue)
                        NotaBadge(nota: analiseAsync.value!.notaGeral),
                      if (analiseAsync.isLoading && _expandido)
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.acc))
                      else
                        Icon(_expandido ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.mu, size: 20),
                    ],
                  ],
                ),
              ),
            ),
            if (_expandido) ...[
              const Divider(height: 1, color: AppColors.bord),
              if (contas.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Registre suas contas e investimentos para receber uma análise personalizada.',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                analiseAsync.when(
                  loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: UnicornLoading()),
                  error: (e, _) => ErroAnalise(
                    erro: e is GeminiPatrimonioException ? e.message : e.toString(),
                    onRetry: () => ref.invalidate(patrimonioAnaliseProvider),
                  ),
                  data: (analise) => AnaliseConteudo(
                    analise: analise,
                    contas: contas,
                    onRefresh: () => ref.invalidate(patrimonioAnaliseProvider),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
