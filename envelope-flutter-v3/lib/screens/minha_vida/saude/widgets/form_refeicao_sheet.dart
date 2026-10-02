import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nosso_bolso_v3/core/providers/saude_provider.dart';
import 'package:nosso_bolso_v3/core/services/saude_api_service.dart';
import 'package:nosso_bolso_v3/screens/sheets/comum.dart';
import 'package:nosso_bolso_v3/ui/components/nb_components.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

class FormRefeicaoSheet extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;
  final String data;
  final String tipoInicial;

  const FormRefeicaoSheet({
    super.key,
    required this.membroId,
    required this.familiaId,
    required this.data,
    this.tipoInicial = 'almoco',
  });

  @override
  ConsumerState<FormRefeicaoSheet> createState() => _FormRefeicaoSheetState();
}

class _FormRefeicaoSheetState extends ConsumerState<FormRefeicaoSheet> {
  late String _tipo;
  final _descricaoCtrl = TextEditingController();
  bool _salvando = false;

  final _tipos = const [
    ('cafe_da_manha', '☕ Café da Manhã'),
    ('almoco', '🍽️ Almoço'),
    ('lanche_tarde', '🍎 Lanche'),
    ('jantar', '🌙 Jantar'),
  ];

  @override
  void initState() {
    super.initState();
    _tipo = widget.tipoInicial;
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final desc = _descricaoCtrl.text.trim();
    if (desc.isEmpty) {
      avisar('Informe o que você comeu', erro: true);
      return;
    }
    setState(() => _salvando = true);
    try {
      // A IA do backend calcula os macros a partir do texto.
      final r = await SaudeApiService.registrarRefeicao({
        'membro_id': widget.membroId,
        'familia_id': widget.familiaId,
        'tipo_refeicao': _tipo,
        'modalidade': 'texto',
        'dados_entrada': {'descricao': desc},
        'offline_timestamp': widget.data,
      });
      if (r['status'] == 'aguardando_clarificacao') {
        avisar(r['pergunta_agente'] as String? ?? 'Conte um pouco mais: quantidades ajudam a IA a calcular.');
        return;
      }
      ref.invalidate(refeicoesDiaProvider);
      ref.invalidate(extratoDiarioProvider);
      if (mounted) {
        Navigator.pop(context);
        final kcal = (((r['resultado'] as Map?)?['macros_totais'] as Map?)?['calorias_kcal'] as num?)?.round();
        avisar(kcal == null ? 'Refeição registrada.' : 'Refeição registrada: $kcal kcal.');
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
          const TopoSheet(titulo: 'Registrar Refeição'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tipos.map((t) {
              final sel = _tipo == t.$1;
              return ChoiceChip(
                label: Text(t.$2),
                selected: sel,
                onSelected: (val) {
                  if (val) setState(() => _tipo = t.$1);
                },
                selectedColor: NBColors.verde.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: sel ? NBColors.verde : NBColors.tinta,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descricaoCtrl,
            decoration: InputDecoration(
              labelText: 'O que você comeu?',
              hintText: 'Ex: 4 colheres de arroz, 1 filé de frango e salada',
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
            rotulo: 'Salvar Refeição',
            carregando: _salvando,
            onPressed: _salvar,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
