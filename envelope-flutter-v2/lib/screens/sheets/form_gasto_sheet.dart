import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../providers/envelopes_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/api_service.dart';
import '../../utils/moeda.dart';
import 'widgets/form_gasto_widgets.dart';

class FormGastoSheet extends ConsumerStatefulWidget {
  final String? initialEnvelopeId;

  const FormGastoSheet({super.key, this.initialEnvelopeId});

  @override
  ConsumerState<FormGastoSheet> createState() => _FormGastoSheetState();
}

class _FormGastoSheetState extends ConsumerState<FormGastoSheet> {
  final _valorController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _envelopeSelecionadoId;
  XFile? _comprovante;
  bool _carregando = false;
  String _formaPagamento = 'credito';

  @override
  void initState() {
    super.initState();
    _envelopeSelecionadoId = widget.initialEnvelopeId;
  }

  @override
  void dispose() {
    _valorController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _pickImagem() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (picked != null) setState(() => _comprovante = picked);
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_envelopeSelecionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selecione um envelope', style: AppTextStyles.bodySm),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() => _carregando = true);
    try {
      final perfil = ref.read(perfilUsuarioLogadoProvider).value;
      if (perfil == null) throw Exception('Usuário não autenticado');

      final valor = parseMoeda(_valorController.text);
      final data = <String, dynamic>{
        'valor': valor,
        'tipo': 'despesa',
        'envelope_id': _envelopeSelecionadoId,
        'usuario_id': perfil['id'],
        'familia_id': perfil['familia_id'],
        'descricao': _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        'forma_pagamento': _formaPagamento,
      };

      await ApiService.post('/transacoes/', data);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(true);
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Gasto de R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')} registrado!'),
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
    final bottom = MediaQuery.of(context).viewInsets.bottom + 20;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.95,
      ),
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
                  Text('Registrar gasto 💸', style: AppTextStyles.title),
                  const SizedBox(height: 4),
                  Text('máx. 4 toques ⚡', style: AppTextStyles.caption),
                  const SizedBox(height: 24),
                  GastoValorInput(controller: _valorController),
                  const SizedBox(height: 20),
                  Text('Envelope', style: AppTextStyles.bodySm.copyWith(color: AppColors.mu)),
                  const SizedBox(height: 8),
                  GastoEnvelopeGrid(
                    envelopes: envelopes,
                    envelopeSelecionadoId: _envelopeSelecionadoId,
                    onSelect: (id) => setState(() => _envelopeSelecionadoId = id),
                  ),
                  const SizedBox(height: 20),
                  Text('Forma de pagamento', style: AppTextStyles.bodySm.copyWith(color: AppColors.mu)),
                  const SizedBox(height: 8),
                  FormaPagamentoChips(
                    formaPagamento: _formaPagamento,
                    onSelect: (f) => setState(() => _formaPagamento = f),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('campo_descricao'),
                          controller: _descricaoController,
                          style: AppTextStyles.body,
                          decoration: InputDecoration(
                            hintText: 'Descrição (opcional)',
                            hintStyle: AppTextStyles.body.copyWith(color: AppColors.mu),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _pickImagem,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: _comprovante != null ? AppColors.acc.withOpacity(0.15) : AppColors.surf,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                            border: Border.all(
                              color: _comprovante != null ? AppColors.acc : AppColors.bord,
                            ),
                          ),
                          child: _comprovante != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                                  child: Image.file(File(_comprovante!.path), fit: BoxFit.cover),
                                )
                              : const Icon(Icons.camera_alt_outlined, color: AppColors.mu, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      key: const Key('btn_registrar_gasto'),
                      onPressed: _carregando ? null : _registrar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.red,
                        foregroundColor: AppColors.tx,
                        disabledBackgroundColor: AppColors.red.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                        ),
                        elevation: 0,
                      ),
                      child: _carregando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.tx),
                            )
                          : Text('Registrar gasto', style: AppTextStyles.titleSm.copyWith(color: AppColors.tx)),
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
