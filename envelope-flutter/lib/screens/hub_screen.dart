import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/usuarios_provider.dart';
import '../providers/envelopes_provider.dart';
import '../providers/saude_provider.dart';
import 'main_navigation_screen.dart';
import 'saude/saude_navigation_screen.dart';

class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
    final nome = perfil?['nome'] as String? ?? 'Usuário';
    final membroId = perfil?['id'] as String? ?? '';
    final hoje = DateTime.now();
    final mes = _nomeMes(hoje.month);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(nome, mes, hoje.year),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FinanceiroCard(onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                    );
                  }),
                  const SizedBox(height: 12),
                  _NutricionalCard(
                    membroId: membroId,
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const SaudeNavigationScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ProximoModuloCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String nome, String mes, int ano) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Olá, ${nome.split(' ').first}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.tx,
                ),
              ),
              Text(
                '$mes / $ano',
                style: const TextStyle(fontSize: 13, color: AppColors.mu),
              ),
            ],
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.acc.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.grid_view_rounded, color: AppColors.acc, size: 20),
          ),
        ],
      ),
    );
  }

  String _nomeMes(int m) {
    const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return meses[m - 1];
  }
}

class _FinanceiroCard extends ConsumerWidget {
  final VoidCallback onTap;
  const _FinanceiroCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saldoAsync = ref.watch(saldoGeralProvider);

    return _ModuloCard(
      emoji: '💰',
      titulo: 'FINANCEIRO',
      cor: AppColors.acc,
      onTap: onTap,
      resumo: saldoAsync.when(
        data: (saldo) => 'Saldo total: R\$ ${saldo.toStringAsFixed(2).replaceAll('.', ',')}',
        loading: () => 'Carregando...',
        error: (_, __) => 'Toque para abrir',
      ),
      detalhe: 'Envelopes, extratos e fixos',
    );
  }
}

class _NutricionalCard extends ConsumerWidget {
  final String membroId;
  final VoidCallback onTap;
  const _NutricionalCard({required this.membroId, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoje = DateTime.now();
    final dataStr = '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';

    if (membroId.isEmpty) {
      return _ModuloCard(
        emoji: '🥗',
        titulo: 'NUTRICIONAL',
        cor: AppColors.grn,
        onTap: onTap,
        resumo: 'Toque para configurar seu perfil',
        detalhe: 'Refeições, hidratação e metas',
      );
    }

    final extratoAsync = ref.watch(extratoDiarioProvider((membroId: membroId, data: dataStr)));
    final perfilAsync = ref.watch(perfilMetabolicoProvider(membroId));

    final semPerfil = perfilAsync.asData?.value == null && perfilAsync is AsyncData;

    if (semPerfil) {
      return _ModuloCard(
        emoji: '🥗',
        titulo: 'NUTRICIONAL',
        cor: AppColors.grn,
        onTap: onTap,
        resumo: 'Configurar perfil nutricional',
        detalhe: 'Anamnese + cálculo metabólico',
        badge: 'Novo',
      );
    }

    final resumo = extratoAsync.when(
      data: (e) {
        final consumido = (e['calorias_consumidas_kcal'] as num?)?.toInt() ?? 0;
        final meta = (e['meta_calorica_kcal'] as num?)?.toInt() ?? 0;
        return '$consumido / $meta kcal hoje';
      },
      loading: () => 'Carregando...',
      error: (_, __) => 'Toque para abrir',
    );

    final detalhe = extratoAsync.when(
      data: (e) {
        final prot = (e['proteina_consumida_g'] as num?)?.toInt() ?? 0;
        final metaProt = (e['proteina_meta_g'] as num?)?.toInt() ?? 0;
        final falta = (metaProt - prot).clamp(0, metaProt);
        return falta > 0 ? 'Faltam ${falta}g de proteína' : 'Meta de proteína atingida!';
      },
      loading: () => 'Refeições, hidratação e metas',
      error: (_, __) => 'Refeições, hidratação e metas',
    );

    return _ModuloCard(
      emoji: '🥗',
      titulo: 'NUTRICIONAL',
      cor: AppColors.grn,
      onTap: onTap,
      resumo: resumo,
      detalhe: detalhe,
    );
  }
}

class _ProximoModuloCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Row(
        children: [
          Text('🏋️', style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXERCÍCIO FÍSICO',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mu,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Em breve — treinos, TDEE real e biofeedback',
                  style: TextStyle(fontSize: 12, color: AppColors.mu),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surf,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Em breve',
              style: TextStyle(fontSize: 10, color: AppColors.mu),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuloCard extends StatelessWidget {
  final String emoji;
  final String titulo;
  final Color cor;
  final VoidCallback onTap;
  final String resumo;
  final String detalhe;
  final String? badge;

  const _ModuloCard({
    required this.emoji,
    required this.titulo,
    required this.cor,
    required this.onTap,
    required this.resumo,
    required this.detalhe,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: cor,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(fontSize: 9, color: cor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    resumo,
                    style: const TextStyle(fontSize: 14, color: AppColors.tx, fontWeight: FontWeight.w500),
                  ),
                  Text(detalhe, style: const TextStyle(fontSize: 11, color: AppColors.mu)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cor.withOpacity(0.6), size: 22),
          ],
        ),
      ),
    );
  }
}
