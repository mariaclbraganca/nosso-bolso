import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/plano/plano_mes.dart';
import '../../core/providers/fechamento_provider.dart';
import '../../core/providers/usuarios_provider.dart';
import '../../core/services/api_service.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../home/widgets/home_cartao_saldo.dart' show nomeMes;
import '../sheets/comum.dart';

/// Fecha (ou atualiza o fechamento de) um mês. O mês é do dia 1 ao último dia,
/// pela data do gasto; o saldo geral não é alterado.
Future<void> fecharMes(BuildContext context, WidgetRef ref, String mes, {bool atualizar = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: NBColors.cartao,
      title: Text('${atualizar ? 'Atualizar o fechamento de' : 'Fechar'} ${nomeMes(mes)}?', style: NBText.secao),
      content: Text(
        'Entram os lançamentos com data de ${nomeMes(mes)}, mesmo os lançados depois. '
        'O saldo geral não é alterado.',
        style: NBText.corpo,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(atualizar ? 'Atualizar' : 'Fechar o mês')),
      ],
    ),
  );
  if (ok != true) return;
  final fam = ref.read(perfilUsuarioLogadoProvider).valueOrNull?['familia_id'] as String?;
  if (fam == null) return;
  try {
    await ApiService.post('/fechamento/fechar', {'familia_id': fam, 'mes': mes});
    ref.invalidate(retrospectivaProvider(mes));
    ref.invalidate(visaoMesProvider(mes));
    avisar('${atualizar ? 'Fechamento atualizado' : 'Mês fechado'}: ${nomeMes(mes)}.');
  } catch (e) {
    avisar(mensagemErro(e), erro: true);
  }
}

/// O que precisa ser pago no mês seguinte, gravado no fechamento.
class CartaoAPagarProximoMes extends StatelessWidget {
  const CartaoAPagarProximoMes({super.key, required this.mes, required this.extras});
  final String mes;
  final Map<String, dynamic> extras;

  double _n(String k) => (extras[k] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final prox = somarMeses(mes, 1);
    Widget linha(String r, double v, {Color? cor, bool forte = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(r, style: forte ? NBText.rotulo : NBText.corpo.copyWith(fontSize: 14))),
            Text(brl(v), style: (forte ? NBText.rotulo : NBText.corpo.copyWith(fontSize: 14)).copyWith(color: cor)),
          ]),
        );
    final falta = _n('falta_cobrir');
    return CartaoNB(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('A PAGAR EM ${nomeMes(prox).toUpperCase()}', style: NBText.eyebrow),
        const SizedBox(height: 4),
        linha('Fatura do cartão', _n('fatura_cartao')),
        linha('Contas de ${nomeMes(prox)}', _n('contas_mes_seguinte')),
        linha('Total a pagar', _n('a_pagar_mes_seguinte'), forte: true),
        const Divider(height: 16),
        linha('Saldo disponível no fechamento', _n('saldo_disponivel')),
        linha('Falta cobrir', falta, forte: true, cor: falta > 0 ? NBColors.estouro : NBColors.verde),
      ]),
    );
  }
}

/// Aviso e botão para atualizar um fechamento que ficou para trás.
class AvisoFechamentoDesatualizado extends ConsumerWidget {
  const AvisoFechamentoDesatualizado({super.key, required this.mes, required this.novos});
  final String mes;
  final int novos;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        padding: const EdgeInsets.all(NBSpacing.l),
        decoration: BoxDecoration(color: NBColors.ambarClaro, borderRadius: BorderRadius.circular(NBRadius.cartao)),
        child: Row(children: [
          Expanded(
            child: Text(
              '${novos == 1 ? '1 lançamento' : '$novos lançamentos'} de ${nomeMes(mes)} foram feitos depois do fechamento.',
              style: NBText.corpo.copyWith(color: NBColors.ambarTexto, fontSize: 13.5),
            ),
          ),
          TextButton(onPressed: () => fecharMes(context, ref, mes, atualizar: true), child: const Text('Atualizar')),
        ]),
      );
}
