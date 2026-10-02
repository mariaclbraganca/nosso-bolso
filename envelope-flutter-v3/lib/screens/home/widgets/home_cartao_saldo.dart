import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/envelopes_provider.dart';
import '../../../core/providers/mes_provider.dart';
import '../../../core/providers/transacoes_provider.dart';
import '../../../core/providers/usuarios_provider.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../sheets/sheet_abastecer.dart';
import '../../sheets/sheet_lancamento.dart';

class HomeCartaoSaldo extends ConsumerWidget {
  const HomeCartaoSaldo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saldo = ref.watch(saldoGeralProvider).value ?? 0;
    final stats = ref.watch(totalStatsProvider);
    final mes = ref.watch(mesAtualProvider);
    final gastoCiclo = ref.watch(statsPorMesProvider(mes)).totalDespesa;
    final aoVivo = _ultimoLancamento(ref);
    const claro = NBColors.verdeClaro;

    return Container(
      padding: const EdgeInsets.all(NBSpacing.xl),
      decoration: BoxDecoration(
        color: NBColors.verde,
        borderRadius: BorderRadius.circular(NBRadius.destaque),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo geral · fora dos envelopes',
            style: NBText.rotulo.copyWith(color: claro, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(brl(saldo), style: NBText.saldo.copyWith(color: Colors.white)),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: NBColors.ambar,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  aoVivo == null ? 'Ao vivo' : 'Ao vivo · $aoVivo',
                  style: NBText.legenda.copyWith(color: claro),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => abrirSheet(context, const SheetAbastecer()),
                  style: FilledButton.styleFrom(
                    backgroundColor: NBColors.papel,
                    foregroundColor: NBColors.verdeProfundo,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.move_to_inbox_rounded, size: 18),
                  label: const Text('Abastecer'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => abrirLancamento(context, tipo: TipoLancamento.receita),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: claro, width: 1.5),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Receita'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF3E8A78)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniValor(rotulo: 'Nos envelopes', valor: stats['available'] ?? 0)),
              Expanded(child: _MiniValor(rotulo: 'Gasto no ciclo', valor: gastoCiclo)),
            ],
          ),
        ],
      ),
    );
  }

  String? _ultimoLancamento(WidgetRef ref) {
    final eu = ref.watch(perfilUsuarioLogadoProvider).value?['id'];
    final txs = ref.watch(transacoesComDetalhesProvider);
    final agora = DateTime.now();
    for (final t in txs) {
      final criado = DateTime.tryParse(t['created_at']?.toString() ?? '')?.toLocal();
      if (criado == null || agora.difference(criado).inMinutes > 30) continue;
      if (t['tipo'] != 'despesa' && t['tipo'] != 'receita') continue;
      final quem = t['usuario_id'] == eu
          ? 'Você'
          : (t['usuarios']?['nome'] as String? ?? 'Alguém').split(' ').first;
      final min = agora.difference(criado).inMinutes;
      final quando = min < 2 ? 'agora' : 'há $min min';
      return '$quem lançou ${brl((t['valor'] as num).toDouble())} $quando';
    }
    return null;
  }
}

class _MiniValor extends StatelessWidget {
  const _MiniValor({required this.rotulo, required this.valor});
  final String rotulo;
  final double valor;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: NBText.legenda.copyWith(color: NBColors.verdeClaro)),
          Text(
            brl(valor),
            style: NBText.corpo.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      );
}
