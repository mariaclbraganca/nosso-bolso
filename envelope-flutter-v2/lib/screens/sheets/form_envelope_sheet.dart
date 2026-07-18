import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/api_service.dart';
import 'abastecer_sheet.dart';

const _emojis = [
  '📦', '💊', '🍎', '🏠', '🚗', '🎮', '💡', '🧼',
  '🎓', '✈️', '🐕', '🎵', '💄', '🏋️',
];

class FormEnvelopeSheet extends ConsumerStatefulWidget {
  /// Se não nulo, entra em modo edição
  final Map<String, dynamic>? envelope;

  const FormEnvelopeSheet({super.key, this.envelope});

  @override
  ConsumerState<FormEnvelopeSheet> createState() => _FormEnvelopeSheetState();
}

class _FormEnvelopeSheetState extends ConsumerState<FormEnvelopeSheet> {
  final _nomeController = TextEditingController();
  final _metaMensalController = TextEditingController();
  final _metaTotalController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _emojiSelecionado = '📦';
  bool _eReserva = false;
  bool _carregando = false;
  bool _excluindo = false;

  bool get _editando => widget.envelope != null;

  @override
  void initState() {
    super.initState();
    final env = widget.envelope;
    if (env != null) {
      _nomeController.text = env['nome_envelope'] as String? ?? '';
      _emojiSelecionado = env['emoji'] as String? ?? '📦';
      final meta = (env['valor_planejado'] as num?)?.toDouble() ?? 0;
      if (meta > 0) {
        _metaMensalController.text =
            NumberFormat('#,##0.00', 'pt_BR').format(meta);
      }
      _eReserva = env['e_reserva'] as bool? ?? false;
      final metaTotal = (env['meta_total'] as num?)?.toDouble() ?? 0;
      if (metaTotal > 0) {
        _metaTotalController.text =
            NumberFormat('#,##0.00', 'pt_BR').format(metaTotal);
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _metaMensalController.dispose();
    _metaTotalController.dispose();
    super.dispose();
  }

  double _parseValor(String text) {
    if (text.trim().isEmpty) return 0;
    return double.tryParse(
          text.replaceAll('.', '').replaceAll(',', '.'),
        ) ??
        0;
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      final perfil = ref.read(perfilUsuarioLogadoProvider).value;
      if (perfil == null) throw Exception('Usuário não autenticado');

      final data = <String, dynamic>{
        'nome_envelope': _nomeController.text.trim(),
        'emoji': _emojiSelecionado,
        'valor_planejado': _parseValor(_metaMensalController.text),
        'e_reserva': _eReserva,
        'meta_total':
            _eReserva ? _parseValor(_metaTotalController.text) : null,
        'familia_id': perfil['familia_id'],
        'usuario_id': perfil['id'],
      };

      if (_editando) {
        final id = widget.envelope!['id'] as int;
        await ApiService.put('/envelopes/$id', data);
        if (mounted) Navigator.of(context).pop(true);
      } else {
        await ApiService.post('/envelopes/', data);
        if (!mounted) return;
        Navigator.of(context).pop(true);
        await _perguntarAbastecer();
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

  Future<void> _excluir() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: const BorderSide(color: AppColors.bord, width: 0.5),
        ),
        title: Text('Excluir envelope?', style: AppTextStyles.titleSm),
        content: Text(
          'Esta ação não pode ser desfeita. O saldo do envelope será perdido.',
          style: AppTextStyles.body.copyWith(color: AppColors.mu),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(
              'Cancelar',
              style: AppTextStyles.body.copyWith(color: AppColors.mu),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(
              'Excluir',
              style: AppTextStyles.body.copyWith(color: AppColors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _excluindo = true);
    try {
      final perfil = ref.read(perfilUsuarioLogadoProvider).value;
      final id = widget.envelope!['id'] as int;
      await ApiService.delete(
        '/envelopes/$id',
        familiaId: perfil?['familia_id']?.toString(),
      );
      if (mounted) Navigator.of(context).pop('deleted');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e', style: AppTextStyles.bodySm),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _excluindo = false);
    }
  }

  Future<void> _perguntarAbastecer() async {
    if (!mounted) return;
    final resposta = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: const BorderSide(color: AppColors.bord, width: 0.5),
        ),
        title: Text(
          'Abastecer envelope agora?',
          style: AppTextStyles.titleSm,
        ),
        content: Text(
          'Deseja adicionar saldo a este envelope agora?',
          style: AppTextStyles.body.copyWith(color: AppColors.mu),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(
              'Depois',
              style: AppTextStyles.body.copyWith(color: AppColors.mu),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(
              'Sim, agora',
              style: AppTextStyles.body.copyWith(color: AppColors.acc),
            ),
          ),
        ],
      ),
    );

    if (resposta == true && mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AbastecerSheet(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom + 20;
    final titulo = _editando ? 'Editar Envelope 📦' : 'Novo Envelope 📦';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pagePad,
            0,
            AppSpacing.pagePad,
            bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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

                // Titulo
                Text(titulo, style: AppTextStyles.title),
                const SizedBox(height: 24),

                // Nome
                Text(
                  'Nome',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nomeController,
                  autofocus: !_editando,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: 'Ex: Alimentação, Saúde…',
                    hintStyle:
                        AppTextStyles.body.copyWith(color: AppColors.mu),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Informe o nome do envelope';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Meta mensal + Emoji
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meta mensal
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Meta Mensal (R\$)',
                            style: AppTextStyles.bodySm
                                .copyWith(color: AppColors.mu),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _metaMensalController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\d,.]'),
                              ),
                            ],
                            style: AppTextStyles.mono.copyWith(
                              fontSize: 16,
                              color: AppColors.acc,
                            ),
                            decoration: InputDecoration(
                              hintText: '0,00',
                              hintStyle: AppTextStyles.mono.copyWith(
                                fontSize: 16,
                                color: AppColors.mu,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Dropdown emoji
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emoji',
                          style: AppTextStyles.bodySm
                              .copyWith(color: AppColors.mu),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 90,
                          decoration: BoxDecoration(
                            color: AppColors.surf,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusInput,
                            ),
                            border: const Border.fromBorderSide(
                              BorderSide(color: AppColors.bord),
                            ),
                          ),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _emojiSelecionado,
                              dropdownColor: AppColors.surf,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.mu,
                                size: 18,
                              ),
                              items: _emojis.map((e) {
                                return DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    e,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _emojiSelecionado = v);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Switch reserva
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surf,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusCard),
                    border: const Border.fromBorderSide(
                      BorderSide(color: AppColors.bord, width: 0.5),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('É Reserva?', style: AppTextStyles.body),
                            Text(
                              'Separa o dinheiro como meta de longo prazo',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _eReserva,
                        onChanged: (v) => setState(() => _eReserva = v),
                      ),
                    ],
                  ),
                ),

                // Campo valor objetivo (visível se reserva)
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: _eReserva
                      ? Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Valor Objetivo (Meta Total)',
                                style: AppTextStyles.bodySm
                                    .copyWith(color: AppColors.mu),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _metaTotalController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[\d,.]'),
                                  ),
                                ],
                                style: AppTextStyles.mono.copyWith(
                                  fontSize: 16,
                                  color: AppColors.gold,
                                ),
                                decoration: InputDecoration(
                                  hintText: '0,00',
                                  hintStyle: AppTextStyles.mono.copyWith(
                                    fontSize: 16,
                                    color: AppColors.mu,
                                  ),
                                  prefixText: 'R\$ ',
                                  prefixStyle: AppTextStyles.bodySm
                                      .copyWith(color: AppColors.mu),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),

                // Botão salvar
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _carregando ? null : _salvar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.acc,
                      foregroundColor: AppColors.bg,
                      disabledBackgroundColor:
                          AppColors.acc.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusBtn,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: _carregando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.bg,
                            ),
                          )
                        : Text(
                            _editando ? 'Salvar alterações' : 'Criar envelope',
                            style: AppTextStyles.titleSm.copyWith(
                              color: AppColors.bg,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                // Botão excluir (somente em edição)
                if (_editando) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: _excluindo ? null : _excluir,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusBtn,
                          ),
                          side: BorderSide(
                            color: AppColors.red.withOpacity(0.3),
                          ),
                        ),
                      ),
                      child: _excluindo
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.red,
                              ),
                            )
                          : Text(
                              'EXCLUIR ENVELOPE',
                              style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.red,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ],

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
