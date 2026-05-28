import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/usuarios_provider.dart';
import '../../providers/exercicio_provider.dart';
import '../../providers/saude_provider.dart';
import '../../services/saude_api_service.dart';
import '../../providers/unicorn_team.dart';

class RegistrarTreinoSheet extends ConsumerStatefulWidget {
  final String data; // YYYY-MM-DD
  final VoidCallback onSaved;

  const RegistrarTreinoSheet({
    super.key,
    required this.data,
    required this.onSaved,
  });

  @override
  ConsumerState<RegistrarTreinoSheet> createState() => _RegistrarTreinoSheetState();
}

class _RegistrarTreinoSheetState extends ConsumerState<RegistrarTreinoSheet> {
  String _categoriaFiltro = 'cardio';
  Map<String, dynamic>? _exercicioSelecionado;
  int _duracaoMin = 30;
  bool _salvando = false;

  @override
  Widget build(BuildContext context) {
    final catalogoAsync = ref.watch(catalogoExerciciosProvider);
    final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
    final membroId = perfil?['id'] as String? ?? '';
    final metabolicoAsync = ref.watch(perfilMetabolicoProvider(membroId));
    final pesoKg = (metabolicoAsync.asData?.value?['antropometria']?['peso_kg'] as num?)
            ?.toDouble() ?? 70.0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandle(),
          const SizedBox(height: 12),
          const Text(
            'Registrar Treino',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.tx),
          ),
          const SizedBox(height: 16),
          _buildCategoryFilter(),
          const SizedBox(height: 12),
          catalogoAsync.when(
            data: (lista) => _buildExerciseList(lista),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: AppColors.org),
              ),
            ),
            error: (e, _) => Center(
              child: Text('Erro ao carregar exercícios', style: TextStyle(color: AppColors.red)),
            ),
          ),
          if (_exercicioSelecionado != null) ...[
            const SizedBox(height: 16),
            _buildDurationPicker(),
            const SizedBox(height: 12),
            _buildCaloriePreview(pesoKg),
            const SizedBox(height: 16),
            _buildSaveButton(perfil, membroId),
          ],
        ],
      ),
    );
  }

  Widget _buildHandle() => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.bord,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categorias.map((cat) {
          final selected = cat == _categoriaFiltro;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() {
                _categoriaFiltro = cat;
                _exercicioSelecionado = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? AppColors.org.withOpacity(0.2) : AppColors.surf,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.org : AppColors.bord,
                    width: selected ? 1.5 : 0.5,
                  ),
                ),
                child: Text(
                  '${categoriaEmoji[cat]} ${categoriaNome[cat]}',
                  style: TextStyle(
                    fontSize: 13,
                    color: selected ? AppColors.org : AppColors.mu,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExerciseList(List<Map<String, dynamic>> catalogo) {
    final filtered = catalogo.where((e) => e['categoria'] == _categoriaFiltro).toList();

    return SizedBox(
      height: 180,
      child: ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, i) {
          final ex = filtered[i];
          final selected = _exercicioSelecionado?['nome'] == ex['nome'];
          return GestureDetector(
            onTap: () => setState(() => _exercicioSelecionado = ex),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.org.withOpacity(0.15) : AppColors.surf,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppColors.org : AppColors.bord,
                  width: selected ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ex['nome'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        color: selected ? AppColors.org : AppColors.tx,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    'MET ${ex['met']}',
                    style: const TextStyle(fontSize: 11, color: AppColors.mu),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDurationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Duração', style: TextStyle(fontSize: 13, color: AppColors.mu)),
            Text(
              '$_duracaoMin min',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.tx),
            ),
          ],
        ),
        Slider(
          value: _duracaoMin.toDouble(),
          min: 5,
          max: 180,
          divisions: 35,
          activeColor: AppColors.org,
          inactiveColor: AppColors.bord,
          onChanged: (v) => setState(() => _duracaoMin = v.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('5 min', style: TextStyle(fontSize: 10, color: AppColors.mu)),
            const Text('3 h', style: TextStyle(fontSize: 10, color: AppColors.mu)),
          ],
        ),
      ],
    );
  }

  Widget _buildCaloriePreview(double pesoKg) {
    final met = (_exercicioSelecionado?['met'] as num?)?.toDouble() ?? 4.0;
    final kcal = (met * pesoKg * _duracaoMin / 60).round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.org.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.org.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$kcal kcal',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.org,
                ),
              ),
              Text(
                'estimativa para ${_exercicioSelecionado?['nome']}',
                style: const TextStyle(fontSize: 11, color: AppColors.mu),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(Map<String, dynamic>? perfil, String membroId) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _salvando ? null : () => _salvar(perfil, membroId),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.org,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: _salvando
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : const Icon(Icons.check_rounded),
        label: Text(
          _salvando ? 'Salvando...' : 'Registrar Treino',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  Future<void> _salvar(Map<String, dynamic>? perfil, String membroId) async {
    final ex = _exercicioSelecionado;
    if (ex == null) return;

    final familiaId = perfil?['familia_id'] as String? ?? '';
    if (membroId.isEmpty) return;

    setState(() => _salvando = true);
    try {
      await SaudeApiService.registrarExercicio({
        'membro_id':   membroId,
        'familia_id':  familiaId,
        'data':        widget.data,
        'nome':        ex['nome'],
        'categoria':   ex['categoria'],
        'met':         ex['met'],
        'duracao_min': _duracaoMin,
      });
      ref.happy('Treino registrado! Você está ficando mais forte! Orgulho! ⭐', mood: UnicornMood.celebrate);
      if (mounted) Navigator.of(context).pop();
      widget.onSaved();
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }
}
