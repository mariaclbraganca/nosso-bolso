import 'package:flutter/material.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';

class FechamentoPendenteCard extends StatelessWidget {
  const FechamentoPendenteCard({
    super.key,
    required this.p,
    required this.envelope,
    required this.descartada,
    required this.onEscolher,
    required this.onDescartar,
  });

  final Map<String, dynamic> p;
  final Map<String, dynamic>? envelope;
  final bool descartada;
  final VoidCallback onEscolher;
  final VoidCallback onDescartar;

  @override
  Widget build(BuildContext context) {
    final origem = [p['quem'], p['fonte']].whereType<String>().join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: NBSpacing.s),
      child: CartaoNB(
        borda: envelope == null && !descartada ? NBColors.ambarBarra : NBColors.linha,
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Opacity(
          opacity: descartada ? 0.45 : 1,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['estabelecimento'] as String? ?? 'Compra',
                      style: NBText.corpo.copyWith(
                        fontWeight: FontWeight.w700,
                        decoration: descartada ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (origem.isNotEmpty) Text(origem, style: NBText.legenda),
                    if (!descartada) ...[
                      const SizedBox(height: NBSpacing.s),
                      ChipNB(
                        rotulo: envelope == null ? 'Escolher envelope' : '${envelope!['nome']}',
                        selecionado: false,
                        onTap: onEscolher,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    brl(-((p['valor'] as num?) ?? 0)),
                    style: NBText.corpo.copyWith(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    tooltip: descartada ? 'Manter' : 'Não é gasto (descartar)',
                    icon: Icon(
                      descartada ? Icons.undo_rounded : Icons.close_rounded,
                      size: 20,
                      color: NBColors.tintaSuave,
                    ),
                    onPressed: onDescartar,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
