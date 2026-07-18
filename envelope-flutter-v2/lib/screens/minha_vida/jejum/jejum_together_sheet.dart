import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/jejum_provider.dart';
import '../../../providers/usuarios_provider.dart';
import '../../../services/jejum_api_service.dart';
import '../../../widgets/unicorn/unicorn_system.dart';

/// Sheet do Fast Together: convite de parceiro ou envio de incentivo.
/// Só marcos POSITIVOS do parceiro são visíveis — quebras ficam privadas.
class JejumTogetherSheet extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;

  const JejumTogetherSheet({
    super.key,
    required this.membroId,
    required this.familiaId,
  });

  @override
  ConsumerState<JejumTogetherSheet> createState() =>
      _JejumTogetherSheetState();
}

class _JejumTogetherSheetState extends ConsumerState<JejumTogetherSheet> {
  final _msgCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  JejumArgs get _args =>
      (membroId: widget.membroId, familiaId: widget.familiaId);

  @override
  Widget build(BuildContext context) {
    final togetherAsync = ref.watch(jejumTogetherProvider(_args));

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.bord,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          togetherAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: UnicornLoading()),
            ),
            error: (_, __) => _buildConvite(),
            data: (vinculo) =>
                vinculo == null ? _buildConvite() : _buildAtivo(vinculo),
          ),
        ],
      ),
    );
  }

  // ── Sem vínculo: escolher parceiro ─────────────────────────────────────────

  Widget _buildConvite() {
    final membros = ref.watch(listaUsuariosProvider).asData?.value ?? [];
    final outros =
        membros.where((m) => m['id'] != widget.membroId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('🤝 Fast Together',
            style: AppTextStyles.title.copyWith(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          'Jejuar em dupla aumenta (muito!) a chance de manter o hábito. '
          'Cada um segue seu próprio ritmo — vocês só se motivam.',
          style: AppTextStyles.caption.copyWith(height: 1.4),
        ),
        const SizedBox(height: 20),
        if (outros.isEmpty)
          Text('Nenhum outro membro na família ainda.',
              style: AppTextStyles.bodySm)
        else
          ...outros.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: _enviando ? null : () => _convidar(m['id'] as String),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusBtn),
                      border: Border.all(color: AppColors.bord, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.pur.withOpacity(0.2),
                          child: Text(
                            ((m['nome'] as String? ?? '?')[0]).toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.pur,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            m['nome'] as String? ?? '',
                            style: AppTextStyles.bodySm
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('Convidar',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.pur,
                              fontWeight: FontWeight.bold,
                            )),
                      ],
                    ),
                  ),
                ),
              )),
      ],
    );
  }

  // ── Vínculo ativo: incentivo ───────────────────────────────────────────────

  Widget _buildAtivo(Map<String, dynamic> vinculo) {
    final parceiro = vinculo['parceiro'] as Map<String, dynamic>? ?? {};
    final nome = parceiro['nome'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('🤝 Você e $nome',
            style: AppTextStyles.title.copyWith(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          'Mande um incentivo — chega como notificação carinhosa no celular. '
          'Máximo de 2 por dia, para não virar cobrança. 💜',
          style: AppTextStyles.caption.copyWith(height: 1.4),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _msgCtrl,
          maxLines: 2,
          maxLength: 120,
          style: AppTextStyles.bodySm,
          decoration: InputDecoration(
            hintText: 'Escreva algo ou deixe em branco para o unicórnio criar',
            hintStyle: AppTextStyles.caption,
            counterStyle: AppTextStyles.caption,
            filled: true,
            fillColor: AppColors.surf,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _enviando
                ? null
                : () => _motivar(vinculo['together_id'] as String),
            icon: const Icon(Icons.favorite_rounded, size: 18),
            label: Text(_enviando ? 'Enviando…' : 'Enviar incentivo',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pur,
              foregroundColor: AppColors.bg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _convidar(String parceiroId) async {
    HapticFeedback.mediumImpact();
    setState(() => _enviando = true);
    try {
      await JejumApiService.togetherConvite(
        familiaId: widget.familiaId,
        usuarioA: widget.membroId,
        usuarioB: parceiroId,
      );
      if (!mounted) return;
      ref.invalidate(jejumTogetherProvider(_args));
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fast Together ativado! 🤝'),
          backgroundColor: AppColors.grn,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  Future<void> _motivar(String togetherId) async {
    HapticFeedback.mediumImpact();
    setState(() => _enviando = true);
    try {
      await JejumApiService.togetherMotivar(
        togetherId: togetherId,
        remetenteId: widget.membroId,
        mensagem: _msgCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incentivo enviado! 💜'),
          backgroundColor: AppColors.grn,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.org,
        ),
      );
    }
  }
}
