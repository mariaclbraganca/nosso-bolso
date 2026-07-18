import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../services/saude_api_service.dart';
import '../../../providers/saude_provider.dart';

class RegistrarRefeicaoSheet extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;
  final String? initialTipo;

  const RegistrarRefeicaoSheet({
    super.key,
    required this.membroId,
    required this.familiaId,
    this.initialTipo,
  });

  @override
  ConsumerState<RegistrarRefeicaoSheet> createState() => _RegistrarRefeicaoSheetState();
}

class _RegistrarRefeicaoSheetState extends ConsumerState<RegistrarRefeicaoSheet> {
  final _descCtrl   = TextEditingController();
  final _kcalCtrl   = TextEditingController();
  final _protCtrl   = TextEditingController();
  final _carbCtrl   = TextEditingController();
  final _gordCtrl   = TextEditingController();
  final _pesoCtrl   = TextEditingController();
  bool _isLoading   = false;
  late String _tipo;

  static const _tipos = [
    ('cafe_da_manha', '☕ Café da manhã'),
    ('almoco',        '🍽️ Almoço'),
    ('lanche_tarde',  '🍪 Lanche'),
    ('jantar',        '🌙 Jantar'),
    ('lanche_noturno','🌛 Lanche noturno'),
  ];

  @override
  void initState() {
    super.initState();
    _tipo = widget.initialTipo ?? 'cafe_da_manha';
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _kcalCtrl.dispose();
    _protCtrl.dispose();
    _carbCtrl.dispose();
    _gordCtrl.dispose();
    _pesoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      _snack('Informe o que você comeu', AppColors.org);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final hoje = DateTime.now();
      final data = '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';
      await SaudeApiService.registrarRefeicao({
        'membro_id':      widget.membroId,
        'familia_id':     widget.familiaId,
        'tipo_refeicao':  _tipo,
        'descricao':      desc,
        'calorias_kcal':  double.tryParse(_kcalCtrl.text) ?? 0,
        'data':           data,
        if (double.tryParse(_protCtrl.text) != null) 'proteina_g':     double.parse(_protCtrl.text),
        if (double.tryParse(_carbCtrl.text) != null) 'carboidrato_g':  double.parse(_carbCtrl.text),
        if (double.tryParse(_gordCtrl.text) != null) 'gordura_g':      double.parse(_gordCtrl.text),
        if (double.tryParse(_pesoCtrl.text) != null) 'peso_g':         double.parse(_pesoCtrl.text),
      });
      ref.invalidate(refeicoesDiaProvider);
      ref.invalidate(extratoDiarioProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Erro: $e', AppColors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Registrar Refeição', style: AppTextStyles.title),
            ),
            const Divider(color: AppColors.bord, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tipo de refeição
                    Text('Tipo de refeição', style: AppTextStyles.caption),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _tipos.map((t) {
                          final sel = _tipo == t.$1;
                          return GestureDetector(
                            onTap: () => setState(() => _tipo = t.$1),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: sel ? AppColors.grn.withOpacity(0.15) : AppColors.surf,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                                border: Border.all(
                                  color: sel ? AppColors.grn : AppColors.bord,
                                  width: sel ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                t.$2,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: sel ? AppColors.grn : AppColors.mu,
                                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Descrição
                    _field(_descCtrl, 'O que você comeu? *', TextInputType.text),
                    const SizedBox(height: 12),
                    _field(_kcalCtrl, 'Calorias (kcal)', TextInputType.number),
                    const SizedBox(height: 12),

                    // Macros em linha
                    Row(children: [
                      Expanded(child: _field(_protCtrl, 'Proteína (g)', TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: _field(_carbCtrl, 'Carboidrato (g)', TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: _field(_gordCtrl, 'Gordura (g)', TextInputType.number)),
                    ]),
                    const SizedBox(height: 12),
                    _field(_pesoCtrl, 'Quantidade (g/ml) — opcional', TextInputType.number),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _salvar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.grn,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Registrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _field(TextEditingController ctrl, String hint, TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.caption,
        filled: true,
        fillColor: AppColors.surf,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn), borderSide: const BorderSide(color: AppColors.bord)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn), borderSide: const BorderSide(color: AppColors.bord)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn), borderSide: const BorderSide(color: AppColors.grn, width: 1.5)),
      ),
    );
  }
}
