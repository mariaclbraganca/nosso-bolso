import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/mes_provider.dart';
import '../../providers/transacoes_provider.dart';
import '../../providers/fixos_provider.dart';
import '../../providers/envelopes_provider.dart';

class ResumoMensalScreen extends ConsumerWidget {
  const ResumoMensalScreen({super.key});

  static final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesAtualProvider);
    final mesTitulo = mesLabelLongo(mes);
    final mesAnt = mesAnterior(mes);

    final todasTx = ref.watch(transacoesComDetalhesProvider);
    final fixos = ref.watch(fixosMesAtualProvider);
    final envelopes = ref.watch(envelopesProvider).value ?? [];

    // Stats do mês atual
    final statsAtual = ref.watch(statsPorMesProvider(mes));
    // Stats do mês anterior (usa o stream bruto)
    final statsAnt = ref.watch(statsPorMesProvider(mesAnt));

    final totalFixos = fixos.fold<double>(0, (s, f) => s + ((f['valor'] as num?)?.toDouble() ?? 0));
    final fixosPagos = fixos.where((f) => f['pago'] == true).toList();
    final totalFixosPagos = fixosPagos.fold<double>(0, (s, f) => s + ((f['valor'] as num?)?.toDouble() ?? 0));

    final saldo = statsAtual.totalReceita - statsAtual.totalDespesa - totalFixosPagos;

    // Top 5 despesas
    final despesas = todasTx.where((t) => t['tipo'] == 'despesa').toList()
      ..sort((a, b) => ((b['valor'] as num?)?.toDouble() ?? 0)
          .compareTo((a['valor'] as num?)?.toDouble() ?? 0));
    final top5 = despesas.take(5).toList();

    // Gastos por envelope
    final Map<String, double> gastosPorEnv = {};
    for (final t in todasTx.where((t) => t['tipo'] == 'despesa')) {
      final envId = t['envelope_id']?.toString() ?? '';
      gastosPorEnv[envId] = (gastosPorEnv[envId] ?? 0) + ((t['valor'] as num?)?.toDouble() ?? 0);
    }

    // Mapa de orcamento por envelope (saldo_atual + gastos = orcamento aproximado)
    final Map<String, double> orcamentoPorEnv = {};
    for (final e in envelopes) {
      final id = e['id']?.toString() ?? '';
      final saldoEnv = (e['saldo_atual'] as num?)?.toDouble() ?? 0;
      final gasto = gastosPorEnv[id] ?? 0;
      orcamentoPorEnv[id] = saldoEnv + gasto;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePad, 16, AppSpacing.pagePad, 16,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surf,
                border: Border(bottom: BorderSide(color: AppColors.bord, width: 0.5)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.arrow_back_rounded, color: AppColors.tx, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Resumo', style: AppTextStyles.caption),
                        Text(mesTitulo, style: AppTextStyles.titleSm),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Conteúdo
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePad, 20, AppSpacing.pagePad, 40,
                ),
                children: [

                  // ── Visão Geral ──────────────────────────────────────────────
                  _SectionHeader(titulo: 'Visão Geral', icon: Icons.bar_chart_rounded),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDeco(),
                    child: Column(
                      children: [
                        _ResumoRow(
                          label: 'Receita total',
                          valor: statsAtual.totalReceita,
                          cor: AppColors.grn,
                        ),
                        const Divider(color: AppColors.bord, height: 20),
                        _ResumoRow(
                          label: 'Fixos do mês',
                          valor: totalFixos,
                          cor: AppColors.org,
                        ),
                        const SizedBox(height: 8),
                        _ResumoRow(
                          label: 'Despesas variáveis',
                          valor: statsAtual.totalDespesa,
                          cor: AppColors.red,
                        ),
                        const Divider(color: AppColors.bord, height: 20),
                        _ResumoRow(
                          label: 'Total gasto',
                          valor: statsAtual.totalDespesa + totalFixosPagos,
                          cor: AppColors.mu,
                        ),
                        const SizedBox(height: 8),
                        _ResumoRow(
                          label: 'Saldo',
                          valor: saldo,
                          cor: saldo >= 0 ? AppColors.acc : AppColors.red,
                          destaque: true,
                          sufixo: saldo >= 0 ? ' ✅' : ' ⚠️',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sectionGap),

                  // ── Fixos do mês ─────────────────────────────────────────────
                  _SectionHeader(
                    titulo: 'Fixos do mês',
                    icon: Icons.repeat_rounded,
                    badge: '${fixosPagos.length}/${fixos.length}',
                  ),
                  const SizedBox(height: 12),
                  if (fixos.isEmpty)
                    _EmptyItem(label: 'Nenhum fixo neste mês')
                  else
                    ...fixos.map((f) {
                      final nome = f['nome']?.toString() ?? '—';
                      final val = (f['valor'] as num?)?.toDouble() ?? 0;
                      final pago = f['pago'] == true;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                color: pago ? AppColors.grn : AppColors.org,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(nome, style: AppTextStyles.bodySm)),
                            Text(
                              _fmt.format(val),
                              style: AppTextStyles.monoSm.copyWith(color: AppColors.mu),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              pago ? '✅' : '⏳',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: AppSpacing.sectionGap),

                  // ── Top 5 Despesas ───────────────────────────────────────────
                  _SectionHeader(titulo: 'Top 5 Despesas', icon: Icons.trending_up_rounded),
                  const SizedBox(height: 12),
                  if (top5.isEmpty)
                    _EmptyItem(label: 'Nenhuma despesa neste mês')
                  else
                    ...top5.asMap().entries.map((entry) {
                      final i = entry.key;
                      final t = entry.value;
                      final val = (t['valor'] as num?)?.toDouble() ?? 0;
                      final desc = t['descricao']?.toString() ?? '—';
                      final envNome = (t['envelopes']?['nome_envelope'] as String?) ?? '—';
                      final envEmoji = (t['envelopes']?['emoji'] as String?) ?? '💰';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 22, height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.red.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.red,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(envEmoji, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    desc,
                                    style: AppTextStyles.bodySm.copyWith(
                                        fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(envNome, style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            Text(
                              _fmt.format(val),
                              style: AppTextStyles.monoSm.copyWith(color: AppColors.red),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: AppSpacing.sectionGap),

                  // ── Por envelope ─────────────────────────────────────────────
                  _SectionHeader(titulo: 'Por Envelope', icon: Icons.folder_outlined),
                  const SizedBox(height: 12),
                  if (gastosPorEnv.isEmpty)
                    _EmptyItem(label: 'Nenhuma despesa neste mês')
                  else
                    ...envelopes
                        .where((e) => gastosPorEnv.containsKey(e['id']?.toString()))
                        .map((e) {
                      final id = e['id']?.toString() ?? '';
                      final nome = e['nome_envelope']?.toString() ?? '—';
                      final emoji = e['emoji']?.toString() ?? '💰';
                      final gasto = gastosPorEnv[id] ?? 0;
                      final orcamento = orcamentoPorEnv[id] ?? 0;
                      final pct = orcamento > 0 ? (gasto / orcamento).clamp(0.0, 2.0) : 0.0;
                      final pctDisplay = orcamento > 0 ? gasto / orcamento : 0.0;
                      final Color barColor = pctDisplay < 0.8
                          ? AppColors.acc
                          : pctDisplay < 1.0
                              ? AppColors.org
                              : AppColors.red;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(emoji, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(nome, style: AppTextStyles.bodySm),
                                ),
                                Text(
                                  _fmt.format(gasto),
                                  style: AppTextStyles.monoSm.copyWith(color: barColor),
                                ),
                                if (pctDisplay > 1.0)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Text(
                                      'Estourado!',
                                      style: AppTextStyles.caption.copyWith(color: AppColors.red),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct.clamp(0.0, 1.0),
                                minHeight: 5,
                                backgroundColor: AppColors.bord,
                                valueColor: AlwaysStoppedAnimation(barColor),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: AppSpacing.sectionGap),

                  // ── Comparativo com mês anterior ─────────────────────────────
                  _SectionHeader(titulo: 'Comparativo', icon: Icons.compare_arrows_rounded),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDeco(),
                    child: Column(
                      children: [
                        // Header da tabela
                        Row(
                          children: [
                            const Expanded(child: SizedBox()),
                            Expanded(
                              child: Text(
                                mesLabel(mesAnt),
                                style: AppTextStyles.caption,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                mesLabel(mes),
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.acc),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 24),
                          ],
                        ),
                        const Divider(color: AppColors.bord, height: 16),

                        _ComparativoRow(
                          label: 'Receita',
                          antigo: statsAnt.totalReceita,
                          atual: statsAtual.totalReceita,
                          melhorQuandoMaior: true,
                        ),
                        const SizedBox(height: 10),
                        _ComparativoRow(
                          label: 'Gastos',
                          antigo: statsAnt.totalDespesa,
                          atual: statsAtual.totalDespesa,
                          melhorQuandoMaior: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static BoxDecoration _cardDeco() => BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord, width: 0.5),
      );
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String titulo;
  final IconData icon;
  final String? badge;

  const _SectionHeader({required this.titulo, required this.icon, this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.acc, size: 16),
        const SizedBox(width: 6),
        Text(titulo, style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600)),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.acc.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(badge!, style: AppTextStyles.caption.copyWith(color: AppColors.acc)),
          ),
        ],
      ],
    );
  }
}

class _ResumoRow extends StatelessWidget {
  final String label;
  final double valor;
  final Color cor;
  final bool destaque;
  final String? sufixo;

  const _ResumoRow({
    required this.label,
    required this.valor,
    required this.cor,
    this.destaque = false,
    this.sufixo,
  });

  static final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  Widget build(BuildContext context) {
    final style = destaque ? AppTextStyles.mono : AppTextStyles.monoSm;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: destaque
                ? AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600)
                : AppTextStyles.bodySm,
          ),
        ),
        Text(
          '${_fmt.format(valor)}${sufixo ?? ''}',
          style: style.copyWith(color: cor),
        ),
      ],
    );
  }
}

class _ComparativoRow extends StatelessWidget {
  final String label;
  final double antigo;
  final double atual;
  final bool melhorQuandoMaior;

  const _ComparativoRow({
    required this.label,
    required this.antigo,
    required this.atual,
    required this.melhorQuandoMaior,
  });

  static final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  Widget build(BuildContext context) {
    final melhorou = melhorQuandoMaior ? atual > antigo : atual < antigo;
    final igual = atual == antigo;
    final cor = igual ? AppColors.mu : melhorou ? AppColors.acc : AppColors.red;
    final icon = igual
        ? Icons.remove_rounded
        : melhorou
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;

    return Row(
      children: [
        Expanded(
          child: Text(label, style: AppTextStyles.bodySm),
        ),
        Expanded(
          child: Text(
            _fmt.format(antigo),
            style: AppTextStyles.monoSm.copyWith(color: AppColors.mu),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Text(
            _fmt.format(atual),
            style: AppTextStyles.monoSm.copyWith(color: AppColors.tx),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          width: 24,
          child: Icon(icon, color: cor, size: 16),
        ),
      ],
    );
  }
}

class _EmptyItem extends StatelessWidget {
  final String label;
  const _EmptyItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(label, style: AppTextStyles.caption),
    );
  }
}
