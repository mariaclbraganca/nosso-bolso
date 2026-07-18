import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import 'jejum_config_sheet.dart';

/// Tela de onboarding do módulo de Jejum Intermitente.
/// Exibida apenas na primeira vez que o usuário acessa (sem protocolo configurado).
class JejumOnboardingScreen extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;

  const JejumOnboardingScreen({
    super.key,
    required this.membroId,
    required this.familiaId,
  });

  @override
  ConsumerState<JejumOnboardingScreen> createState() =>
      _JejumOnboardingScreenState();
}

class _JejumOnboardingScreenState
    extends ConsumerState<JejumOnboardingScreen> {
  final PageController _pageController = PageController();
  int _pagina = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _proximo() {
    HapticFeedback.lightImpact();
    if (_pagina < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _abrirConfig();
    }
  }

  void _abrirConfig() {
    Navigator.of(context).pop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JejumConfigSheet(
        membroId: widget.membroId,
        familiaId: widget.familiaId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Botão Pular
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _abrirConfig,
                child: Text(
                  'Pular',
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.mu),
                ),
              ),
            ),
            // Páginas
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (p) => setState(() => _pagina = p),
                children: const [
                  _PaginaBemVindo(),
                  _PaginaFases(),
                  _PaginaComoFunciona(),
                ],
              ),
            ),
            // Dots
            _DotsProgresso(pagina: _pagina, total: 3),
            const SizedBox(height: 16),
            // Botão principal
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePad),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _proximo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.acc,
                    foregroundColor: AppColors.bg,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusBtn),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _pagina < 2 ? 'Próximo' : 'Começar',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.bg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Dots ─────────────────────────────────────────────────────────────────────

class _DotsProgresso extends StatelessWidget {
  final int pagina;
  final int total;

  const _DotsProgresso({required this.pagina, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final ativo = i == pagina;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: ativo ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: ativo ? AppColors.acc : AppColors.bord,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ─── Página 1 — Boas-vindas ────────────────────────────────────────────────

class _PaginaBemVindo extends StatelessWidget {
  const _PaginaBemVindo();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePad),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Text('⏱', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          Text(
            'Jejum Intermitente',
            style: AppTextStyles.title.copyWith(
                fontSize: 24, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Uma prática milenar para reconectar com seu corpo',
            style: AppTextStyles.body.copyWith(color: AppColors.mu),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            'Não é dieta. Não é restrição.\nÉ sobre dar ao seu corpo o tempo que ele precisa para limpar, regenerar e equilibrar.',
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.mu,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pur.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border:
                  Border.all(color: AppColors.pur.withOpacity(0.3)),
            ),
            child: Text(
              '🚫 Este módulo não tem nenhum dado financeiro.\nAqui é sobre você — seu corpo, sua mente, seu ritmo.',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.pur,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Página 2 — Fases metabólicas ─────────────────────────────────────────

class _PaginaFases extends StatelessWidget {
  const _PaginaFases();

  static const _itens = [
    _FaseItem('0h', '🟠', 'Digestão ativa',
        'Corpo processando a última refeição'),
    _FaseItem('4h', '🟡', 'Glicose em queda',
        'Insulina cai, corpo busca energia nos estoques'),
    _FaseItem('8h', '🟢', 'Queima de gordura',
        'Lipólise ativa, você está queimando gordura'),
    _FaseItem('12h', '🔵', 'Cetose leve',
        'Corpos cetônicos surgem, foco mental aumenta'),
    _FaseItem('16h', '🟣', 'Autofagia',
        'Células se limpam e se regeneram'),
    _FaseItem('20h', '🟣', 'Deep autofagia',
        'Regeneração intensa, imunidade fortalecida'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'O que acontece no seu corpo',
            style: AppTextStyles.title.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 20),
          ...List.generate(_itens.length, (i) {
            final item = _itens[i];
            final isLast = i == _itens.length - 1;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline
                  SizedBox(
                    width: 36,
                    child: Column(
                      children: [
                        Text(item.dot,
                            style: const TextStyle(fontSize: 16)),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              color: AppColors.bord,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.hora,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.acc,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.nome,
                                style: AppTextStyles.bodySm.copyWith(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.descricao,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.mu),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _FaseItem {
  final String hora;
  final String dot;
  final String nome;
  final String descricao;
  const _FaseItem(this.hora, this.dot, this.nome, this.descricao);
}

// ─── Página 3 — Como funciona ─────────────────────────────────────────────

class _PaginaComoFunciona extends StatelessWidget {
  const _PaginaComoFunciona();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePad),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Seu jeito, seu ritmo',
              style: AppTextStyles.title.copyWith(fontSize: 20),
            ),
          ),
          const SizedBox(height: 20),
          const _ComoCard(
            emoji: '🎯',
            titulo: 'Protocolos prontos',
            descricao:
                '16:8, 18:6, 20:4, 24h — escolha o que se encaixa',
          ),
          const SizedBox(height: AppSpacing.cardGap),
          const _ComoCard(
            emoji: '🌿',
            titulo: 'Dia de descanso',
            descricao:
                'Se precisar parar, é descanso — nunca falha',
          ),
          const SizedBox(height: AppSpacing.cardGap),
          const _ComoCard(
            emoji: '🤝',
            titulo: 'Fast Together',
            descricao:
                'Jejue com alguém da família para mais motivação',
          ),
          const SizedBox(height: 24),
          // Unicórnio Sweet
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.acc.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border:
                  Border.all(color: AppColors.acc.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Text('🦄', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cada jejum é um presente que você dá ao seu corpo 💚',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.tx,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ComoCard extends StatelessWidget {
  final String emoji;
  final String titulo;
  final String descricao;

  const _ComoCard({
    required this.emoji,
    required this.titulo,
    required this.descricao,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: AppTextStyles.bodySm
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  descricao,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.mu, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
