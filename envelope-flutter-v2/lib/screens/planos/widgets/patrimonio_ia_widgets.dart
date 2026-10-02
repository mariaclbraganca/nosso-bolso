import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/gemini_patrimonio_service.dart';
import 'patrimonio_sugestao_card.dart';

/// Badge com nota de 0 a 10 atribuída pelo Astrix
class NotaBadge extends StatelessWidget {
  final double nota;
  const NotaBadge({super.key, required this.nota});

  @override
  Widget build(BuildContext context) {
    final cor = nota >= 7.5 ? AppColors.grn : nota >= 5.0 ? AppColors.org : AppColors.red;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Text(
        '${nota.toStringAsFixed(1)}/10',
        style: AppTextStyles.caption.copyWith(color: cor, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Estado de erro na análise com botão de tentar novamente
class ErroAnalise extends StatelessWidget {
  final String erro;
  final VoidCallback onRetry;
  const ErroAnalise({super.key, required this.erro, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text('⚠️ $erro', style: AppTextStyles.caption.copyWith(color: AppColors.org), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Tentar novamente'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.acc,
              side: const BorderSide(color: AppColors.acc),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Conteúdo completo expandido da análise de IA
class AnaliseConteudo extends StatelessWidget {
  final PatrimonioAnalise analise;
  final List<Map<String, dynamic>> contas;
  final VoidCallback onRefresh;
  const AnaliseConteudo({super.key, required this.analise, required this.contas, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NotaBadge(nota: analise.notaGeral),
              const SizedBox(width: 10),
              Expanded(child: Text(analise.resumo, style: AppTextStyles.bodySm.copyWith(height: 1.5))),
            ],
          ),
          if (analise.pontosPositivos.isNotEmpty) ...[
            const SizedBox(height: 16),
            _secaoLabel('PONTOS FORTES', AppColors.grn),
            const SizedBox(height: 8),
            ...analise.pontosPositivos.map((p) => _bulletItem(p, '✅')),
          ],
          if (analise.alertas.isNotEmpty) ...[
            const SizedBox(height: 16),
            _secaoLabel('ATENÇÃO', AppColors.org),
            const SizedBox(height: 8),
            ...analise.alertas.map((a) => _bulletItem(a, '⚠️')),
          ],
          if (analise.sugestoes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _secaoLabel('SUGESTÕES DA IA', AppColors.acc),
            const SizedBox(height: 10),
            ...analise.sugestoes.map((s) => SugestaoCard(sugestao: s, contas: contas)),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onRefresh,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_rounded, size: 14, color: AppColors.mu),
                  const SizedBox(width: 4),
                  Text('Atualizar análise', style: AppTextStyles.caption.copyWith(color: AppColors.mu)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _secaoLabel(String label, Color cor) => Text(
        label,
        style: AppTextStyles.caption.copyWith(color: cor, fontWeight: FontWeight.w700, letterSpacing: 0.8),
      );

  Widget _bulletItem(String texto, String icone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icone, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: AppTextStyles.caption.copyWith(color: AppColors.tx, height: 1.5))),
        ],
      ),
    );
  }
}
