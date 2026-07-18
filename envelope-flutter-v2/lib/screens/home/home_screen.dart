import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/envelopes_provider.dart';
import '../../providers/fixos_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../providers/mes_provider.dart';
import '../../providers/transacoes_provider.dart';
import '../../widgets/monitor_ia_card.dart';
import '../../widgets/unicorn/unicorn_system.dart';
import '../sheets/envelope_detail_sheet.dart';
import '../sheets/form_envelope_sheet.dart';
import '../config/config_hub_screen.dart';
import '../../services/notification_service.dart';
import '../../services/ifood_notification_service.dart';
import '../sheets/abastecer_sheet.dart';
import 'widgets/jejum_chip_home.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<String> _negativosNotificados = {};
  bool _temPermissaoNotif = true; // otimista até checar

  @override
  void initState() {
    super.initState();
    _verificarPermissao();
  }

  Future<void> _verificarPermissao() async {
    final ok = await IfoodNotificationService.temPermissao();
    if (mounted) setState(() => _temPermissaoNotif = ok);
  }

  @override
  Widget build(BuildContext context) {
    // Monitora mudanças nos envelopes para disparar notificação quando negativo.
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
      envelopesProvider,
      (_, next) {
        final envelopes = next.asData?.value;
        if (envelopes == null) return;
        for (final env in envelopes) {
          final id = env['id'] as String?;
          if (id == null) continue;
          final saldo = (env['saldo_atual'] as num?)?.toDouble() ?? 0.0;
          final nome = env['nome_envelope'] as String? ?? 'Envelope';
          if (saldo < 0) {
            if (!_negativosNotificados.contains(id)) {
              _negativosNotificados.add(id);
              NotificationService.notificarEnvelopeNegativo(
                envelopeId: id,
                nomeEnvelope: nome,
                saldoAtual: saldo,
              );
            }
          } else {
            // Remove do set quando volta ao positivo — permitirá nova notificação
            // caso fique negativo novamente numa sessão futura.
            _negativosNotificados.remove(id);
          }
        }
      },
    );

    final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
    final nome = (perfil?['nome'] as String? ?? 'você').split(' ').first;
    final membroId = perfil?['id'] as String?;
    final familiaId = perfil?['familia_id'] as String?;
    final envelopesAsync = ref.watch(envelopesProvider);
    final saldoLivre = ref.watch(saldoLivreProvider);
    final mes = ref.watch(mesAtualProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(envelopesProvider.future),
        color: AppColors.acc,
        backgroundColor: AppColors.surf,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(nome: nome, mes: mes, ref: ref)),
            SliverToBoxAdapter(
              child: _SaldoCard(saldo: saldoLivre),
            ),
            if (membroId != null && familiaId != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.cardGap),
                  child: JejumChipHome(
                    membroId: membroId,
                    familiaId: familiaId,
                  ),
                ),
              ),
            if (saldoLivre > 0)
              SliverToBoxAdapter(
                child: _CardDistribuir(
                  saldo: saldoLivre,
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AbastecerSheet(),
                  ),
                ),
              ),
            if (!_temPermissaoNotif)
              SliverToBoxAdapter(
                child: _BannerPermissaoNotif(
                  onConceder: () async {
                    await IfoodNotificationService.solicitarPermissao();
                    _verificarPermissao();
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.cardGap)),
            SliverToBoxAdapter(child: _HistoricoMiniChart(mesAtual: mes)),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.cardGap)),
            const SliverToBoxAdapter(child: MonitorIACard()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sectionGap)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePad),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Envelopes', style: AppTextStyles.titleSm),
                    const Spacer(),
                    Text(
                      mesLabelLongo(mes),
                      style: AppTextStyles.caption.copyWith(color: AppColors.acc),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const FormEnvelopeSheet(),
                        );
                      },
                      child: Container(
                        width: 32,
                        height: 32,
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
            envelopesAsync.when(
              data: (envelopes) {
                if (envelopes.isEmpty) {
                  return SliverToBoxAdapter(
                    child: UnicornEmpty(
                      type: UnicornType.astrix,
                      title: 'Nenhum envelope ainda',
                      subtitle: 'Toque em + para criar seu primeiro envelope',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePad),
                  sliver: SliverList.separated(
                    itemCount: envelopes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.cardGap),
                    itemBuilder: (_, i) => _EnvelopeCard(envelope: envelopes[i]),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(child: UnicornLoading()),
              error: (e, _) => SliverToBoxAdapter(child: _ErrorCard('Erro ao carregar envelopes')),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String nome;
  final String mes;
  final WidgetRef ref;

  const _Header({required this.nome, required this.mes, required this.ref});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(AppSpacing.pagePad, h + 16, AppSpacing.pagePad, 20),
          decoration: const BoxDecoration(
            color: AppColors.surf,
            border: Border(bottom: BorderSide(color: AppColors.bord, width: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_saudacao(), style: AppTextStyles.caption),
                    const SizedBox(height: 2),
                    Text(nome, style: AppTextStyles.title.copyWith(fontSize: 26)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.acc.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.acc.withOpacity(0.3)),
                      ),
                      child: Text(
                        mesLabelLongo(mes),
                        style: AppTextStyles.caption.copyWith(color: AppColors.acc),
                      ),
                    ),
                  ],
                ),
              ),
              UnicornWidget(type: UnicornType.astrix, size: 90, mood: AstrixMood.wave),
            ],
          ),
        ),
        Positioned(
          top: h + 8,
          right: 4,
          child: IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConfigHubScreen()),
            ),
            icon: const Icon(Icons.settings_rounded, color: AppColors.mu, size: 20),
            tooltip: 'Configurações',
          ),
        ),
      ],
    );
  }

  String _saudacao() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }
}

class _SaldoCard extends ConsumerWidget {
  final double saldo;
  const _SaldoCard({required this.saldo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final isPositivo = saldo >= 0;
    final totalEnvelopes = ref.watch(envelopesProvider).value?.length ?? 0;

    return Container(
        margin: const EdgeInsets.fromLTRB(AppSpacing.pagePad, 20, AppSpacing.pagePad, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.card, AppColors.acc.withOpacity(0.06)],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(
            color: isPositivo ? AppColors.acc.withOpacity(0.2) : AppColors.red.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo disponível', style: AppTextStyles.caption),
            const SizedBox(height: 8),
            Text(
                    fmt.format(saldo),
                    style: AppTextStyles.monoLg.copyWith(color: isPositivo ? AppColors.tx : AppColors.red),
                  ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(
                  label: '$totalEnvelopes envelope${totalEnvelopes == 1 ? '' : 's'}',
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.acc,
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  label: isPositivo ? 'Saldo positivo ✓' : 'Saldo negativo ⚠',
                  icon: isPositivo ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: isPositivo ? AppColors.grn : AppColors.red,
                ),
              ],
            ),
          ],
        ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _InfoChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        border: Border.all(color: color.withOpacity(0.30), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EnvelopeCard extends StatelessWidget {
  final Map<String, dynamic> envelope;
  const _EnvelopeCard({required this.envelope});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final saldo = (envelope['saldo_atual'] as num?)?.toDouble() ?? 0;
    final planejado = (envelope['valor_planejado'] as num?)?.toDouble() ?? 1;
    final pct = (saldo / planejado).clamp(0.0, 1.0);
    final emoji = envelope['emoji'] as String? ?? '📦';
    final nome = envelope['nome_envelope'] as String? ?? '';

    Color barColor;
    if (pct > 0.5) barColor = AppColors.grn;
    else if (pct > 0.2) barColor = AppColors.org;
    else barColor = AppColors.red;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => EnvelopeDetailSheet(envelope: envelope),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: barColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome, style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Meta: ${fmt.format(planejado)}', style: AppTextStyles.caption),
                    ],
                  ),
                ),
                Text(fmt.format(saldo), style: AppTextStyles.monoSm.copyWith(color: barColor)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: AppColors.bord,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(pct * 100).toStringAsFixed(0)}% do planejado', style: AppTextStyles.caption),
                if (saldo < 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                    ),
                    child: Text('Negativo', style: AppTextStyles.caption.copyWith(color: AppColors.red)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mini gráfico histórico de barras na Home ──────────────────────────────────

class _HistoricoMiniChart extends ConsumerWidget {
  final String mesAtual;
  const _HistoricoMiniChart({required this.mesAtual});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meses = <String>[];
    var m = mesAtual;
    for (int i = 0; i < 6; i++) {
      meses.insert(0, m);
      m = mesAnterior(m);
    }

    final barGroups = <BarChartGroupData>[];
    double maxVal = 1;

    for (int i = 0; i < meses.length; i++) {
      final stats = ref.watch(statsPorMesProvider(meses[i]));
      final rec  = stats.totalReceita;
      final desp = stats.totalDespesa;
      if (rec > maxVal)  maxVal = rec;
      if (desp > maxVal) maxVal = desp;
      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: rec,
            color: AppColors.grn.withOpacity(0.8),
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
          BarChartRodData(
            toY: desp,
            color: AppColors.red.withOpacity(0.8),
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ],
        barsSpace: 2,
      ));
    }

    final labels = meses.map((mes) => mesLabel(mes)).toList();
    final fmt = NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePad),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Últimos 6 meses', style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.bold, color: AppColors.tx,
          )),
          Row(children: [
            _MiniLegenda(cor: AppColors.grn, label: 'Receita'),
            const SizedBox(width: 12),
            _MiniLegenda(cor: AppColors.red, label: 'Despesa'),
          ]),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: BarChart(
            BarChartData(
              maxY: maxVal * 1.2,
              barGroups: barGroups,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, _) {
                      final idx = val.toInt();
                      if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                      final isCurrent = idx == meses.length - 1;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          labels[idx].substring(0, 3),
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 9,
                            color: isCurrent ? AppColors.acc : AppColors.mu,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surf,
                  tooltipRoundedRadius: 6,
                  getTooltipItem: (group, _, rod, rodIdx) {
                    final label = rodIdx == 0 ? 'Receita' : 'Despesa';
                    final cor   = rodIdx == 0 ? AppColors.grn : AppColors.red;
                    return BarTooltipItem(
                      '$label\n${fmt.format(rod.toY)}',
                      AppTextStyles.caption.copyWith(color: cor, fontSize: 10),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _MiniLegenda extends StatelessWidget {
  final Color cor;
  final String label;
  const _MiniLegenda({required this.cor, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: AppTextStyles.caption.copyWith(fontSize: 9)),
    ],
  );
}

Widget _ErrorCard(String msg) => Padding(
  padding: const EdgeInsets.all(AppSpacing.pagePad),
  child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.red.withOpacity(0.08),
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      border: Border.all(color: AppColors.red.withOpacity(0.2)),
    ),
    child: Text(msg, style: const TextStyle(color: AppColors.red, fontSize: 13)),
  ),
);

class _CardDistribuir extends StatelessWidget {
  final double saldo;
  final VoidCallback onTap;
  const _CardDistribuir({required this.saldo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.pagePad, 16, AppSpacing.pagePad, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.gold.withOpacity(0.12),
              AppColors.gold.withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.gold.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text('💰', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fmt.format(saldo),
                    style: AppTextStyles.mono.copyWith(
                      color: AppColors.gold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Disponível para distribuir nos envelopes',
                    style: AppTextStyles.caption.copyWith(color: AppColors.mu, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                border: Border.all(color: AppColors.gold.withOpacity(0.4)),
              ),
              child: Text(
                'Distribuir',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerPermissaoNotif extends StatelessWidget {
  final VoidCallback onConceder;
  const _BannerPermissaoNotif({required this.onConceder});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onConceder,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.pagePad, 0, AppSpacing.pagePad, AppSpacing.cardGap),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.org.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.org.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.notifications_off_rounded, color: AppColors.org, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Captura automática desativada',
                    style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.org, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Toque para permitir que o Nosso Bolso leia notificações do Nubank e iFood',
                    style: AppTextStyles.caption.copyWith(color: AppColors.mu, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.mu, size: 14),
        ]),
      ),
    );
  }
}
