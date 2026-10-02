import 'package:flutter/material.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';

/// Card de cabeçalho do mês para os Gastos Fixos
class FixosResumoCard extends StatelessWidget {
  final double total;
  final double pago;
  final double reservado;
  final int totalCount;
  final int pagosCount;

  const FixosResumoCard({
    super.key,
    required this.total,
    required this.pago,
    required this.reservado,
    required this.totalCount,
    required this.pagosCount,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (pago / total).clamp(0.0, 1.0) : 0.0;

    return CartaoNB(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('RESUMO DOS FIXOS', style: NBText.eyebrow),
              const Spacer(),
              SeloNB(
                '$pagosCount/$totalCount PAGOS',
                cor: pagosCount == totalCount && totalCount > 0 ? NBColors.verde : NBColors.tintaSuave,
                fundo: pagosCount == totalCount && totalCount > 0 ? NBColors.verdeClaro : NBColors.afundado,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total do mês', style: NBText.legenda),
                    const SizedBox(height: 2),
                    Text(brl(total), style: NBText.valorCartao),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('A pagar', style: NBText.legenda),
                  const SizedBox(height: 2),
                  Text(
                    brl(reservado),
                    style: NBText.valorCartao.copyWith(
                      color: reservado > 0 ? NBColors.estouro : NBColors.verde,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(NBRadius.pilula),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: NBColors.afundado,
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 1.0 ? NBColors.verde : NBColors.tinta,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
