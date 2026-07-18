import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/unicorn/unicorn_system.dart';

// Descrição estática das fases para exibição educacional
class _FaseInfo {
  final String emoji;
  final String faixaLabel;
  final String nome;
  final String descricao;
  final Color cor;
  final double inicioHoras;
  final double fimHoras;

  const _FaseInfo({
    required this.emoji,
    required this.faixaLabel,
    required this.nome,
    required this.descricao,
    required this.cor,
    required this.inicioHoras,
    required this.fimHoras,
  });
}

const _kFases = [
  _FaseInfo(
    emoji: '🔵',
    faixaLabel: '0–4h',
    nome: 'Absorção',
    descricao:
        'Insulina alta, digestão ativa. Corpo usa glicose como combustível.',
    cor: AppColors.blu,
    inicioHoras: 0,
    fimHoras: 4,
  ),
  _FaseInfo(
    emoji: '🟢',
    faixaLabel: '4–12h',
    nome: 'Glicogênio',
    descricao:
        'Insulina cai. Corpo usa reservas de glicogênio no fígado e músculos.',
    cor: AppColors.acc,
    inicioHoras: 4,
    fimHoras: 12,
  ),
  _FaseInfo(
    emoji: '🟠',
    faixaLabel: '12–18h',
    nome: '🔥 Queima de gordura',
    descricao:
        'Lipólise ativa. Seu corpo decompõe gordura em ácidos graxos para energia. Clareza mental aumenta.',
    cor: AppColors.org,
    inicioHoras: 12,
    fimHoras: 18,
  ),
  _FaseInfo(
    emoji: '🟡',
    faixaLabel: '16–24h',
    nome: 'Autofagia',
    descricao:
        'Células se auto-limpam, removendo componentes danificados. Processo anti-envelhecimento.',
    cor: AppColors.gold,
    inicioHoras: 16,
    fimHoras: 24,
  ),
  _FaseInfo(
    emoji: '🟣',
    faixaLabel: '24h+',
    nome: 'HGH & Cetose',
    descricao:
        'Hormônio do crescimento aumenta 500–2000%. Cetose profunda. Para protocolos avançados.',
    cor: AppColors.pur,
    inicioHoras: 24,
    fimHoras: 999,
  ),
];

/// Tela educacional "Fases do Jejum" — exibe o que acontece no corpo em cada fase.
class JejumFasesScreen extends StatelessWidget {
  /// Horas decorridas do jejum ativo (opcional — para destacar fase atual).
  final double? horasDecorridas;

  const JejumFasesScreen({super.key, this.horasDecorridas});

  @override
  Widget build(BuildContext context) {
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fases do jejum',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.tx,
              ),
            ),
            Text(
              'O que acontece no seu corpo',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePad, 8, AppSpacing.pagePad, 120),
            children: [
              for (int i = 0; i < _kFases.length; i++)
                _buildFaseItem(_kFases[i], i, _kFases.length),
            ],
          ),
          // Unicórnio bubble canto inferior direito
          const Positioned(
            right: 16,
            bottom: 32,
            child: UnicornBubble(
              type: UnicornType.happy,
              message: 'Conhecimento é poder! 💪',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaseItem(_FaseInfo fase, int index, int total) {
    final h = horasDecorridas;
    final isAtual = h != null && h >= fase.inicioHoras && h < fase.fimHoras;
    final isPassado = h != null && h >= fase.fimHoras;
    final isFuturo = h != null && h < fase.inicioHoras;
    final isUltima = index == total - 1;

    // Tempo até esta fase
    String? tempoAte;
    final horas = h;
    if (isFuturo && horas != null) {
      final minRestantes = ((fase.inicioHoras - horas) * 60).round();
      if (minRestantes >= 60) {
        final hrs = minRestantes ~/ 60;
        final min = minRestantes % 60;
        tempoAte = min > 0 ? 'Em ${hrs}h${min}min' : 'Em ${hrs}h';
      } else {
        tempoAte = 'Em ${minRestantes}min';
      }
    }

    return Opacity(
      opacity: isFuturo ? 0.5 : 1.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot + linha vertical
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isAtual
                        ? fase.cor
                        : isPassado
                            ? fase.cor.withOpacity(0.5)
                            : fase.cor.withOpacity(0.25),
                    shape: BoxShape.circle,
                    border: isAtual
                        ? Border.all(color: fase.cor, width: 2)
                        : null,
                  ),
                ),
                if (!isUltima)
                  Container(
                    width: 2,
                    height: 80,
                    color: AppColors.bord,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Conteúdo
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isAtual
                    ? fase.cor.withOpacity(0.05)
                    : AppColors.card,
                borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                border: Border.all(
                  color: isAtual
                      ? fase.cor.withOpacity(0.35)
                      : AppColors.bord,
                  width: isAtual ? 1 : 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(fase.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        fase.faixaLabel,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.mu,
                          fontSize: 10,
                        ),
                      ),
                      const Spacer(),
                      if (isAtual)
                        _chip('AGORA', AppColors.acc)
                      else if (isPassado)
                        _chip('Passado', AppColors.mu)
                      else if (tempoAte != null)
                        _chip(tempoAte, AppColors.mu),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fase.nome,
                    style: AppTextStyles.bodySm.copyWith(
                      color: fase.cor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fase.descricao,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.tx.withOpacity(0.75),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        border: Border.all(color: cor.withOpacity(0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: cor,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
