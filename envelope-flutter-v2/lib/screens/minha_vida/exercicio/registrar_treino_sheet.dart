import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../services/exercicio_api_service.dart';
import '../../../providers/exercicio_provider.dart';

class RegistrarTreinoSheet extends ConsumerStatefulWidget {
  final String membroId;

  const RegistrarTreinoSheet({super.key, required this.membroId});

  @override
  ConsumerState<RegistrarTreinoSheet> createState() => _RegistrarTreinoSheetState();
}

class _RegistrarTreinoSheetState extends ConsumerState<RegistrarTreinoSheet> {
  final _nomeCtrl     = TextEditingController();
  final _kcalCtrl     = TextEditingController();
  final _duracaoCtrl  = TextEditingController();
  final _seriesCtrl   = TextEditingController();
  final _repsCtrl     = TextEditingController();
  final _pesoCtrl     = TextEditingController();
  bool _isLoading     = false;
  String _tipo        = 'musculacao';

  static const _tipos = [
    ('musculacao',  '🏋️ Musculação'),
    ('cardio',      '🏃 Cardio'),
    ('yoga',        '🧘 Yoga'),
    ('funcional',   '⚡ Funcional'),
    ('natacao',     '🏊 Natação'),
    ('ciclismo',    '🚴 Ciclismo'),
    ('outro',       '💪 Outro'),
  ];

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _kcalCtrl.dispose();
    _duracaoCtrl.dispose();
    _seriesCtrl.dispose();
    _repsCtrl.dispose();
    _pesoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) {
      _snack('Informe o nome do exercício', AppColors.org);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ExercicioApiService.registrarTreino(
        membroId:        widget.membroId,
        tipo:            _tipo,
        nomeExercicio:   nome,
        caloriasKcal:    double.tryParse(_kcalCtrl.text) ?? 0,
        duracaoMinutos:  int.tryParse(_duracaoCtrl.text),
        series:          int.tryParse(_seriesCtrl.text),
        repeticoes:      int.tryParse(_repsCtrl.text),
        pesoKg:          double.tryParse(_pesoCtrl.text.replaceAll(',', '.')),
      );
      ref.invalidate(exercicioDiaProvider);
      ref.invalidate(historicoExercicioProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Erro: $e', AppColors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
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
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Registrar Treino', style: AppTextStyles.title),
            ),
            const Divider(color: AppColors.bord, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tipo de treino', style: AppTextStyles.caption),
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
                                color: sel ? AppColors.org.withOpacity(0.15) : AppColors.surf,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                                border: Border.all(color: sel ? AppColors.org : AppColors.bord, width: sel ? 1.5 : 1),
                              ),
                              child: Text(t.$2, style: TextStyle(fontSize: 12, color: sel ? AppColors.org : AppColors.mu, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(_nomeCtrl, 'Nome do exercício *', TextInputType.text),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _field(_duracaoCtrl, 'Duração (min)', TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: _field(_kcalCtrl, 'Calorias (kcal)', TextInputType.number)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _field(_seriesCtrl, 'Séries', TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: _field(_repsCtrl, 'Repetições', TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: _field(_pesoCtrl, 'Peso (kg)', TextInputType.number)),
                    ]),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _salvar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.org,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Registrar Treino', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn), borderSide: const BorderSide(color: AppColors.org, width: 1.5)),
      ),
    );
  }
}
