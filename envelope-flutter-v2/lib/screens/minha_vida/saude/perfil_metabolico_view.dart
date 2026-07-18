import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/saude_provider.dart';
import '../../../services/saude_api_service.dart';
import 'anamnese_screen.dart';

class PerfilMetabolicoView extends ConsumerWidget {
  final String membroId;
  final String familiaId;

  const PerfilMetabolicoView({
    super.key,
    required this.membroId,
    required this.familiaId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(perfilMetabolicoProvider(membroId));

    return perfilAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.grn)),
      error:   (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: AppColors.red))),
      data:    (perfil) => perfil == null
          ? _SemPerfilPrompt(membroId: membroId)
          : _PerfilConteudo(membroId: membroId, familiaId: familiaId, perfil: perfil),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _SemPerfilPrompt extends StatelessWidget {
  final String membroId;
  const _SemPerfilPrompt({required this.membroId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🥗', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text(
              'Vamos montar seu plano!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.tx),
            ),
            const SizedBox(height: 8),
            const Text(
              'Responda algumas perguntas rápidas e vou calcular quantas calorias e proteínas você precisa por dia.',
              style: TextStyle(color: AppColors.mu, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.grn,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                ),
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

// ── Conteúdo do perfil ────────────────────────────────────────────────────────

class _PerfilConteudo extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;
  final Map<String, dynamic> perfil;

  const _PerfilConteudo({
    required this.membroId,
    required this.familiaId,
    required this.perfil,
  });

  @override
  ConsumerState<_PerfilConteudo> createState() => _PerfilConteudoState();
}

class _PerfilConteudoState extends ConsumerState<_PerfilConteudo> {
  @override
  Widget build(BuildContext context) {
    final met    = widget.perfil['metabolico'] as Map<String, dynamic>? ?? {};
    final macros = met['metas_macros'] as Map<String, dynamic>? ?? {};
    final antro  = widget.perfil['antropometria'] as Map<String, dynamic>? ?? {};
    final anamnese  = widget.perfil['anamnese'] as Map<String, dynamic>? ?? {};
    final alergias  = (anamnese['alergias'] as List?)?.cast<String>() ?? [];
    final supl      = (anamnese['suplementos'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final objetivoLabel = {
      'perda_peso':  '⬇️ Perda de Peso',
      'manutencao':  '↔️ Manutenção',
      'ganho_massa': '⬆️ Ganho de Massa',
    }[met['objetivo'] ?? 'manutencao'] ?? 'Manutenção';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(objetivoLabel, antro, anamnese)),
        SliverToBoxAdapter(child: _buildPlanodiario(met, macros)),
        SliverToBoxAdapter(child: _buildComposicao(antro)),
        if (alergias.isNotEmpty) SliverToBoxAdapter(child: _buildAlergias(alergias)),
        if (supl.isNotEmpty)     SliverToBoxAdapter(child: _buildSupl(supl)),
        SliverToBoxAdapter(child: _buildAcoes(context)),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    String objetivo,
    Map<String, dynamic> antro,
    Map<String, dynamic> anamnese,
  ) {
    final nome = anamnese['nome_curto'] as String? ?? 'Membro';
    final peso = (antro['peso_kg'] as num?)?.toStringAsFixed(1) ?? '?';
    final alt  = (antro['altura_cm'] as num?)?.toInt() ?? '?';
    final idade = antro['idade'] ?? '?';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.grn.withOpacity(0.2),
              child: Text(
                nome[0].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.grn, fontSize: 22, fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Perfil Nutricional', style: TextStyle(fontSize: 11, color: AppColors.mu)),
                Text(
                  objetivo,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.tx),
                ),
                Text(
                  '${peso}kg  •  ${alt}cm  •  $idade anos',
                  style: const TextStyle(fontSize: 12, color: AppColors.mu),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Plano diário ──────────────────────────────────────────────────────────

  Widget _buildPlanodiario(Map<String, dynamic> met, Map<String, dynamic> macros) {
    final tmb  = (met['tmb_kcal'] as num?)?.toInt() ?? 0;
    final tdee = (met['tdee_kcal'] as num?)?.toInt() ?? 0;
    final meta = (met['meta_calorica_kcal'] as num?)?.toInt() ?? 0;
    final prot = (macros['proteina_via_comida_g'] as num?)?.toInt() ?? 0;
    final carb = (macros['carboidrato_g'] as num?)?.toInt() ?? 0;
    final gord = (macros['gordura_g'] as num?)?.toInt() ?? 0;

    return _Secao(
      titulo: 'SEU PLANO DIÁRIO',
      children: [
        _InfoRow('Metabolismo basal (TMB)', '$tmb kcal'),
        _InfoRow('Gasto total diário (TDEE)', '$tdee kcal'),
        _InfoRow('Sua meta calórica', '$meta kcal', destaque: true),
        const Divider(color: AppColors.bord, height: 16),
        _InfoRow('Proteína (via alimentação)', '${prot}g', destaque: true),
        _InfoRow('Carboidrato', '${carb}g'),
        _InfoRow('Gordura', '${gord}g'),
      ],
    );
  }

  // ── Composição corporal ───────────────────────────────────────────────────

  Widget _buildComposicao(Map<String, dynamic> antro) {
    final pctGord    = antro['percentual_gordura'];
    final massaMagra = antro['massa_magra_kg'];

    return _Secao(
      titulo: 'Composição Corporal',
      trailing: TextButton.icon(
        icon: const Icon(Icons.add_rounded, size: 14, color: AppColors.grn),
        label: const Text('Registrar Peso', style: TextStyle(fontSize: 12, color: AppColors.grn)),
        onPressed: () => _registrarPeso(context),
      ),
      children: [
        _InfoRow('Peso Atual', '${(antro['peso_kg'] as num?)?.toStringAsFixed(1) ?? '?'}kg'),
        if (pctGord != null)    _InfoRow('% Gordura', '${(pctGord as num).toStringAsFixed(1)}%'),
        if (massaMagra != null) _InfoRow('Massa Magra', '${(massaMagra as num).toStringAsFixed(1)}kg'),
        _InfoRow('Última Medição', _fmtDate(antro['ultima_medicao'] as String?)),
      ],
    );
  }

  // ── Alergias ──────────────────────────────────────────────────────────────

  Widget _buildAlergias(List<String> alergias) {
    return _Secao(
      titulo: 'Restrições Alimentares',
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: alergias.map((a) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
              border: Border.all(color: AppColors.red.withOpacity(0.3)),
            ),
            child: Text(a, style: const TextStyle(fontSize: 12, color: AppColors.red)),
          )).toList(),
        ),
      ],
    );
  }

  // ── Suplementos ───────────────────────────────────────────────────────────

  Widget _buildSupl(List<Map<String, dynamic>> supl) {
    return _Secao(
      titulo: 'Suplementação',
      children: supl.map((s) => _InfoRow(
        s['nome'] as String? ?? '',
        s['dose'] as String? ?? '',
      )).toList(),
    );
  }

  // ── Ações ─────────────────────────────────────────────────────────────────

  Widget _buildAcoes(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          const Text(
            'Seus dados mudaram? Refaça o plano para atualizar suas metas.',
            style: TextStyle(fontSize: 12, color: AppColors.mu),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.grn,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refazer Meu Plano', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AnamneseScreen(membroId: widget.membroId),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso.split('T').first;
    }
  }

  void _registrarPeso(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Registrar Peso', style: TextStyle(color: AppColors.tx)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppColors.tx),
          decoration: const InputDecoration(
            hintText: '74.5',
            suffixText: 'kg',
            hintStyle: TextStyle(color: AppColors.mu),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.grn),
            onPressed: () async {
              final peso = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (peso == null) return;
              Navigator.pop(context);
              try {
                final now = DateTime.now();
                await SaudeApiService.registrarPeso({
                  'membro_id': widget.membroId,
                  'familia_id': widget.familiaId,
                  'peso_kg': peso,
                  'data_medicao': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
                });
                ref.invalidate(perfilMetabolicoProvider);
                ref.invalidate(historicoPesoProvider);
              } catch (_) {}
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

// ── Widgets internos ──────────────────────────────────────────────────────────

class _Secao extends StatelessWidget {
  final String titulo;
  final List<Widget> children;
  final Widget? trailing;

  const _Secao({required this.titulo, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
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
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.mu, letterSpacing: 0.6,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool destaque;

  const _InfoRow(this.label, this.value, {this.destaque = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.mu)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: destaque ? FontWeight.bold : FontWeight.w500,
              color: destaque ? AppColors.grn : AppColors.tx,
            ),
          ),
        ],
      ),
    );
  }
}
