import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../providers/envelopes_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/api_service.dart';

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

      final rawValor = _valorController.text
          .replaceAll('.', '')
          .replaceAll(',', '.');
      final valor = double.parse(rawValor);

      final data = <String, dynamic>{
        'valor': valor,
        'tipo': 'despesa',
        'envelope_id': _envelopeSelecionadoId,
        'usuario_id': perfil['id'],
        'familia_id': perfil['familia_id'],
        'descricao': _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
      };

      // TODO: upload do comprovante e adicionar comprovante_url
      // if (_comprovante != null) { ... }

      await ApiService.post('/transacoes/', data);

      if (mounted) Navigator.of(context).pop(true);
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
    final envelopesAsync = ref.watch(envelopesProvider);
    final envelopes = envelopesAsync.value ?? [];
    final bottom = MediaQuery.of(context).viewInsets.bottom + 20;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pagePad,
            0,
            AppSpacing.pagePad,
            bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
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

                // Cabeçalho
                Text('Registrar gasto 💸', style: AppTextStyles.title),
                const SizedBox(height: 4),
                Text(
                  'máx. 4 toques ⚡',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 24),

                // Campo Valor
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surf,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    border: Border.all(
                      color: AppColors.red.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'R\$',
                        style: AppTextStyles.titleSm.copyWith(
                          color: AppColors.red.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: const Key('campo_valor'),
                          controller: _valorController,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[\d,.]'),
                            ),
                          ],
                          textAlign: TextAlign.center,
                          style: AppTextStyles.mono.copyWith(
                            fontSize: 44,
                            color: AppColors.red,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            filled: false,
                            border: InputBorder.none,
                            hintText: '0,00',
                            hintStyle: AppTextStyles.mono.copyWith(
                              fontSize: 44,
                              color: AppColors.red.withOpacity(0.3),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Informe o valor';
                            }
                            final raw = v.replaceAll('.', '').replaceAll(',', '.');
                            final n = double.tryParse(raw);
                            if (n == null || n <= 0) return 'Valor inválido';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Label envelopes
                Text('Envelope', style: AppTextStyles.bodySm.copyWith(color: AppColors.mu)),
                const SizedBox(height: 8),

                // Grid de envelopes
                if (envelopes.isEmpty)
                  Center(
                    child: Text(
                      'Nenhum envelope encontrado',
                      style: AppTextStyles.caption,
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 3.2,
                      crossAxisSpacing: AppSpacing.cardGap,
                      mainAxisSpacing: AppSpacing.cardGap,
                    ),
                    itemCount: envelopes.length,
                    itemBuilder: (context, index) {
                      final env = envelopes[index];
                      final id = env['id'] as String;
                      final selecionado = _envelopeSelecionadoId == id;
                      final emoji = env['emoji'] as String? ?? '📦';
                      final nome = env['nome_envelope'] as String? ?? '—';

                      return GestureDetector(
                        onTap: () => setState(
                          () => _envelopeSelecionadoId = id,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: selecionado
                                ? AppColors.acc.withOpacity(0.12)
                                : AppColors.surf,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusChip,
                            ),
                            border: Border.all(
                              color: selecionado
                                  ? AppColors.acc
                                  : AppColors.bord,
                              width: selecionado ? 1.5 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          child: Row(
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  nome,
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: selecionado
                                        ? AppColors.acc
                                        : AppColors.tx,
                                    fontWeight: selecionado
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),

                // Campo descrição + botão câmera
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('campo_descricao'),
                        controller: _descricaoController,
                        style: AppTextStyles.body,
                        decoration: InputDecoration(
                          hintText: 'Descrição (opcional)',
                          hintStyle: AppTextStyles.body.copyWith(
                            color: AppColors.mu,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _pickImagem,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _comprovante != null
                              ? AppColors.acc.withOpacity(0.15)
                              : AppColors.surf,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusInput,
                          ),
                          border: Border.all(
                            color: _comprovante != null
                                ? AppColors.acc
                                : AppColors.bord,
                          ),
                        ),
                        child: _comprovante != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusInput,
                                ),
                                child: Image.file(
                                  File(_comprovante!.path),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_outlined,
                                color: AppColors.mu,
                                size: 22,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Botão registrar
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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.tx,
                            ),
                          )
                        : Text(
                            'Registrar gasto',
                            style: AppTextStyles.titleSm.copyWith(
                              color: AppColors.tx,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
