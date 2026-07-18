import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/saude_provider.dart';
import '../../../providers/exercicio_provider.dart';
import '../../../providers/usuarios_provider.dart';
import '../../../services/saude_api_service.dart';
import 'registrar_refeicao_sheet.dart';
import 'anamnese_screen.dart';
import 'sugestao_jantar_screen.dart';
import '../../../providers/jejum_provider.dart';
import '../jejum/jejum_timer_screen.dart';

// ── Slots do dia ──────────────────────────────────────────────────────────────

class _Slot {
  final String tipo;
  final IconData icon;
  final String label;
  final String horario;
  const _Slot(this.tipo, this.icon, this.label, this.horario);
}

const _kSlots = [
  _Slot('cafe_da_manha', Icons.coffee_rounded,     'Café da manhã', '7h – 9h'),
  _Slot('almoco',        Icons.restaurant_rounded, 'Almoço',        '12h – 14h'),
  _Slot('lanche_tarde',  Icons.cookie_rounded,     'Lanche',        '15h – 17h'),
  _Slot('jantar',        Icons.nightlight_round,   'Jantar',        '19h – 21h'),
];

// ── View principal ────────────────────────────────────────────────────────────

class DashboardDiarioView extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;

  const DashboardDiarioView({
    super.key,
    required this.membroId,
    required this.familiaId,
  });

  @override
  ConsumerState<DashboardDiarioView> createState() => _DashboardDiarioViewState();
}

class _DashboardDiarioViewState extends ConsumerState<DashboardDiarioView> {
  String get _hoje {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final perfilAsync    = ref.watch(perfilMetabolicoProvider(widget.membroId));

    return perfilAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.grn)),
      error:   (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: AppColors.red))),
      data:    (perfil) => perfil == null
          ? _SemPerfilView(membroId: widget.membroId)
          : _DashboardConteudo(membroId: widget.membroId, familiaId: widget.familiaId, hoje: _hoje),
    );
  }
}

// ── Empty state (sem perfil) ──────────────────────────────────────────────────

class _SemPerfilView extends StatelessWidget {
  final String membroId;
  const _SemPerfilView({required this.membroId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🥗', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Vamos montar seu plano nutricional!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.tx),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Responda algumas perguntas rápidas e receba suas metas de calorias e nutrientes personalizadas.',
              style: TextStyle(fontSize: 14, color: AppColors.mu),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.grn,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AnamneseScreen(membroId: membroId)),
              ),
              child: const Text('Criar meu plano', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Conteúdo do dashboard ─────────────────────────────────────────────────────

class _DashboardConteudo extends ConsumerWidget {
  final String membroId;
  final String familiaId;
  final String hoje;

  const _DashboardConteudo({
    required this.membroId,
    required this.familiaId,
    required this.hoje,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extratoAsync   = ref.watch(extratoDiarioProvider((membroId: membroId, data: hoje)));
    final refeicaoAsync  = ref.watch(refeicoesDiaProvider((membroId: membroId, data: hoje)));
    final hidraAsync     = ref.watch(hidratacaoDiaProvider((membroId: membroId, data: hoje)));
    final streakAsync    = ref.watch(streakProvider(membroId));
    final exercicioAsync = ref.watch(exercicioDiaProvider((membroId: membroId, data: hoje)));
    final kcalEx         = (exercicioAsync.asData?.value['total_calorias_kcal'] as num?)?.toInt() ?? 0;
    final jejumAtivoAsync = ref.watch(jejumAtivoProvider(membroId));

    final nomeCompleto = ref.watch(perfilUsuarioLogadoProvider).asData?.value?['nome'] as String? ?? '';
    final nome = nomeCompleto.split(' ').first;

    return RefreshIndicator(
      color: AppColors.grn,
      backgroundColor: AppColors.surf,
      onRefresh: () async {
        ref.invalidate(extratoDiarioProvider);
        ref.invalidate(refeicoesDiaProvider);
        ref.invalidate(hidratacaoDiaProvider);
        ref.invalidate(streakProvider);
        ref.invalidate(exercicioDiaProvider);
        ref.invalidate(jejumAtivoProvider);
      },
      child: CustomScrollView(
        slivers: [
          // Saudação
          SliverToBoxAdapter(
            child: extratoAsync.when(
              loading: () => _buildGreeting(nome, streakAsync.value ?? 0, null, kcalEx),
              error:   (_, __) => _buildGreeting(nome, streakAsync.value ?? 0, null, kcalEx),
              data:    (e) => _buildGreeting(nome, streakAsync.value ?? 0, e, kcalEx),
            ),
          ),

          // Anel calórico
          SliverToBoxAdapter(
            child: extratoAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: AppColors.grn)),
              ),
              error: (e, _) => const SizedBox.shrink(),
              data:  (e) => _buildAnelCalorico(e, kcalEx),
            ),
          ),

          // Hidratação
          SliverToBoxAdapter(
            child: hidraAsync.when(
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
              data:    (h) => _buildHidratacao(context, ref, h),
            ),
          ),

          // Jejum ativo (card integrado — só aparece se há jejum em andamento)
          SliverToBoxAdapter(
            child: jejumAtivoAsync.when(
              data: (ativo) => ativo != null
                  ? _buildCardJejumIntegrado(context, ativo)
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
            ),
          ),

          // Refeições do dia
          SliverToBoxAdapter(
            child: refeicaoAsync.when(
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
              data:    (lista) => _buildMealSlots(
                context, ref, lista, jejumAtivoAsync.asData?.value),
            ),
          ),

          // Macros
          SliverToBoxAdapter(
            child: extratoAsync.maybeWhen(
              data: (e) => _buildMacros(e),
              orElse: () => const SizedBox.shrink(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── Saudação ──────────────────────────────────────────────────────────────

  Widget _buildGreeting(String nome, int streak, Map<String, dynamic>? extrato, int kcalEx) {
    final h    = DateTime.now().hour;
    final saud = h < 12 ? 'Bom dia' : h < 18 ? 'Boa tarde' : 'Boa noite';
    final nomeStr = nome.isNotEmpty ? ', $nome' : '';
    final status = _statusMsg(extrato, kcalEx);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$saud$nomeStr!',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.tx),
                ),
                const SizedBox(height: 3),
                Text(status, style: const TextStyle(fontSize: 12, color: AppColors.mu)),
              ],
            ),
          ),
          if (streak >= 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.org.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                border: Border.all(color: AppColors.org.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    '$streak dias',
                    style: const TextStyle(fontSize: 11, color: AppColors.org, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _statusMsg(Map<String, dynamic>? extrato, int kcalEx) {
    if (extrato == null) return 'Carregando seu dia...';
    final count  = (extrato['refeicoes_count'] as num?)?.toInt() ?? 0;
    final cons   = (extrato['calorias_consumidas_kcal'] as num?)?.toDouble() ?? 0;
    final metaAdj = ((extrato['meta_calorica_kcal'] as num?)?.toDouble() ?? 2000) + kcalEx;
    final h = DateTime.now().hour;

    if (count == 0) {
      if (h < 10) return 'Não esqueça do café da manhã ☕';
      if (h < 13) return 'Que tal registrar o que você comeu hoje?';
      return 'Vamos registrar suas refeições de hoje!';
    }
    if (metaAdj <= 0) return 'Continue registrando suas refeições!';
    final pct = cons / metaAdj;
    if (pct >= 0.95) return 'Meta calórica batida! Dia incrível 🎯';
    if (pct >= 0.6)  return 'No caminho certo! Continue assim 💪';
    if (pct >= 0.3)  return 'Bom progresso! Lembre das próximas refeições.';
    return 'Ótimo começo! Continue registrando o dia.';
  }

  // ── Anel calórico ─────────────────────────────────────────────────────────

  Widget _buildAnelCalorico(Map<String, dynamic> extrato, int kcalEx) {
    final cons     = (extrato['calorias_consumidas_kcal'] as num?)?.toDouble() ?? 0;
    final metaBase = (extrato['meta_calorica_kcal'] as num?)?.toDouble() ?? 2000;
    final metaAdj  = metaBase + kcalEx;
    final pct      = metaAdj > 0 ? (cons / metaAdj).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Row(
          children: [
            // Anel
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: pct,
                      strokeWidth: 8,
                      backgroundColor: AppColors.bord,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        pct >= 1.0 ? AppColors.org : AppColors.grn,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cons.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.tx,
                        ),
                      ),
                      const Text('kcal', style: TextStyle(fontSize: 10, color: AppColors.mu)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Detalhes
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meta: ${metaAdj.toInt()} kcal',
                    style: const TextStyle(fontSize: 13, color: AppColors.mu),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Restam: ${(metaAdj - cons).abs().toInt()} kcal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cons > metaAdj ? AppColors.org : AppColors.grn,
                    ),
                  ),
                  if (kcalEx > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.org.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Text(
                        '🏋️ +$kcalEx kcal do treino',
                        style: const TextStyle(fontSize: 11, color: AppColors.org),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hidratação ────────────────────────────────────────────────────────────

  Widget _buildHidratacao(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> hidra,
  ) {
    final total = (hidra['total_ml'] as num?)?.toInt() ?? 0;
    final meta  = (hidra['meta_ml']  as num?)?.toInt() ?? 2000;
    final copos = (total / 250).round();
    final metaCopos = (meta / 250).round();
    final pct = meta > 0 ? (total / meta).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
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
                const Row(
                  children: [
                    Text('💧', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 6),
                    Text(
                      'Hidratação',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.tx),
                    ),
                  ],
                ),
                Text(
                  '$copos / $metaCopos copos',
                  style: const TextStyle(fontSize: 12, color: AppColors.mu),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: AppColors.bord,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.blu),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${total}ml de ${meta}ml',
                  style: const TextStyle(fontSize: 12, color: AppColors.mu),
                ),
                GestureDetector(
                  onTap: () async {
                    try {
                      await SaudeApiService.registrarHidratacao(familiaId, familiaId, volumeMl: 250);
                      ref.invalidate(hidratacaoDiaProvider);
                    } catch (_) {}
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.blu.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                      border: Border.all(color: AppColors.blu.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: AppColors.blu),
                        SizedBox(width: 4),
                        Text('+1 copo', style: TextStyle(fontSize: 12, color: AppColors.blu, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Meal Slots ────────────────────────────────────────────────────────────

  // "12:00" → minutos desde 00h. null se inválido.
  int? _horaParaMin(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return null;
    final p = hhmm.split(':');
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  // Extrai a hora inicial do range do slot ("7h – 9h" → 7) e checa se cai
  // fora da janela alimentar do jejum ativo.
  bool _slotForaDaJanela(_Slot slot, int? janelaIni, int? janelaFim) {
    if (janelaIni == null || janelaFim == null) return false;
    final match = RegExp(r'(\d{1,2})h').firstMatch(slot.horario);
    if (match == null) return false;
    final horaSlotMin = int.parse(match.group(1)!) * 60;
    // Janela normal (ini < fim) ou que cruza a meia-noite
    final dentro = janelaIni <= janelaFim
        ? (horaSlotMin >= janelaIni && horaSlotMin < janelaFim)
        : (horaSlotMin >= janelaIni || horaSlotMin < janelaFim);
    return !dentro;
  }

  Widget _buildMealSlots(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> refeicoes,
    Map<String, dynamic>? jejumAtivo,
  ) {
    // Janela alimentar do jejum ativo (se houver)
    final janelaIni = _horaParaMin(jejumAtivo?['janela_inicio'] as String? ??
        jejumAtivo?['hora_inicio_janela'] as String?);
    final janelaFim = _horaParaMin(jejumAtivo?['janela_fim'] as String? ??
        jejumAtivo?['hora_fim_janela'] as String?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text(
            'REFEIÇÕES DO DIA',
            style: TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
        ),
        ..._kSlots.map((slot) {
          final slotRefs = refeicoes.where((r) => r['tipo_refeicao'] == slot.tipo).toList();
          return _MealSlotCard(
            icon: slot.icon,
            label: slot.label,
            horario: slot.horario,
            refeicoes: slotRefs,
            foraDaJanela: _slotForaDaJanela(slot, janelaIni, janelaFim),
            onRegistrar: () => _abrirRegistro(context, ref, slot.tipo),
            onDeletar: (id) => _deletarRefeicao(context, ref, id),
          );
        }),
        // Botão Sugestão de Jantar IA
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.grn,
              side: const BorderSide(color: AppColors.grn),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
            ),
            icon: const Text('✨', style: TextStyle(fontSize: 14)),
            label: const Text('Sugestão de Jantar IA', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SugestaoJantarScreen(membroId: membroId)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Macros ────────────────────────────────────────────────────────────────

  Widget _buildMacros(Map<String, dynamic> extrato) {
    final protCons = (extrato['proteina_consumida_g']    as num?)?.toDouble() ?? 0;
    final protMeta = (extrato['proteina_meta_g']         as num?)?.toDouble() ?? 150;
    final carbCons = (extrato['carboidrato_consumido_g'] as num?)?.toDouble() ?? 0;
    final carbMeta = (extrato['carboidrato_meta_g']      as num?)?.toDouble() ?? 200;
    final gordCons = (extrato['gordura_consumida_g']     as num?)?.toDouble() ?? 0;
    final gordMeta = (extrato['gordura_meta_g']          as num?)?.toDouble() ?? 70;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NUTRIENTES',
              style: TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            const SizedBox(height: 12),
            _MacroBar(label: 'Proteína',    consumido: protCons, meta: protMeta, color: AppColors.blu),
            const SizedBox(height: 8),
            _MacroBar(label: 'Carboidrato', consumido: carbCons, meta: carbMeta, color: AppColors.org),
            const SizedBox(height: 8),
            _MacroBar(label: 'Gordura',     consumido: gordCons, meta: gordMeta, color: AppColors.pur),
          ],
        ),
      ),
    );
  }

  // ── Card Jejum integrado ──────────────────────────────────────────────────

  Widget _buildCardJejumIntegrado(
      BuildContext context, Map<String, dynamic> ativo) {
    final inicio = DateTime.tryParse(ativo['iniciado_em'] ?? '')?.toLocal();
    final decorrido =
        inicio != null ? DateTime.now().difference(inicio) : Duration.zero;
    final metaHoras = (ativo['meta_horas'] as num?)?.toDouble();
    final pct = metaHoras != null && metaHoras > 0
        ? (decorrido.inMinutes / (metaHoras * 60)).clamp(0.0, 1.0)
        : null;
    final fase = FaseMetabolica.atual(decorrido);
    final protocolo = ativo['protocolo'] as String? ?? '';
    final horaInicioJanela = ativo['hora_inicio_janela'] as String?;

    final h = decorrido.inHours;
    final m = decorrido.inMinutes % 60;

    // Calcular quando a janela abre
    String janelaAbreStr = '';
    if (horaInicioJanela != null) {
      janelaAbreStr = 'Janela abre às ${horaInicioJanela.replaceAll(':', 'h')}';
    }

    // Tempo restante para atingir meta
    String restanteStr = '';
    if (metaHoras != null && pct != null && pct < 1.0) {
      final minRestantes =
          ((metaHoras * 60) - decorrido.inMinutes).round().clamp(0, 9999);
      final hR = minRestantes ~/ 60;
      final mR = minRestantes % 60;
      restanteStr = hR > 0 ? '${hR}h${mR}min' : '${mR}min';
    }

    final protocoloLabel = ProtocoloJejum.todos
        .firstWhere((p) => p.id == protocolo,
            orElse: () => ProtocoloJejum.todos.first)
        .label;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JejumTimerScreen(
            membroId: membroId,
            familiaId: familiaId,
            registroInicial: ativo,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(color: AppColors.acc.withOpacity(0.35), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '⏱ Jejum · $protocoloLabel',
                    style: AppTextStyles.bodySm.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.tx,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.acc.withOpacity(0.15),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusChip),
                      border: Border.all(
                          color: AppColors.acc.withOpacity(0.4), width: 0.8),
                    ),
                    child: Text(
                      '${h}h${m.toString().padLeft(2, '0')} · ativo',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.acc,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              if (pct != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: AppColors.bord,
                    valueColor: const AlwaysStoppedAnimation(AppColors.acc),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    janelaAbreStr.isNotEmpty ? janelaAbreStr : fase.nome,
                    style: AppTextStyles.caption,
                  ),
                  if (restanteStr.isNotEmpty)
                    Text(
                      '$restanteStr restante',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.acc,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Ações ─────────────────────────────────────────────────────────────────

  void _abrirRegistro(BuildContext context, WidgetRef ref, String tipo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RegistrarRefeicaoSheet(
        membroId: membroId,
        familiaId: familiaId,
        initialTipo: tipo,
      ),
    ).then((_) {
      ref.invalidate(extratoDiarioProvider);
      ref.invalidate(refeicoesDiaProvider);
      ref.invalidate(streakProvider);
    });
  }

  Future<void> _deletarRefeicao(BuildContext context, WidgetRef ref, String id) async {
    if (id.isEmpty) return;
    try {
      await SaudeApiService.deletarRefeicao(id);
      ref.invalidate(refeicoesDiaProvider);
      ref.invalidate(extratoDiarioProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao deletar: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }
}

// ── MealSlotCard ──────────────────────────────────────────────────────────────

class _MealSlotCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String horario;
  final List<Map<String, dynamic>> refeicoes;
  final VoidCallback onRegistrar;
  final ValueChanged<String> onDeletar;
  final bool foraDaJanela; // slot cai fora da janela do jejum ativo

  const _MealSlotCard({
    required this.icon,
    required this.label,
    required this.horario,
    required this.refeicoes,
    required this.onRegistrar,
    required this.onDeletar,
    this.foraDaJanela = false,
  });

  @override
  Widget build(BuildContext context) {
    final totalKcal = refeicoes.fold<int>(
      0,
      (sum, r) => sum + ((r['calorias_kcal'] as num?)?.toInt() ?? 0),
    );

    // Alerta só quando há refeição registrada num slot fora da janela
    final alertaJanela = foraDaJanela && refeicoes.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(
          color: alertaJanela ? AppColors.red.withOpacity(0.35) : AppColors.bord,
          width: alertaJanela ? 0.8 : 0.5,
        ),
      ),
      child: Column(
        children: [
          // Cabeçalho do slot
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: alertaJanela
                        ? AppColors.red.withOpacity(0.1)
                        : AppColors.grn.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18,
                      color: alertaJanela ? AppColors.red : AppColors.grn),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.tx)),
                      if (alertaJanela)
                        const Text('Fora da janela alimentar',
                            style: TextStyle(fontSize: 10, color: AppColors.red))
                      else
                        Text(horario, style: const TextStyle(fontSize: 10, color: AppColors.mu)),
                    ],
                  ),
                ),
                if (alertaJanela) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                    ),
                    child: const Text('⚠️',
                        style: TextStyle(fontSize: 10)),
                  ),
                  const SizedBox(width: 4),
                ],
                if (totalKcal > 0)
                  Text(
                    '$totalKcal kcal',
                    style: const TextStyle(fontSize: 12, color: AppColors.grn, fontWeight: FontWeight.w600),
                  ),
                IconButton(
                  onPressed: onRegistrar,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.acc),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Lista de refeições
          if (refeicoes.isNotEmpty) ...[
            const Divider(color: AppColors.bord, height: 1),
            ...refeicoes.map((r) => Dismissible(
              key: Key(r['id'] as String? ?? r.hashCode.toString()),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: AppColors.red.withOpacity(0.15),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 20),
              ),
              onDismissed: (_) => onDeletar(r['id'] as String? ?? ''),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['descricao'] as String? ?? r['nome'] as String? ?? '',
                            style: const TextStyle(fontSize: 12, color: AppColors.tx),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if ((r['proteina_g'] as num?) != null)
                            Text(
                              'P: ${(r['proteina_g'] as num).toInt()}g  C: ${(r['carboidrato_g'] as num?)?.toInt() ?? 0}g  G: ${(r['gordura_g'] as num?)?.toInt() ?? 0}g',
                              style: const TextStyle(fontSize: 10, color: AppColors.mu),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${(r['calorias_kcal'] as num?)?.toInt() ?? 0} kcal',
                      style: const TextStyle(fontSize: 12, color: AppColors.mu),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }
}

// ── MacroBar ──────────────────────────────────────────────────────────────────

class _MacroBar extends StatelessWidget {
  final String label;
  final double consumido;
  final double meta;
  final Color color;

  const _MacroBar({
    required this.label,
    required this.consumido,
    required this.meta,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = meta > 0 ? (consumido / meta).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.mu)),
            Text(
              '${consumido.toInt()}g / ${meta.toInt()}g',
              style: const TextStyle(fontSize: 12, color: AppColors.mu),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: AppColors.bord,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
