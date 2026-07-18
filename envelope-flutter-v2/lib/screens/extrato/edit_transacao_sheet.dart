import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/envelopes_provider.dart';
import '../../services/api_service.dart';

/// Sheet para editar uma transação existente.
/// Abre via showModalBottomSheet — sem Scaffold próprio.
class EditTransacaoSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> transacao;

  const EditTransacaoSheet({super.key, required this.transacao});

  @override
  ConsumerState<EditTransacaoSheet> createState() => _EditTransacaoSheetState();
}

class _EditTransacaoSheetState extends ConsumerState<EditTransacaoSheet> {
  late TextEditingController _descricaoCtrl;
  late TextEditingController _valorCtrl;
  String? _envelopeId;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _descricaoCtrl = TextEditingController(
      text: widget.transacao['descricao']?.toString() ?? '',
    );
    final val = (widget.transacao['valor'] as num?)?.toDouble() ?? 0.0;
    _valorCtrl = TextEditingController(
      text: val.toStringAsFixed(2).replaceAll('.', ','),
    );
    _envelopeId = widget.transacao['envelope_id']?.toString();
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  double? _parseValor() {
    final raw = _valorCtrl.text.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(raw);
  }

  Future<void> _salvar() async {
    final id = widget.transacao['id']?.toString();
    if (id == null) return;

    final valor = _parseValor();
    if (valor == null || valor <= 0) {
      setState(() => _erro = 'Valor inválido');
      return;
    }
    if (_descricaoCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Informe a descrição');
      return;
    }

    setState(() { _salvando = true; _erro = null; });

    try {
      await ApiService.patch('/transacoes/$id', {
        'descricao': _descricaoCtrl.text.trim(),
        'valor': valor,
        if (_envelopeId != null) 'envelope_id': _envelopeId,
      });

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _erro = 'Erro ao salvar: $e';
        _salvando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final envelopesAsync = ref.watch(envelopesProvider);
    final envelopes = envelopesAsync.value ?? [];
    final mq = MediaQuery.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePad, 20,
        AppSpacing.pagePad, mq.viewInsets.bottom + AppSpacing.pagePad,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.bord,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Título
            Row(
              children: [
                const Icon(Icons.edit_outlined, color: AppColors.acc, size: 20),
                const SizedBox(width: 8),
                Text('Editar Transação', style: AppTextStyles.titleSm),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // Campo Valor (grande, centralizado)
            Center(
              child: Column(
                children: [
                  Text('Valor', style: AppTextStyles.caption),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _valorCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.monoLg.copyWith(color: AppColors.acc),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surf,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                          borderSide: BorderSide.none,
                        ),
                        prefixText: 'R\$ ',
                        prefixStyle: AppTextStyles.monoLg.copyWith(
                          color: AppColors.mu,
                          fontSize: 18,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sectionGap),

            // Campo Descrição
            Text('Descrição', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.itemGap),
            TextField(
              controller: _descricaoCtrl,
              style: AppTextStyles.body,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Ex: Mercado, Gasolina...',
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.mu),
              ),
            ),

            const SizedBox(height: AppSpacing.sectionGap),

            // Seletor de Envelope
            Text('Envelope', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.itemGap),

            if (envelopesAsync.isLoading)
              const Center(
                child: SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.acc),
                ),
              )
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppSpacing.cardGap,
                mainAxisSpacing: AppSpacing.cardGap,
                childAspectRatio: 3.0,
                children: envelopes.map((env) {
                  final id = env['id']?.toString() ?? '';
                  final nome = env['nome_envelope'] as String? ?? '';
                  final emoji = env['emoji'] as String? ?? '💰';
                  final selected = _envelopeId == id;

                  return GestureDetector(
                    onTap: () => setState(() => _envelopeId = id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.acc.withOpacity(0.12)
                            : AppColors.surf,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                        border: Border.all(
                          color: selected ? AppColors.acc : AppColors.bord,
                          width: selected ? 1.0 : 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              nome,
                              style: AppTextStyles.bodySm.copyWith(
                                color: selected ? AppColors.acc : AppColors.tx,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle, color: AppColors.acc, size: 14),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: AppSpacing.sectionGap),

            // Erro
            if (_erro != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                  border: Border.all(color: AppColors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_erro!,
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.red)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Botão Salvar
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _salvando ? null : _salvar,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.acc,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                  ),
                ),
                child: _salvando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.bg,
                        ),
                      )
                    : Text('Salvar', style: AppTextStyles.body.copyWith(
                        color: AppColors.bg,
                        fontWeight: FontWeight.w600,
                      )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Abre a sheet de edição e retorna true se houve alteração.
Future<bool?> showEditTransacaoSheet(
  BuildContext context,
  Map<String, dynamic> transacao,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EditTransacaoSheet(transacao: transacao),
  );
}
