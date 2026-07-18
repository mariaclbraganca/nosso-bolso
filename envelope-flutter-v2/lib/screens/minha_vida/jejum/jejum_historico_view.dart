import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/jejum_provider.dart';
import '../../../widgets/unicorn/unicorn_system.dart';

/// Aba Histórico: seletor 7/30 dias · 4 KPIs · calendário mensal de consistência
/// · lista de registros. Interrupções aparecem como "dia de descanso".
class JejumHistoricoView extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;

  const JejumHistoricoView({
    super.key,
    required this.membroId,
    required this.familiaId,
  });

  @override
  ConsumerState<JejumHistoricoView> createState() => _JejumHistoricoViewState();
}

class _JejumHistoricoViewState extends ConsumerState<JejumHistoricoView> {
  int _janela = 30; // 7 ou 30 dias
  DateTime _mesVisivel = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final historicoAsync = ref.watch(jejumHistoricoProvider(widget.membroId));
    final configAsync = ref.watch(jejumConfigProvider(
        (membroId: widget.membroId, familiaId: widget.familiaId)));

    return historicoAsync.when(
      loading: () => const Center(child: UnicornLoading()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Não consegui carregar o histórico.',
                  style: AppTextStyles.bodySm),
              TextButton(
                onPressed: () =>
                    ref.invalidate(jejumHistoricoProvider(widget.membroId)),
                child: const Text('Tentar de novo',
                    style: TextStyle(color: AppColors.acc)),
              ),
            ],
          ),
        ),
      ),
      data: (dados) {
        final registros =
            (dados['registros'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final stats = dados['stats'] as Map<String, dynamic>? ?? {};
        final cfg = configAsync.asData?.value ?? {};

        if (registros.isEmpty) {
          return const UnicornEmpty(
            type: UnicornType.happy,
            title: 'Sua jornada começa aqui',
            subtitle: 'Cada jejum concluído vai aparecer nesta tela',
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePad, 0, AppSpacing.pagePad, 100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSeletorJanela(),
              const SizedBox(height: AppSpacing.cardGap),
              _buildKpis(stats, cfg),
              const SizedBox(height: AppSpacing.cardGap),
              _buildCalendario(registros),
              const SizedBox(height: AppSpacing.sectionGap),
              Text('Registros', style: AppTextStyles.title.copyWith(fontSize: 16)),
              const SizedBox(height: AppSpacing.cardGap),
              ..._registrosFiltrados(registros).map(_buildRegistroItem),
            ],
          ),
        );
      },
    );
  }

  // ── Seletor 7 / 30 dias ─────────────────────────────────────────────────────

  Widget _buildSeletorJanela() {
    Widget chip(int dias, String label) {
      final ativo = _janela == dias;
      return GestureDetector(
        onTap: () => setState(() => _janela = dias),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: ativo ? AppColors.acc.withOpacity(0.15) : AppColors.surf,
            borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
            border: Border.all(
              color: ativo ? AppColors.acc : AppColors.bord,
              width: 0.8,
            ),
          ),
          child: Text(label,
              style: AppTextStyles.caption.copyWith(
                color: ativo ? AppColors.acc : AppColors.mu,
                fontWeight: FontWeight.w700,
              )),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        chip(7, '7 dias'),
        const SizedBox(width: 8),
        chip(30, '30 dias'),
      ],
    );
  }

  // ── 4 KPIs (grid 2x2) ───────────────────────────────────────────────────────

  Widget _buildKpis(Map<String, dynamic> stats, Map<String, dynamic> cfg) {
    final total = stats['total'] as int? ?? 0;
    final completos = stats['completos'] as int? ?? 0;
    final taxa = stats['taxa_sucesso'] ?? 0;
    final duracaoMedia = stats['duracao_media_min'] as int? ?? 0;
    final mediaFmt = duracaoMedia >= 60
        ? '${duracaoMedia ~/ 60}h${(duracaoMedia % 60).toString().padLeft(2, '0')}'
        : '${duracaoMedia}min';

    final streak = cfg['sequencia_atual'] as int? ?? 0;
    final recorde = cfg['recorde_sequencia'] as int? ?? 0;
    final jokersUsados = cfg['jokers_usados'] as int? ?? 0;
    final jokersMes = cfg['joker_days_mes'] as int? ?? 4;

    return Column(
      children: [
        Row(children: [
          Expanded(
            child: _kpi('JEJUNS COMPLETOS', '$completos/$total',
                '$taxa% de sucesso', AppColors.acc),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _kpi('STREAK ATUAL', '$streak dias 🔥',
                'Recorde: $recorde dias', AppColors.gold),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _kpi('MÉDIA DIÁRIA', mediaFmt, 'por jejum', AppColors.pur),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _kpi('JOKERS USADOS', '$jokersUsados/$jokersMes 🃏',
                '${jokersMes - jokersUsados} restantes', AppColors.gold),
          ),
        ]),
      ],
    );
  }

  Widget _kpi(String label, String valor, String sub, Color cor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 9,
                color: AppColors.mu,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 5),
          Text(valor,
              style: AppTextStyles.mono.copyWith(color: cor, fontSize: 17)),
          const SizedBox(height: 2),
          Text(sub, style: AppTextStyles.caption.copyWith(fontSize: 9)),
        ],
      ),
    );
  }

  // ── Calendário mensal de consistência ───────────────────────────────────────

  Widget _buildCalendario(List<Map<String, dynamic>> registros) {
    // Melhor status por dia
    final porDia = <String, String>{};
    for (final r in registros) {
      final inicio = DateTime.tryParse(r['iniciado_em'] ?? '')?.toLocal();
      if (inicio == null) continue;
      final chave = DateFormat('yyyy-MM-dd').format(inicio);
      final status = r['status'] as String? ?? '';
      if (porDia[chave] == 'completo') continue;
      if (porDia[chave] == 'joker' && status != 'completo') continue;
      porDia[chave] = status;
    }

    final primeiroDia = DateTime(_mesVisivel.year, _mesVisivel.month, 1);
    final diasNoMes =
        DateTime(_mesVisivel.year, _mesVisivel.month + 1, 0).day;
    // Dia da semana do dia 1 (0=domingo)
    final offset = primeiroDia.weekday % 7;
    final hoje = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => setState(() => _mesVisivel = DateTime(
                    _mesVisivel.year, _mesVisivel.month - 1)),
                child: const Icon(Icons.chevron_left_rounded,
                    color: AppColors.mu, size: 20),
              ),
              Text(
                DateFormat("MMMM yyyy", 'pt_BR').format(_mesVisivel).toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              GestureDetector(
                onTap: () {
                  final prox =
                      DateTime(_mesVisivel.year, _mesVisivel.month + 1);
                  if (!prox.isAfter(DateTime(hoje.year, hoje.month))) {
                    setState(() => _mesVisivel = prox);
                  }
                },
                child: Icon(Icons.chevron_right_rounded,
                    color: _mesVisivel.isBefore(DateTime(hoje.year, hoje.month))
                        ? AppColors.mu
                        : AppColors.bord,
                    size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Cabeçalho dos dias da semana
          Row(
            children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: AppTextStyles.caption
                                .copyWith(fontSize: 9, color: AppColors.mu)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          // Grade de dias
          ..._semanas(offset, diasNoMes, porDia, hoje),
          const SizedBox(height: 10),
          Row(
            children: [
              _legenda(AppColors.acc, 'Completo'),
              const SizedBox(width: 12),
              _legenda(AppColors.gold, 'Joker 🃏'),
              const SizedBox(width: 12),
              _legenda(AppColors.blu.withOpacity(0.45), 'Descanso'),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _semanas(int offset, int diasNoMes,
      Map<String, String> porDia, DateTime hoje) {
    final celulas = <Widget?>[];
    for (var i = 0; i < offset; i++) {
      celulas.add(null);
    }
    for (var dia = 1; dia <= diasNoMes; dia++) {
      final data = DateTime(_mesVisivel.year, _mesVisivel.month, dia);
      final chave = DateFormat('yyyy-MM-dd').format(data);
      final status = porDia[chave];
      final ehHoje = data.year == hoje.year &&
          data.month == hoje.month &&
          data.day == hoje.day;

      Color bg;
      Color txt = AppColors.bg;
      switch (status) {
        case 'completo':
          bg = AppColors.acc;
          break;
        case 'joker':
          bg = AppColors.gold;
          break;
        case 'interrompido':
          bg = AppColors.blu.withOpacity(0.45);
          break;
        default:
          bg = AppColors.bord;
          txt = AppColors.mu;
      }

      celulas.add(Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: ehHoje
              ? Border.all(color: AppColors.tx.withOpacity(0.6), width: 1.2)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          status == 'joker' ? '$dia🃏' : '$dia',
          style: AppTextStyles.caption.copyWith(
            fontSize: 9,
            color: txt,
            fontWeight: status != null ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ));
    }
    // Completa a última semana
    while (celulas.length % 7 != 0) {
      celulas.add(null);
    }

    final linhas = <Widget>[];
    for (var i = 0; i < celulas.length; i += 7) {
      linhas.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: List.generate(7, (j) {
            final c = celulas[i + j];
            return Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: c ?? const SizedBox.shrink(),
                ),
              ),
            );
          }),
        ),
      ));
    }
    return linhas;
  }

  Widget _legenda(Color cor, String label) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
      ],
    );
  }

  // ── Lista de registros (filtrada pela janela) ───────────────────────────────

  List<Map<String, dynamic>> _registrosFiltrados(
      List<Map<String, dynamic>> registros) {
    final limite = DateTime.now().subtract(Duration(days: _janela));
    return registros.where((r) {
      final inicio = DateTime.tryParse(r['iniciado_em'] ?? '')?.toLocal();
      return inicio != null && inicio.isAfter(limite);
    }).toList();
  }

  Widget _buildRegistroItem(Map<String, dynamic> r) {
    final inicio = DateTime.tryParse(r['iniciado_em'] ?? '')?.toLocal();
    final status = r['status'] as String? ?? '';
    final duracaoMin = r['duracao_real_min'] as int? ?? 0;
    final metaHoras = (r['meta_horas'] as num?)?.toDouble();
    final humorFim = r['humor_fim'] as int?;
    final reflexao = r['reflexao'] as String?;

    final (emoji, label, cor) = switch (status) {
      'completo' => ('✅', 'Completo', AppColors.acc),
      'joker' => ('🌿', 'Dia de descanso', AppColors.gold),
      _ => ('🕊️', 'Parcial — valeu o esforço', AppColors.blu),
    };

    final duracaoFmt = duracaoMin >= 60
        ? '${duracaoMin ~/ 60}h${(duracaoMin % 60).toString().padLeft(2, '0')}min'
        : '${duracaoMin}min';
    const humores = ['😞', '😕', '😐', '🙂', '😄'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(label,
                  style: AppTextStyles.bodySm.copyWith(
                    color: cor, fontWeight: FontWeight.w700,
                  )),
              const Spacer(),
              if (humorFim != null && humorFim >= 1 && humorFim <= 5) ...[
                Text(humores[humorFim - 1],
                    style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
              ],
              Text(duracaoFmt,
                  style: AppTextStyles.monoSm.copyWith(color: cor)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (inicio != null)
                DateFormat("d 'de' MMMM · HH:mm", 'pt_BR').format(inicio),
              if (metaHoras != null)
                'meta ${metaHoras.toStringAsFixed(metaHoras.truncateToDouble() == metaHoras ? 0 : 1)}h',
            ].join(' · '),
            style: AppTextStyles.caption,
          ),
          if (reflexao != null && reflexao.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surf,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('💭 $reflexao',
                  style: AppTextStyles.caption.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppColors.tx.withOpacity(0.8),
                  )),
            ),
          ],
        ],
      ),
    );
  }
}
