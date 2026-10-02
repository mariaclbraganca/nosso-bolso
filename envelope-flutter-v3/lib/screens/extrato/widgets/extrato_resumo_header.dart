import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/mes_provider.dart';
import '../../../core/providers/transacoes_provider.dart';
import '../../../ui/theme/nb_theme.dart';

/// Card de resumo financeiro do mês (Entradas, Saídas e Saldo)
class ExtratoResumoHeader extends ConsumerWidget {
  const ExtratoResumoHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesAtualProvider);
    final stats = ref.watch(statsPorMesProvider(mes));
    final saldo = stats.saldo;
    final negativo = saldo < 0;

    return Container(
      padding: const EdgeInsets.all(NBSpacing.l),
      decoration: BoxDecoration(
        color: NBColors.cartao,
        borderRadius: BorderRadius.circular(NBRadius.cartao),
        border: Border.all(color: NBColors.linha),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RESUMO DO CICLO', style: NBText.eyebrow),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: negativo ? NBColors.estouroClaro : NBColors.verdeClaro,
                  borderRadius: BorderRadius.circular(NBRadius.chip),
                ),
                child: Text(
                  negativo ? 'Déficit' : 'No azul',
                  style: NBText.legenda.copyWith(
                    fontWeight: FontWeight.w700,
                    color: negativo ? NBColors.estouro : NBColors.verdeProfundo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ColunaInfo(
                  titulo: 'Entradas',
                  valor: stats.totalReceita,
                  corValor: NBColors.verde,
                  icone: Icons.arrow_downward_rounded,
                  corIcone: NBColors.verde,
                ),
              ),
              Container(width: 1, height: 36, color: NBColors.linha),
              Expanded(
                child: _ColunaInfo(
                  titulo: 'Saídas',
                  valor: stats.totalDespesa,
                  corValor: NBColors.tinta,
                  icone: Icons.arrow_upward_rounded,
                  corIcone: NBColors.tintaSuave,
                ),
              ),
              Container(width: 1, height: 36, color: NBColors.linha),
              Expanded(
                child: _ColunaInfo(
                  titulo: 'Líquido',
                  valor: saldo,
                  corValor: negativo ? NBColors.estouro : NBColors.verde,
                  icone: negativo ? Icons.warning_amber_rounded : Icons.account_balance_wallet_outlined,
                  corIcone: negativo ? NBColors.estouro : NBColors.verde,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColunaInfo extends StatelessWidget {
  final String titulo;
  final double valor;
  final Color corValor;
  final IconData icone;
  final Color corIcone;

  const _ColunaInfo({
    required this.titulo,
    required this.valor,
    required this.corValor,
    required this.icone,
    required this.corIcone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 13, color: corIcone),
            const SizedBox(width: 4),
            Text(titulo, style: NBText.legenda),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            brl(valor, curto: true),
            style: NBText.valorCartao.copyWith(
              color: corValor,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
