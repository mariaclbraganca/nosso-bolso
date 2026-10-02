import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/envelopes_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/api_service.dart';
import '../../constants.dart';
import '../../utils/moeda.dart';
import 'widgets/remanejar_widgets.dart';

class RemanejSaldoSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> origem;

  const RemanejSaldoSheet({super.key, required this.origem});

  @override
  ConsumerState<RemanejSaldoSheet> createState() => _RemanejSaldoSheetState();
}

class _RemanejSaldoSheetState extends ConsumerState<RemanejSaldoSheet> {
  final _valorController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _destinoId;
  bool _carregando = false;

  static final _fmt = NumberFormat('R\$ #,##0.00', 'pt_BR');

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _transferir() async {
    if (!_formKey.currentState!.validate()) return;
    if (_destinoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selecione o envelope destino', style: AppTextStyles.bodySm),
          backgroundColor: AppColors.org,
        ),
      );
      return;
    }

    setState(() => _carregando = true);
    try {
      final perfil = ref.read(perfilUsuarioLogadoProvider).value;
      if (perfil == null) throw Exception('Usuário não autenticado');

      final valor = parseMoeda(_valorController.text);
      final origemId = widget.origem['id'] as String;

      await ApiService.post('/remanejar/', {
        'origem_id': origemId,
        'destino_id': _destinoId,
        'valor': valor,
        'familia_id': perfil['familia_id'],
        'usuario_id': perfil['id'],
      });

      await supabase.from('remanejamentos_log').insert({
        'familia_id': perfil['familia_id'],
        'usuario_id': perfil['id'],
        'envelope_origem_id': origemId,
        'envelope_destino_id': _destinoId,
        'valor': valor,
        'descricao': 'Remanejamento de ${widget.origem['nome_envelope']} para destino',
      });

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(true);
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Saldo de ${_fmt.format(valor)} remanejado com sucesso! ✨'),
                ),
              ],
            ),
            backgroundColor: AppColors.grn,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e', style: AppTextStyles.bodySm),
            backgroundColor: AppColors.red,
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
    final origemId = widget.origem['id'] as String;
    final destinos = envelopes.where((e) => e['id'] != origemId).toList();
    final origemNome = widget.origem['nome_envelope'] as String? ?? '—';
    final origemEmoji = widget.origem['emoji'] as String? ?? '📦';
    final saldoOrigem = (widget.origem['saldo_atual'] as num?)?.toDouble() ?? 0;
    final podeTransferir = saldoOrigem > 0;
    final bottom = MediaQuery.of(context).viewInsets.bottom + 20;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.pagePad, 0, AppSpacing.pagePad, bottom),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 20),
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
                  Text('Remanejar Saldo', style: AppTextStyles.title),
                  const SizedBox(height: 16),
                  RemanejarOrigemCard(
                    emoji: origemEmoji,
                    nome: origemNome,
                    saldo: saldoOrigem,
                  ),
                  const SizedBox(height: 20),
                  Text('Destino', style: AppTextStyles.bodySm.copyWith(color: AppColors.mu)),
                  const SizedBox(height: 8),
                  RemanejarDestinoSelector(
                    destinos: destinos,
                    destinoId: _destinoId,
                    onChanged: podeTransferir ? (v) => setState(() => _destinoId = v) : (_) {},
                  ),
                  const SizedBox(height: 20),
                  RemanejarValorInput(
                    controller: _valorController,
                    saldoOrigem: saldoOrigem,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_carregando || !podeTransferir) ? null : _transferir,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bg,
                        disabledBackgroundColor: AppColors.gold.withOpacity(0.3),
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
                              podeTransferir ? 'Transferir Agora' : 'Saldo insuficiente',
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
        ),
      ),
    );
  }
}
