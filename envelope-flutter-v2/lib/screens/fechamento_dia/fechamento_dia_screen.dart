import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/dia_provider.dart';
import '../../providers/envelopes_provider.dart';
import '../../services/financeiro_ext_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';

/// FECHAMENTO DO DIA — o ritual das 23h30.
///
/// Mostra o que a família gastou hoje e as compras capturadas (Nubank/iFood)
/// ainda sem envelope, já com o envelope sugerido. Um toque em "Fechar o dia"
/// confirma tudo. Trocar o envelope ou descartar uma compra é opcional.
class FechamentoDiaScreen extends ConsumerStatefulWidget {
  const FechamentoDiaScreen({super.key});

  @override
  ConsumerState<FechamentoDiaScreen> createState() => _FechamentoDiaScreenState();
}

class _FechamentoDiaScreenState extends ConsumerState<FechamentoDiaScreen> {
  final _fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final Map<String, Map<String, dynamic>> _ajustes = {}; // compra_id → envelope
  final Set<String> _descartadas = {};
  bool _fechando = false;

  @override
  void initState() {
    super.initState();
    NotificationService.silenciarAlarmeAtivo();
  }

  Map<String, dynamic>? _envelopeDe(Map<String, dynamic> p) =>
      _ajustes[p['compra_id']] ?? (p['envelope_sugerido'] as Map<String, dynamic>?);

  Future<void> _escolherEnvelope(Map<String, dynamic> pendente) async {
    final envelopes = ref.read(envelopesProvider).asData?.value ?? [];
    final escolhido = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppColors.surf,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(pendente['estabelecimento'] ?? 'Compra', style: AppTextStyles.titleSm),
            ),
            for (final e in envelopes)
              ListTile(
                leading: Text(e['emoji'] ?? '📦', style: const TextStyle(fontSize: 22)),
                title: Text(e['nome_envelope'] ?? '', style: AppTextStyles.body),
                trailing: Text(_fmt.format((e['saldo_atual'] as num?) ?? 0),
                    style: AppTextStyles.monoSm.copyWith(color: AppColors.mu)),
                onTap: () => Navigator.pop(ctx, {
                  'id': e['id'], 'nome': e['nome_envelope'], 'emoji': e['emoji'],
                }),
              ),
          ],
        ),
      ),
    );
    if (escolhido != null) {
      setState(() {
        _ajustes[pendente['compra_id'] as String] = escolhido;
        _descartadas.remove(pendente['compra_id']);
      });
    }
  }

  Future<void> _fechar() async {
    setState(() => _fechando = true);
    try {
      final r = await FinanceiroExtService.fecharDia(
        ajustes: {for (final e in _ajustes.entries) e.key: e.value['id'] as String},
        descartar: _descartadas.toList(),
      );
      ref.invalidate(resumoDiaProvider);
      if (!mounted) return;
      if (r['fechado'] == true) {
        HapticFeedback.heavyImpact();
        await NotificationService.agendarAlarmeFechamento(hojeFechado: true);
        if (!mounted) return;
        final streak = (r['resumo']?['streak'] as num?)?.toInt() ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Dia fechado! 🔥 $streak ${streak == 1 ? 'dia' : 'dias'} seguidos'),
        ));
        Navigator.of(context).maybePop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Escolha o envelope das compras marcadas antes de fechar.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao fechar: $e')));
      }
    } finally {
      if (mounted) setState(() => _fechando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(resumoDiaProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Fechamento do dia 🌙')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acc)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Não foi possível carregar o dia.\n$e',
                textAlign: TextAlign.center, style: AppTextStyles.bodySm),
          ),
        ),
        data: (r) => _conteudo(r),
      ),
    );
  }

  Widget _conteudo(Map<String, dynamic> r) {
    final pendentes = (r['pendentes'] as List? ?? []).cast<Map<String, dynamic>>();
    final gastos = (r['gastos'] as List? ?? []).cast<Map<String, dynamic>>();
    final semEnvelope = pendentes.where(
        (p) => !_descartadas.contains(p['compra_id']) && _envelopeDe(p) == null).length;
    final fechado = r['fechado'] == true;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(resumoDiaProvider.future),
            color: AppColors.acc,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.pagePad),
              children: [
                _Placar(resumo: r, fmt: _fmt),
                if (fechado) ...[
                  const SizedBox(height: AppSpacing.cardGap),
                  _Aviso(
                    cor: AppColors.grn,
                    texto: '✅ Dia fechado${r['fechado_por'] != null ? ' por ${r['fechado_por']}' : ''}. '
                        'Pode fechar de novo se entrou algo depois.',
                  ),
                ],
                const SizedBox(height: AppSpacing.sectionGap),
                if (pendentes.isNotEmpty) ...[
                  Text('Para resolver (${pendentes.length})', style: AppTextStyles.titleSm),
                  const SizedBox(height: 4),
                  Text('Confira o envelope sugerido. Toque para trocar.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.mu)),
                  const SizedBox(height: AppSpacing.itemGap),
                  for (final p in pendentes) _pendenteTile(p),
                  const SizedBox(height: AppSpacing.sectionGap),
                ],
                Text('Lançados hoje (${gastos.length})', style: AppTextStyles.titleSm),
                const SizedBox(height: AppSpacing.itemGap),
                if (gastos.isEmpty)
                  Text('Nenhum gasto lançado hoje.',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.mu)),
                for (final g in gastos)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(g['descricao'] ?? '—', style: AppTextStyles.body),
                    subtitle: Text(
                      [g['quem'], g['envelope']].whereType<String>().join(' · '),
                      style: AppTextStyles.caption.copyWith(color: AppColors.mu),
                    ),
                    trailing: Text(_fmt.format(g['valor'] ?? 0), style: AppTextStyles.mono),
                  ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.pagePad, 8, AppSpacing.pagePad, 12),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _fechando || semEnvelope > 0 ? null : _fechar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.acc,
                  foregroundColor: AppColors.bg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                ),
                child: _fechando
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                    : Text(
                        semEnvelope > 0
                            ? 'Escolha o envelope de $semEnvelope ${semEnvelope == 1 ? 'compra' : 'compras'}'
                            : pendentes.isEmpty
                                ? 'Fechar o dia'
                                : 'Confirmar tudo e fechar o dia',
                        style: AppTextStyles.body.copyWith(
                            color: AppColors.bg, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pendenteTile(Map<String, dynamic> p) {
    final id = p['compra_id'] as String;
    final descartada = _descartadas.contains(id);
    final env = _envelopeDe(p);
    final origem = [p['quem'], p['fonte'], _dataCurta(p['data'])].whereType<String>().join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.itemGap),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: env == null && !descartada ? AppColors.org : AppColors.bord),
      ),
      child: Opacity(
        opacity: descartada ? 0.45 : 1,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['estabelecimento'] ?? 'Compra',
                      style: AppTextStyles.body.copyWith(
                          decoration: descartada ? TextDecoration.lineThrough : null)),
                  if (origem.isNotEmpty)
                    Text(origem, style: AppTextStyles.caption.copyWith(color: AppColors.mu)),
                  const SizedBox(height: 8),
                  if (!descartada)
                    InkWell(
                      onTap: () => _escolherEnvelope(p),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (env == null ? AppColors.org : AppColors.acc).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                        ),
                        child: Text(
                          env == null ? 'Escolher envelope ›' : '${env['emoji'] ?? '📦'} ${env['nome']} ›',
                          style: AppTextStyles.bodySm.copyWith(
                              color: env == null ? AppColors.org : AppColors.acc),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_fmt.format(p['valor'] ?? 0), style: AppTextStyles.mono),
                IconButton(
                  tooltip: descartada ? 'Manter' : 'Não é gasto (descartar)',
                  icon: Icon(descartada ? Icons.undo : Icons.close, size: 18, color: AppColors.mu),
                  onPressed: () => setState(() =>
                      descartada ? _descartadas.remove(id) : _descartadas.add(id)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _dataCurta(dynamic iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '');
    if (d == null) return null;
    final hoje = DateTime.now();
    if (d.year == hoje.year && d.month == hoje.month && d.day == hoje.day) return 'hoje';
    return DateFormat('dd/MM').format(d);
  }
}

class _Placar extends StatelessWidget {
  final Map<String, dynamic> resumo;
  final NumberFormat fmt;
  const _Placar({required this.resumo, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final porDia = resumo['pode_gastar_por_dia'] as num?;
    final streak = (resumo['streak'] as num?)?.toInt() ?? 0;
    final dias = (resumo['dias_restantes'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Hoje a família gastou',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.mu)),
              ),
              Text('🔥 $streak ${streak == 1 ? 'dia' : 'dias'}',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.gold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(fmt.format(resumo['total_dia'] ?? 0), style: AppTextStyles.monoLg),
          const Divider(height: 24, color: AppColors.bord),
          Text(
            porDia == null
                ? 'Último dia do mês — amanhã começa um ciclo novo.'
                : 'Dá pra gastar ${fmt.format(porDia)}/dia nos próximos $dias dias',
            style: AppTextStyles.body.copyWith(
                color: (porDia ?? 1) <= 0 ? AppColors.red : AppColors.acc),
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final Color cor;
  final String texto;
  const _Aviso({required this.cor, required this.texto});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Text(texto, style: AppTextStyles.bodySm.copyWith(color: cor)),
      );
}
