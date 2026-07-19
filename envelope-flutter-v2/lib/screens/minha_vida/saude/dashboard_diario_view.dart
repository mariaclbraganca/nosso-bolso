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
import '../../../widgets/unicorn/unicorn_system.dart';

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
          // 1. Saudação "Hoje · Nome" + chip streak
          SliverToBoxAdapter(
            child: extratoAsync.when(
              loading: () => _buildGreeting(nome, streakAsync.value ?? 0, null, kcalEx),
              error:   (_, __) => _buildGreeting(nome, streakAsync.value ?? 0, null, kcalEx),
              data:    (e) => _buildGreeting(nome, streakAsync.value ?? 0, e, kcalEx),
            ),
          ),

          // 2. Card unicórnio "bom dia" (Happy) — sempre visível
          SliverToBoxAdapter(
            child: _buildSaudacaoUnicornio(jejumAtivoAsync.asData?.value),
          ),

          // 3. Card Jejum (só quando há jejum ativo) — ANTES do anel
          SliverToBoxAdapter(
            child: jejumAtivoAsync.when(
              data: (ativo) => ativo != null
                  ? _buildCardJejumIntegrado(context, ativo)
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
            ),
          ),

          // 4. Anel calórico COM macros dentro
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

          // 5. Hidratação (copos)
          SliverToBoxAdapter(
            child: hidraAsync.when(
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
              data:    (h) => _buildHidratacao(context, ref, h),
            ),
          ),

          // 6. Refeições do dia
          SliverToBoxAdapter(
            child: refeicaoAsync.when(
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
              data:    (lista) => _buildMealSlots(
                context, ref, lista, jejumAtivoAsync.asData?.value),
            ),
          ),

          // 7. Card SEUS UNICÓRNIOS (Sweet + Happy) — sempre visível
          SliverToBoxAdapter(
            child: _buildCardUnicornios(jejumAtivoAsync.asData?.value),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── Saudação do unicórnio (Happy — nunca Astrix no contexto de jejum) ───────

  Widget _buildSaudacaoUnicornio(Map<String, dynamic>? jejumAtivo) {
    final h = DateTime.now().hour;
    final saud = h < 12 ? 'bom dia' : h < 18 ? 'boa tarde' : 'boa noite';

    // Mensagem contextual: com jejum ativo fala do jejum; sem, mensagem de saúde
    String mensagem;
    final inicio =
        DateTime.tryParse(jejumAtivo?['iniciado_em'] ?? '')?.toLocal();
    if (jejumAtivo != null && inicio != null) {
      final horas = DateTime.now().difference(inicio).inHours;
      final fase = FaseMetabolica.atual(DateTime.now().difference(inicio));
      mensagem =
          'Você está na hora $horas do jejum. ${fase.emoji} ${fase.nome} — '
          'cuida da hidratação 💧';
    } else {
      mensagem = h < 12
          ? 'Um novo dia pra cuidar de você. Comece com um copo de água 💧'
          : h < 18
              ? 'Como está sendo seu dia? Lembre de se hidratar e comer bem 🌿'
              : 'Fim de dia chegando. Você fez o seu melhor hoje 💚';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.acc.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.acc.withOpacity(0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const UnicornWidget(type: UnicornType.happy, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Happy · $saud!',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.acc,
                        fontWeight: FontWeight.bold,
                      )),
                  const SizedBox(height: 2),
                  Text(mensagem,
                      style: AppTextStyles.caption.copyWith(height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card SEUS UNICÓRNIOS (só Sweet e Happy) ─────────────────────────────────

  Widget _buildCardUnicornios(Map<String, dynamic>? jejumAtivo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: _CardUnicorniosSaude(jejumAtivo: jejumAtivo),
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

    // Macros
    final protCons = (extrato['proteina_consumida_g']    as num?)?.toDouble() ?? 0;
    final protMeta = (extrato['proteina_meta_g']         as num?)?.toDouble() ?? 150;
    final carbCons = (extrato['carboidrato_consumido_g'] as num?)?.toDouble() ?? 0;
    final carbMeta = (extrato['carboidrato_meta_g']      as num?)?.toDouble() ?? 200;
    final gordCons = (extrato['gordura_consumida_g']     as num?)?.toDouble() ?? 0;
    final gordMeta = (extrato['gordura_meta_g']          as num?)?.toDouble() ?? 70;
    final protPct  = protMeta > 0 ? (protCons / protMeta).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Anel calórico com % no centro
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: pct,
                      strokeWidth: 7,
                      backgroundColor: AppColors.bord,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        pct >= 1.0 ? AppColors.org : AppColors.grn,
                      ),
                    ),
                  ),
                  Text(
                    '${(pct * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.grn,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Kcal + barras de macro
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: _fmtMilhar(cons.toInt()),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.tx,
                          ),
                        ),
                        TextSpan(
                          text: '  / ${_fmtMilhar(metaAdj.toInt())} kcal',
                          style: const TextStyle(fontSize: 12, color: AppColors.mu),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'P ${protCons.toInt()}g · C ${carbCons.toInt()}g · G ${gordCons.toInt()}g',
                    style: const TextStyle(fontSize: 11, color: AppColors.mu),
                  ),
                  const SizedBox(height: 8),
                  _macroLinha('P', protCons, protMeta, AppColors.blu),
                  const SizedBox(height: 4),
                  _macroLinha('C', carbCons, carbMeta, AppColors.grn),
                  const SizedBox(height: 4),
                  _macroLinha('G', gordCons, gordMeta, AppColors.gold),
                  if (protPct < 0.6) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.org.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                      ),
                      child: const Text(
                        '⚠️ Proteína abaixo da meta',
                        style: TextStyle(fontSize: 9, color: AppColors.org, fontWeight: FontWeight.bold),
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

  // Linha de macro: letra + barra de progresso + %
  Widget _macroLinha(String letra, double cons, double meta, Color cor) {
    final pct = meta > 0 ? (cons / meta).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 12,
          child: Text(letra,
              style: const TextStyle(fontSize: 10, color: AppColors.mu)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: AppColors.bord,
              valueColor: AlwaysStoppedAnimation<Color>(cor),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 30,
          child: Text('${(pct * 100).round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 9, color: AppColors.mu)),
        ),
      ],
    );
  }

  String _fmtMilhar(int v) {
    final s = v.toString();
    return s.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
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

// ── Card SEUS UNICÓRNIOS (Sweet + Happy) ──────────────────────────────────────
// Regra: no contexto de jejum/saúde só entram Sweet e Happy. Astrix e Geronimo
// ficam de fora — dinheiro/cobrança nunca aparecem aqui.

class _CardUnicorniosSaude extends StatefulWidget {
  final Map<String, dynamic>? jejumAtivo;
  const _CardUnicorniosSaude({this.jejumAtivo});

  @override
  State<_CardUnicorniosSaude> createState() => _CardUnicorniosSaudeState();
}

class _CardUnicorniosSaudeState extends State<_CardUnicorniosSaude> {
  UnicornType _sel = UnicornType.sweet;
  int _msgIndex = 0;

  // Tipos de mensagem — Amor / Insight / Ciência (Fato). Sem menção a dinheiro.
  List<({String emoji, String label, Color cor, String texto})> get _mensagens {
    final horas = _horasJejum;
    final ciencia = horas != null
        ? 'Na hora $horas do jejum, seu corpo usa gordura como combustível — '
            'muitas pessoas relatam mais clareza mental nesse momento. ✨'
        : 'O jejum ativa a autofagia: suas células se limpam e se renovam. '
            'É cuidado de verdade com você. ✨';
    return [
      (
        emoji: '💚',
        label: 'Amor',
        cor: AppColors.acc,
        texto: 'Você está cuidando de você hoje, e isso é bonito. '
            'Sem pressa, sem cobrança — no seu ritmo. 💚',
      ),
      (
        emoji: '✨',
        label: 'Insight',
        cor: AppColors.gold,
        texto: horas != null
            ? 'Você já está há $horas horas em jejum. Cada hora é uma escolha '
                'de autocuidado que se soma. 🌱'
            : 'Beber água ao longo do dia deixa o jejum mais leve e a fome '
                'mais tranquila. 🌱',
      ),
      (
        emoji: '🧠',
        label: 'Ciência',
        cor: AppColors.blu,
        texto: ciencia,
      ),
    ];
  }

  int? get _horasJejum {
    final inicio =
        DateTime.tryParse(widget.jejumAtivo?['iniciado_em'] ?? '')?.toLocal();
    if (inicio == null) return null;
    return DateTime.now().difference(inicio).inHours;
  }

  @override
  Widget build(BuildContext context) {
    final msg = _mensagens[_msgIndex];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.acc.withOpacity(0.06), AppColors.card],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.acc.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🦄 SEUS UNICÓRNIOS',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mu,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                fontSize: 10,
              )),
          const SizedBox(height: 12),

          // Seletor de personagem (só Sweet e Happy)
          Row(
            children: [
              _personagemChip(UnicornType.sweet, 'Sweet'),
              const SizedBox(width: 8),
              _personagemChip(UnicornType.happy, 'Happy'),
            ],
          ),
          const SizedBox(height: 14),

          // Mensagem atual
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UnicornWidget(type: _sel, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_sel == UnicornType.sweet ? "Sweet" : "Happy"} · ${msg.label}',
                        style: AppTextStyles.caption.copyWith(
                          color: msg.cor,
                          fontWeight: FontWeight.bold,
                        )),
                    const SizedBox(height: 4),
                    Text(msg.texto,
                        style: AppTextStyles.bodySm.copyWith(height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dots de navegação entre tipos de mensagem
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_mensagens.length, (i) {
                final ativo = i == _msgIndex;
                return GestureDetector(
                  onTap: () => setState(() => _msgIndex = i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: ativo ? 18 : 6,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ativo ? AppColors.acc : AppColors.bord,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),

          // Cartões dos 3 tipos de mensagem
          Row(
            children: _mensagens.asMap().entries.map((e) {
              final i = e.key;
              final m = e.value;
              final ativo = i == _msgIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _msgIndex = i),
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surf,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ativo ? m.cor.withOpacity(0.5) : AppColors.bord,
                        width: ativo ? 1 : 0.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text('${m.emoji} ${m.label}',
                            style: AppTextStyles.caption.copyWith(
                              color: m.cor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _personagemChip(UnicornType type, String nome) {
    final ativo = _sel == type;
    return GestureDetector(
      onTap: () => setState(() => _sel = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ativo ? AppColors.acc.withOpacity(0.15) : AppColors.surf,
          borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
          border: Border.all(
            color: ativo ? AppColors.acc : AppColors.bord,
            width: ativo ? 1 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UnicornWidget(type: type, size: 20),
            const SizedBox(width: 6),
            Text(nome,
                style: AppTextStyles.caption.copyWith(
                  color: ativo ? AppColors.acc : AppColors.mu,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }
}
