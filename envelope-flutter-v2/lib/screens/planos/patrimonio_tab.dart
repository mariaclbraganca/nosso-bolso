import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/patrimonio_provider.dart';
import '../../providers/pin_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../widgets/unicorn/unicorn_system.dart';
import 'widgets/form_conta_patrimonio_sheet.dart';
import 'widgets/patrimonio_bloqueado.dart';
import 'widgets/patrimonio_conta_card.dart';
import 'widgets/patrimonio_grafico_evolucao.dart';
import 'widgets/patrimonio_ia_card.dart';
import 'widgets/patrimonio_metas_com_prazo.dart';

/// Aba de gestão de contas, investimentos e patrimônio líquido familiar
class PatrimonioTab extends ConsumerWidget {
  const PatrimonioTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinDesbloqueado = ref.watch(pinDesbloqueadoProvider);
    final pinConfigurado = ref.watch(pinConfiguradoProvider);

    if (!pinDesbloqueado) {
      return PatrimonioBloqueado(pinConfigurado: pinConfigurado.asData?.value ?? true);
    }
    return const _PatrimonioConteudo();
  }
}

class _PatrimonioConteudo extends ConsumerStatefulWidget {
  const _PatrimonioConteudo();

  @override
  ConsumerState<_PatrimonioConteudo> createState() => _PatrimonioConteudoState();
}

class _PatrimonioConteudoState extends ConsumerState<_PatrimonioConteudo> {
  bool _snapshotSalvo = false;

  Future<void> _salvarSnapshotSeNecessario(List<Map<String, dynamic>> contas) async {
    if (_snapshotSalvo || contas.isEmpty) return;
    final perfil = ref.read(perfilUsuarioLogadoProvider).value;
    if (perfil == null) return;
    _snapshotSalvo = true;
    final familiaId = perfil['familia_id'] as String? ?? '';
    await salvarSnapshotMesAtual(contas, familiaId);
    if (mounted) ref.invalidate(snapshotsPatrimonioProvider);
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(patrimonioProvider, (_, next) {
      final contas = next.value;
      if (contas != null && contas.isNotEmpty) {
        _salvarSnapshotSeNecessario(contas);
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final contasAsync = ref.watch(patrimonioProvider);
    final total = ref.watch(totalPatrimonioProvider);
    final evolucao = ref.watch(evolucaoPatrimonioProvider);
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.card, AppColors.acc.withOpacity(0.08)],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: AppColors.acc.withOpacity(0.2), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Icon(Icons.account_balance_rounded, color: AppColors.acc, size: 16),
                      const SizedBox(width: 8),
                      Text('Patrimônio total', style: AppTextStyles.caption.copyWith(color: AppColors.acc)),
                    ]),
                    InkWell(
                      onTap: () {
                        ref.read(pinNotifierProvider.notifier).bloquear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🔒 Patrimônio bloqueado com sucesso.'),
                            backgroundColor: AppColors.surf,
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surf,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.bord, width: 0.5),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline_rounded, color: AppColors.mu, size: 14),
                            SizedBox(width: 4),
                            Text('Bloquear', style: TextStyle(color: AppColors.mu, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(fmt.format(total), style: AppTextStyles.display.copyWith(color: AppColors.tx)),
                const SizedBox(height: 4),
                Text(
                  '${contasAsync.value?.length ?? 0} conta${(contasAsync.value?.length ?? 0) == 1 ? '' : 's'} registrada${(contasAsync.value?.length ?? 0) == 1 ? '' : 's'}',
                  style: AppTextStyles.caption,
                ),
                if (evolucao.length >= 2) ...[
                  const SizedBox(height: 20),
                  GraficoEvolucao(evolucao: evolucao, fmt: fmt),
                ],
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        const SliverToBoxAdapter(child: PatrimonioIACard()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Contas e investimentos', style: AppTextStyles.titleSm),
                GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const FormContaPatrimonioSheet(),
                  ),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.acc.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.acc.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.add_rounded, color: AppColors.acc, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        contasAsync.when(
          loading: () => const SliverToBoxAdapter(child: UnicornLoading()),
          error: (e, _) => SliverToBoxAdapter(
            child: Center(child: Text('Erro: $e', style: TextStyle(color: AppColors.red))),
          ),
          data: (contas) {
            if (contas.isEmpty) {
              return const SliverToBoxAdapter(
                child: UnicornEmpty(
                  type: UnicornType.astrix,
                  title: 'Nenhuma conta ainda',
                  subtitle: 'Toque em + para registrar sua primeira conta ou investimento',
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: contas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => ContaCard(conta: contas[i]),
              ),
            );
          },
        ),
        SliverToBoxAdapter(child: MetasComPrazo(contasAsync: contasAsync)),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}
