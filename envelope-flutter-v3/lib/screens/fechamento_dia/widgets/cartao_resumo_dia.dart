import 'package:flutter/material.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';

class CartaoResumoDia extends StatelessWidget {
  final List<Map<String, dynamic>> gastos;
  final double totalDia;
  final num? porDia;
  final int dias;
  final bool fechado;
  final String? fechadoPor;

  const CartaoResumoDia({
    super.key,
    required this.gastos,
    required this.totalDia,
    required this.porDia,
    required this.dias,
    required this.fechado,
    this.fechadoPor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CartaoNB(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gastos.isEmpty
                    ? 'Hoje não saiu nada.'
                    : 'Hoje saíram ${brl(totalDia)} em ${gastos.length} ${gastos.length == 1 ? 'lançamento' : 'lançamentos'}.',
                style: NBText.secao,
              ),
              const SizedBox(height: NBSpacing.s),
              Text(
                porDia == null
                    ? 'Último dia do ciclo. Amanhã começa um novo.'
                    : 'Dá pra gastar ${brl(porDia!)} por dia nos próximos $dias dias.',
                style: NBText.corpo.copyWith(
                  color: (porDia ?? 1) <= 0 ? NBColors.estouro : NBColors.verde,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (fechado) ...[
          const SizedBox(height: NBSpacing.m),
          Container(
            padding: const EdgeInsets.all(NBSpacing.m),
            decoration: BoxDecoration(
              color: NBColors.verdeClaro,
              borderRadius: BorderRadius.circular(NBRadius.campo),
            ),
            child: Text(
              'Dia já fechado${fechadoPor != null ? ' por $fechadoPor' : ''}. Pode fechar de novo se entrou algo depois.',
              style: NBText.corpo.copyWith(fontSize: 14, color: NBColors.verdeProfundo),
            ),
          ),
        ],
      ],
    );
  }
}
