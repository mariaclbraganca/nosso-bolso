import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/envelopes_provider.dart';
import '../providers/usuarios_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard/dashboard_header.dart';
import '../widgets/dashboard/alert_banner.dart';
import '../widgets/dashboard/revenue_summary_card.dart';
import '../widgets/dashboard/total_balance_card.dart';
import '../widgets/dashboard/spending_velocity_card.dart';
import '../widgets/dashboard/envelope_health_summary.dart';
import '../widgets/dashboard/envelope_grid_item.dart';
import 'envelope_detail_sheet.dart';
import 'abastecer_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envelopesAsync = ref.watch(envelopesProvider);
    final saldoGeralAsync = ref.watch(saldoGeralProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(envelopesProvider.future),
        backgroundColor: AppColors.surf,
        color: AppColors.acc,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: DashboardHeader()),

            // 🚨 Alert banner (envelopes negativos)
            const SliverToBoxAdapter(child: AlertBanner()),

            const SliverToBoxAdapter(child: RevenueSummaryCard()),

            SliverToBoxAdapter(
              child: saldoGeralAsync.when(
                data: (saldo) => TotalBalanceCard(saldo: saldo),
                loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Center(child: Text('Erro: $e')),
              ),
            ),

            // 📊 Velocidade de gastos
            const SliverToBoxAdapter(child: SpendingVelocityCard()),

            // ✅⚠️🔴 Saúde dos envelopes
            const SliverToBoxAdapter(child: EnvelopeHealthSummary()),

            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 4, 14, 6),
                child: Text('ENVELOPES', style: TextStyle(fontSize: 11, color: AppColors.mu, letterSpacing: 0.8, fontWeight: FontWeight.bold)),
              ),
            ),

            envelopesAsync.when(
              data: (lista) => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.1,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => EnvelopeGridItem(
                      envelope: lista[index],
                      onTap: () => _openEnvDetail(context, lista[index], ref),
                      onAbastecer: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const AbastecerSheet(),
                      ),
                    ),
                    childCount: lista.length,
                  ),
                ),
              ),
              loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Erro: $e'))),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  void _openEnvDetail(BuildContext context, Map<String, dynamic> envelope, WidgetRef ref) {
    final perfil = ref.read(perfilUsuarioLogadoProvider).value;
    final isAdmin = perfil?['role'] == 'admin';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EnvelopeDetailSheet(envelope: envelope, isAdmin: isAdmin),
    );
  }
}
