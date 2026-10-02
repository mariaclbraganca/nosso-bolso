import 'package:flutter/material.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../sheets/comum.dart';

class MetasCard extends StatelessWidget {
  final Map<String, dynamic> meta;
  final VoidCallback onAportar;
  final VoidCallback onExcluir;

  const MetasCard({
    super.key,
    required this.meta,
    required this.onAportar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final titulo = meta['titulo'] as String? ?? 'Meta';
    final emoji = meta['emoji'] as String? ?? '🎯';
    final valorAlvo = (meta['valor_alvo'] as num?)?.toDouble() ?? 0.0;
    final valorAtual = (meta['valor_atual'] as num?)?.toDouble() ?? 0.0;
    final prazoStr = meta['data_prazo'] as String?;

    final pct = valorAlvo > 0 ? (valorAtual / valorAlvo).clamp(0.0, 1.0) : 0.0;
    final atingida = valorAtual >= valorAlvo && valorAlvo > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CartaoNB(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: NBColors.afundado,
                    shape: BoxShape.circle,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: NBText.secao),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (prazoStr != null && prazoStr.isNotEmpty)
                            Text('Prazo: $prazoStr  ·  ', style: NBText.legenda),
                          Text('${(pct * 100).toStringAsFixed(0)}% concluído', style: NBText.legenda),
                          if (atingida) ...[
                            const SizedBox(width: 6),
                            const SeloNB('ATINGIDA! 🎉', cor: NBColors.verde, fundo: NBColors.verdeClaro),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: NBColors.tintaSuave),
                  color: NBColors.cartao,
                  onSelected: (val) {
                    if (val == 'excluir') onExcluir();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'excluir',
                      child: Text('Excluir meta', style: TextStyle(color: NBColors.estouro)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Acumulado', style: NBText.legenda),
                    const SizedBox(height: 2),
                    Text(brl(valorAtual), style: NBText.valorCartao.copyWith(color: NBColors.verde)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Objetivo', style: NBText.legenda),
                    const SizedBox(height: 2),
                    Text(brl(valorAlvo), style: NBText.valorCartao.copyWith(fontSize: 16)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(NBRadius.pilula),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: NBColors.afundado,
                valueColor: AlwaysStoppedAnimation<Color>(
                  atingida ? NBColors.verde : NBColors.tinta,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: BotaoSecundario(
                rotulo: '+ Aportar valor',
                onPressed: onAportar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
