import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nosso_bolso_v3/core/providers/exercicio_provider.dart';
import 'package:nosso_bolso_v3/core/services/saude_api_service.dart';
import 'package:nosso_bolso_v3/screens/sheets/comum.dart';
import 'package:nosso_bolso_v3/ui/components/nb_components.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

class FormTreinoSheet extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;
  final String data;

  const FormTreinoSheet({
    super.key,
    required this.membroId,
    required this.familiaId,
    required this.data,
  });

  @override
  ConsumerState<FormTreinoSheet> createState() => _FormTreinoSheetState();
}

class _FormTreinoSheetState extends ConsumerState<FormTreinoSheet> {
  String _categoria = 'cardio';
  final _nomeCtrl = TextEditingController();
  final _duracaoCtrl = TextEditingController(text: '30');
  bool _salvando = false;

  // MET médio de cada categoria no catálogo do backend (agente_treino.py).
  // O servidor calcula as calorias com o MET e o peso do perfil metabólico.
  static const _metPorCategoria = {
    'cardio': 7.6,
    'forca': 5.4,
    'flexibilidade': 2.6,
    'esporte': 6.8,
    'lazer': 4.5,
  };

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _duracaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) {
      avisar('Informe o nome do exercício', erro: true);
      return;
    }
    final duracao = int.tryParse(_duracaoCtrl.text.trim()) ?? 0;
    if (duracao <= 0) {
      avisar('Informe a duração em minutos', erro: true);
      return;
    }

    setState(() => _salvando = true);
    try {
      await SaudeApiService.registrarExercicio({
        'membro_id': widget.membroId,
        'familia_id': widget.familiaId,
        'categoria': _categoria,
        'nome': nome,
        'met': _metPorCategoria[_categoria] ?? 4.0,
        'duracao_min': duracao,
        'data': widget.data,
      });
      ref.invalidate(exercicioDiaProvider);
      ref.invalidate(historicoExercicioProvider);
      if (mounted) {
        Navigator.pop(context);
        avisar('Exercício registrado! Muito bem! 💪');
      }
    } catch (e) {
      if (mounted) avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TopoSheet(titulo: 'Registrar Treino'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categorias.map((cat) {
              final sel = _categoria == cat;
              final emoji = categoriaEmoji[cat] ?? '🏃';
              final label = categoriaNome[cat] ?? cat;
              return ChoiceChip(
                label: Text('$emoji $label'),
                selected: sel,
                onSelected: (val) {
                  if (val) setState(() => _categoria = cat);
                },
                selectedColor: NBColors.ambar.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: sel ? NBColors.ambarTexto : NBColors.tinta,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nomeCtrl,
            decoration: InputDecoration(
              labelText: 'Nome da atividade',
              hintText: 'Ex: Caminhada rápida, Musculação...',
              filled: true,
              fillColor: NBColors.cartao,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(NBRadius.campo),
                borderSide: const BorderSide(color: NBColors.linha),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _duracaoCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Duração (minutos)',
              helperText: 'As calorias são calculadas pela atividade e pelo seu peso.',
              filled: true,
              fillColor: NBColors.cartao,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(NBRadius.campo),
                borderSide: const BorderSide(color: NBColors.linha),
              ),
            ),
          ),
          const SizedBox(height: 20),
          BotaoPrincipal(
            rotulo: 'Salvar Treino',
            carregando: _salvando,
            onPressed: _salvar,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
