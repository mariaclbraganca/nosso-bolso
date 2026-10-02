import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/gemini_patrimonio_service.dart';
import '../simulador_realocacao_sheet.dart';

/// Card de sugestão inteligente individual com atalho para o simulador
class SugestaoCard extends StatelessWidget {
  final Sugestao sugestao;
  final List<Map<String, dynamic>> contas;
  const SugestaoCard({super.key, required this.sugestao, required this.contas});

  Map<String, dynamic>? _contaRelacionada() {
    final texto = '${sugestao.titulo} ${sugestao.descricao}'.toLowerCase();
    for (final c in contas) {
      final nome = (c['nome'] as String? ?? '').toLowerCase();
      final banco = (c['banco'] as String? ?? '').toLowerCase();
      if (nome.isNotEmpty && texto.contains(nome)) return c;
      if (banco.isNotEmpty && texto.contains(banco)) return c;
    }
    return null;
  }

  bool get _podeSimular =>
      sugestao.descricao.toLowerCase().contains('cdb') ||
      sugestao.descricao.toLowerCase().contains('tesouro') ||
      sugestao.descricao.toLowerCase().contains('lci') ||
      sugestao.descricao.toLowerCase().contains('lca') ||
      sugestao.descricao.toLowerCase().contains('migr') ||
      sugestao.descricao.toLowerCase().contains('transfer') ||
      sugestao.titulo.toLowerCase().contains('realoc') ||
      sugestao.titulo.toLowerCase().contains('migr');

  @override
  Widget build(BuildContext context) {
    final corImpacto = sugestao.impacto == 'alto' ? AppColors.grn : sugestao.impacto == 'medio' ? AppColors.org : AppColors.mu;
    final labelUrgencia = sugestao.urgencia == 'agora' ? '🔴 Agora' : sugestao.urgencia == 'proximo_mes' ? '🟡 Próximo mês' : '🟢 Sem pressa';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(sugestao.titulo, style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: corImpacto.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text('impacto ${sugestao.impacto}', style: AppTextStyles.caption.copyWith(color: corImpacto, fontSize: 9)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(sugestao.descricao, style: AppTextStyles.caption.copyWith(color: AppColors.tx, height: 1.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(labelUrgencia, style: AppTextStyles.caption.copyWith(fontSize: 10)),
              if (_podeSimular)
                GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => SimuladorRealocacaoSheet(contaInicial: _contaRelacionada()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.acc.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.acc.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calculate_rounded, size: 12, color: AppColors.acc),
                        const SizedBox(width: 4),
                        Text('Simular', style: AppTextStyles.caption.copyWith(color: AppColors.acc, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
