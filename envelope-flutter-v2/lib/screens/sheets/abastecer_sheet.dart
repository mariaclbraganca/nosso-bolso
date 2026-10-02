import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/envelopes_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/api_service.dart';
import '../../utils/moeda.dart';
import '../../widgets/abastecer_envelope_item.dart';

/// DEFINIR METAS dos envelopes (planejamento mensal visual, sem mover saldo).
class AbastecerSheet extends ConsumerStatefulWidget {
  const AbastecerSheet({super.key});

  @override
  ConsumerState<AbastecerSheet> createState() => _AbastecerSheetState();
}

class _AbastecerSheetState extends ConsumerState<AbastecerSheet> {
  final Map<String, TextEditingController> _controllers = {};
  bool _carregando = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlFor(String id, double metaAtual) {
    return _controllers.putIfAbsent(
      id,
      () => TextEditingController(
        text: metaAtual > 0
            ? NumberFormat.currency(locale: 'pt_BR', symbol: '').format(metaAtual).trim()
            : '',
      ),
    );
  }

  double _calcularTotalPlanejado() {
    double total = 0.0;
    for (final c in _controllers.values) {
      total += parseMoeda(c.text);
    }
    return total;
  }

  Future<void> _confirmar(
    List<Map<String, dynamic>> envelopes,
    Map<String, dynamic> perfil,
  ) async {
    final familiaId = perfil['familia_id'];
    setState(() => _carregando = true);
    try {
      int erros = 0;
      for (final env in envelopes) {
        final id = env['id'] as String;
        final ctrl = _controllers[id];
        if (ctrl == null) continue;
        final valor = parseMoeda(ctrl.text);
        if (valor < 0) continue;
        try {
          await ApiService.put(
            '/envelopes/$id?familia_id=$familiaId',
            {'valor_planejado': valor},
          );
        } catch (_) {
          erros++;
        }
      }
      ref.invalidate(envelopesProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              erros > 0
                  ? 'Metas salvas com aviso: $erros envelopes não puderam ser atualizados.'
                  : '🎯 Metas dos envelopes atualizadas com sucesso!',
            ),
            backgroundColor: erros > 0 ? AppColors.org : AppColors.grn,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e', style: AppTextStyles.bodySm),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final envelopes = ref.watch(envelopesProvider).value ?? [];
    final perfil = ref.watch(perfilUsuarioLogadoProvider).value;
    final bottom = MediaQuery.of(context).viewInsets.bottom + 20;
    final totalPlanejado = _calcularTotalPlanejado();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.mu.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(AppSpacing.pagePad, 16, AppSpacing.pagePad, bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Definir metas dos envelopes 🎯', style: AppTextStyles.title),
                    const SizedBox(height: 6),
                    Text(
                      'Quanto você pretende gastar em cada um neste mês',
                      style: AppTextStyles.caption.copyWith(color: AppColors.mu),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surf,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      ),
                      child: Text(
                        '💡 A meta é um guia de gasto mensal. Ela não move dinheiro entre contas — '
                        'ajuda a visualizar quanto planeja gastar por categoria.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.mu, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AbastecerTotalCard(total: totalPlanejado),
                    const SizedBox(height: 14),
                    if (envelopes.isEmpty)
                      Center(child: Text('Nenhum envelope encontrado', style: AppTextStyles.caption))
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: envelopes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.cardGap),
                        itemBuilder: (context, index) {
                          final env = envelopes[index];
                          final id = env['id'] as String;
                          final ctrl = _ctrlFor(
                            id,
                            (env['valor_planejado'] as num?)?.toDouble() ?? 0,
                          );
                          return AbastecerEnvelopeTile(
                            emoji: env['emoji'] as String? ?? '📦',
                            nome: env['nome_envelope'] as String? ?? '—',
                            controller: ctrl,
                            onChanged: () => setState(() {}),
                          );
                        },
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_carregando || perfil == null)
                            ? null
                            : () => _confirmar(envelopes, perfil),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.acc,
                          foregroundColor: AppColors.bg,
                          disabledBackgroundColor: AppColors.acc.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                          ),
                          elevation: 0,
                        ),
                        child: _carregando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                              )
                            : Text(
                                'Salvar metas',
                                style: AppTextStyles.titleSm.copyWith(
                                  color: AppColors.bg,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
