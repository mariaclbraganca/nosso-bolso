import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/plano/plano_mes.dart';
import '../../../core/providers/envelopes_provider.dart';
import '../../../core/providers/mes_provider.dart';
import '../../../core/providers/plano_provider.dart';
import '../../../core/providers/transacoes_provider.dart';
import '../../../core/providers/usuarios_provider.dart';
import '../../../ui/theme/nb_theme.dart';

/// Último dia útil do mês 'YYYY-MM' (sem feriados), como "30/10".
String ultimoDiaUtil(String mes) {
  final d = DateTime(int.parse(mes.substring(0, 4)), int.parse(mes.substring(5, 7)) + 1, 0);
  var dia = d;
  while (dia.weekday == DateTime.saturday || dia.weekday == DateTime.sunday) {
    dia = dia.subtract(const Duration(days: 1));
  }
  return '${dia.day}/${dia.month.toString().padLeft(2, '0')}';
}

const _mesesNome = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
String nomeMes(String mes) => _mesesNome[int.parse(mes.substring(5, 7)) - 1];

/// Card principal do Início: quanto ainda dá para gastar no mês.
class HomeCartaoSaldo extends ConsumerWidget {
  const HomeCartaoSaldo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesAtualProvider);
    final limite = ref.watch(limiteMesProvider);
    final saldoConta = ref.watch(saldoGeralProvider).valueOrNull ?? 0;
    final aoVivo = _ultimoLancamento(ref);

    return limite.when(
      loading: () => _Casca(
        negativo: false,
        filhos: [
          Text('DISPONÍVEL PARA GASTAR EM ${nomeMes(mes).toUpperCase()}', style: _eyebrow),
          const SizedBox(height: 12),
          const LinearProgressIndicator(color: Colors.white, backgroundColor: Color(0x33FFFFFF)),
        ],
      ),
      error: (e, _) => _Casca(
        negativo: false,
        filhos: [
          Text('DISPONÍVEL PARA GASTAR', style: _eyebrow),
          const SizedBox(height: 6),
          Text('Não consegui calcular agora. Puxe a tela para atualizar.', style: NBText.corpo.copyWith(color: Colors.white)),
        ],
      ),
      data: (l) => CartaoDisponivel(limite: l, saldoConta: saldoConta, aoVivo: aoVivo),
    );
  }

  String? _ultimoLancamento(WidgetRef ref) {
    final eu = ref.watch(perfilUsuarioLogadoProvider).valueOrNull?['id'];
    final txs = ref.watch(transacoesComDetalhesProvider);
    final agora = DateTime.now();
    for (final t in txs) {
      final criado = DateTime.tryParse(t['created_at']?.toString() ?? '')?.toLocal();
      if (criado == null || agora.difference(criado).inMinutes > 30) continue;
      if (t['tipo'] != 'despesa' && t['tipo'] != 'receita') continue;
      final quem = t['usuario_id'] == eu ? 'Você' : (t['usuarios']?['nome'] as String? ?? 'Alguém').split(' ').first;
      final min = agora.difference(criado).inMinutes;
      return '$quem lançou ${brl((t['valor'] as num).toDouble())} ${min < 2 ? 'agora' : 'há $min min'}';
    }
    return null;
  }
}

final _eyebrow = NBText.eyebrow.copyWith(color: const Color(0xDDFFFFFF));

class _Casca extends StatelessWidget {
  const _Casca({required this.negativo, required this.filhos});
  final bool negativo;
  final List<Widget> filhos;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(NBSpacing.xl),
        decoration: BoxDecoration(
          color: negativo ? NBColors.estouro : NBColors.verde,
          borderRadius: BorderRadius.circular(NBRadius.destaque),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: filhos),
      );
}

/// Disponível para gastar (limite − compras − pendentes de envelope), com o
/// limite, as compras e o aviso de salário comprometido; VA logo abaixo.
class CartaoDisponivel extends StatelessWidget {
  const CartaoDisponivel({super.key, required this.limite, required this.saldoConta, this.aoVivo});
  final LimiteMes limite;
  final double saldoConta;
  final String? aoVivo;

  @override
  Widget build(BuildContext context) {
    final l = limite;
    final negativo = l.disponivel < 0;
    final usado = l.limite > 0 ? ((l.comprasDoMes + l.pendenteDeEnvelope) / l.limite).clamp(0.0, 1.0) : 1.0;
    final proximo = nomeMes(somarMeses(l.mes, 1));
    const branco = Colors.white;
    Widget mini(String rotulo, double v) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rotulo, style: NBText.legenda.copyWith(color: const Color(0xD9FFFFFF), fontSize: 11.5)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(brl(v), style: NBText.corpo.copyWith(color: branco, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ]),
        );

    return Column(
      children: [
        _Casca(
          negativo: negativo,
          filhos: [
            Text('DISPONÍVEL PARA GASTAR EM ${nomeMes(l.mes).toUpperCase()}', style: _eyebrow),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(brl(l.disponivel), style: NBText.saldo.copyWith(color: branco)),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: usado, minHeight: 8, color: branco, backgroundColor: const Color(0x38FFFFFF)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              mini('Limite do mês', l.limite),
              mini('Compras do mês', l.comprasDoMes),
              mini('Pendente de envelope', l.pendenteDeEnvelope),
            ]),
            if (l.limite < 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: const Color(0x24000000), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  'O salário de ${ultimoDiaUtil(l.mes)} já está todo comprometido com as contas de $proximo '
                  'e as parcelas do cartão. Cada compra agora aumenta o déficit coberto pela reserva.',
                  style: NBText.corpo.copyWith(color: branco, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Saldo em conta ${brl(saldoConta)}${aoVivo == null ? '' : ' · $aoVivo'}',
              style: NBText.legenda.copyWith(color: const Color(0xD9FFFFFF)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        if (l.limiteVa > 0) ...[
          const SizedBox(height: NBSpacing.m),
          _CartaoVa(limite: l),
        ],
      ],
    );
  }
}

class _CartaoVa extends StatelessWidget {
  const _CartaoVa({required this.limite});
  final LimiteMes limite;

  @override
  Widget build(BuildContext context) {
    final l = limite;
    return Container(
      padding: const EdgeInsets.all(NBSpacing.l),
      decoration: BoxDecoration(
        color: NBColors.cartao,
        borderRadius: BorderRadius.circular(NBRadius.cartao),
        border: Border.all(color: NBColors.linha),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: NBColors.lavandaClara, borderRadius: BorderRadius.circular(10)),
          child: Text('VA', style: NBText.rotulo.copyWith(color: NBColors.lavanda)),
        ),
        const SizedBox(width: NBSpacing.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Vale-alimentação', style: NBText.rotulo),
            Text(
              'Gasto ${brl(l.gastoVa)} de ${brl(l.limiteVa)}'
              '${l.vaSobraAnterior > 0 ? ' (inclui sobra de ${brl(l.vaSobraAnterior)})' : ''}',
              style: NBText.legenda,
            ),
          ]),
        ),
        Text(brl(l.disponivelVa),
            style: NBText.valorCartao.copyWith(fontSize: 18, color: l.disponivelVa < 0 ? NBColors.estouro : NBColors.verde)),
      ]),
    );
  }
}
