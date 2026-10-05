import 'package:flutter/material.dart';
import '../../../core/plano/plano_mes.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../home/widgets/home_cartao_saldo.dart' show nomeMes;

/// Próximos meses em duas colunas: o que sobra do salário para os envelopes e
/// o resultado depois dos envelopes planejados hoje (falta ou sobra de verdade).
class ProximosMeses extends StatelessWidget {
  const ProximosMeses({super.key, required this.limite});
  final LimiteMes limite;

  @override
  Widget build(BuildContext context) {
    final l = limite;
    final meses = l.proximosMeses(5);
    final depois = [for (final m in meses) m.limite - l.totalOrcado];
    final virada = [for (var i = 0; i < meses.length; i++) if (depois[i] >= 0) meses[i].mes].firstOrNull;
    String nome(String mes) => '${nomeMes(mes)[0].toUpperCase()}${nomeMes(mes).substring(1)}';
    Text valor(double v, {bool forte = false}) => Text(
          '${v < 0 ? '−' : ''}${brl(v.abs())}',
          textAlign: TextAlign.end,
          style: (forte ? NBText.rotulo : NBText.corpo.copyWith(fontSize: 14))
              .copyWith(color: v < 0 ? NBColors.estouro : NBColors.verde),
        );

    return CartaoNB(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PRÓXIMOS MESES', style: NBText.eyebrow),
        Text(
          'Livre: salário − contas do mês seguinte − parcelas que ainda faltam. '
          'Depois dos envelopes: com os ${brl(l.totalOrcado)} planejados hoje.',
          style: NBText.legenda,
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Expanded(flex: 4, child: SizedBox()),
          Expanded(flex: 5, child: Text('Livre', textAlign: TextAlign.end, style: NBText.legenda)),
          Expanded(flex: 6, child: Text('Depois dos envelopes', textAlign: TextAlign.end, style: NBText.legenda)),
        ]),
        for (var i = 0; i < meses.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Expanded(flex: 4, child: Text(nome(meses[i].mes), style: NBText.corpo.copyWith(fontSize: 14))),
              Expanded(flex: 5, child: valor(meses[i].limite)),
              Expanded(flex: 6, child: valor(depois[i], forte: true)),
            ]),
          ),
        const Divider(height: 12),
        Text(
          virada != null
              ? 'Com os envelopes de hoje, o salário volta a cobrir tudo em ${nomeMes(virada)}.'
              : 'No ritmo atual, falta ${brl(-depois.last)} por mês mesmo depois que as parcelas acabam. '
                  'Para fechar sem a reserva: aumentar a renda ou reduzir contas fixas e envelopes.',
          style: NBText.rotulo.copyWith(color: virada != null ? NBColors.verde : NBColors.estouro),
        ),
      ]),
    );
  }
}
