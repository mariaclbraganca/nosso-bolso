import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nosso_bolso_v3/core/providers/saude_provider.dart';
import 'package:nosso_bolso_v3/core/services/saude_api_service.dart';
import 'package:nosso_bolso_v3/screens/sheets/comum.dart';
import 'package:nosso_bolso_v3/ui/components/nb_components.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';
import 'form_refeicao_sheet.dart';

class RefeicoesCard extends ConsumerWidget {
  final String membroId;
  final String familiaId;
  final String data;

  const RefeicoesCard({
    super.key,
    required this.membroId,
    required this.familiaId,
    required this.data,
  });

  static const _slots = [
    ('cafe_da_manha', 'Café da Manhã', '☕'),
    ('almoco', 'Almoço', '🍽️'),
    ('lanche_tarde', 'Lanche da Tarde', '🍎'),
    ('jantar', 'Jantar', '🌙'),
  ];

  void _abrirRegistro(BuildContext context, String tipo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NBColors.papel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FormRefeicaoSheet(
        membroId: membroId,
        familiaId: familiaId,
        data: data,
        tipoInicial: tipo,
      ),
    );
  }

  Future<void> _deletar(WidgetRef ref, String id) async {
    try {
      await SaudeApiService.deletarRefeicao(id);
      ref.invalidate(refeicoesDiaProvider);
      ref.invalidate(extratoDiarioProvider);
      avisar('Refeição removida');
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (membroId: membroId, data: data);
    final refeicoesAsync = ref.watch(refeicoesDiaProvider(args));
    final lista = refeicoesAsync.asData?.value ?? [];

    return CartaoNB(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🥗', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Refeições de Hoje', style: NBText.secao),
              ),
              Text('${lista.length} registradas', style: NBText.legenda),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: NBColors.afundado, height: 1),
          const SizedBox(height: 8),
          ..._slots.map((slot) {
            final reg = lista.where((r) => r['tipo'] == slot.$1).firstOrNull;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(slot.$3, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(slot.$2, style: NBText.corpo.copyWith(fontWeight: FontWeight.bold)),
                        if (reg != null)
                          Text(
                            '${reg['descricao'] ?? ''} ${reg['calorias_estimadas'] != null && (reg['calorias_estimadas'] as num) > 0 ? "(${reg['calorias_estimadas']} kcal)" : ""}',
                            style: NBText.legenda.copyWith(color: NBColors.tintaSuave),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text('Não registrado', style: NBText.legenda),
                      ],
                    ),
                  ),
                  if (reg != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: NBColors.tintaSuave),
                      onPressed: () => _deletar(ref, reg['id']?.toString() ?? ''),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: NBColors.verde),
                      onPressed: () => _abrirRegistro(context, slot.$1),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
