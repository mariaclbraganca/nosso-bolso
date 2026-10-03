import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/envelopes_provider.dart';
import '../../core/providers/mes_provider.dart';
import '../../core/providers/transacoes_provider.dart';
import '../../core/services/api_service.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';
import 'comum.dart';

/// POST /fechamento/fechar — snapshot dos envelopes, zera consumo e saldo geral,
/// grava o resultado do ciclo em historico_mensal. Idempotente no mesmo mês.
class SheetFecharMes extends ConsumerStatefulWidget {
  const SheetFecharMes({super.key});

  @override
  ConsumerState<SheetFecharMes> createState() => _SheetFecharMesState();
}

class _SheetFecharMesState extends ConsumerState<SheetFecharMes> {
  bool _salvando = false;

  Future<void> _fechar(String mes) async {
    setState(() => _salvando = true);
    try {
      final p = perfilOuErro(ref);
      final r = await ApiService.post('/fechamento/fechar', {'familia_id': p['familia_id'], 'mes': mes});
      HapticFeedback.heavyImpact();
      final resultado = ((r['ciclo'] as Map?)?['resultado'] as num?)?.toDouble() ?? 0;
      ref.unicornTeam(messages: {
        UnicornType.astrix: resultado >= 0 ? 'Fechou com ${brl(resultado, sinal: true)}' : 'Mês fechado',
        UnicornType.sweet: 'Ciclo novo!',
        UnicornType.happy: 'Bora de novo',
        UnicornType.geronimo: resultado < 0 ? 'Ficou ${brl(resultado)}' : 'Sem sustos',
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mes = ref.watch(mesAtualProvider);
    final stats = ref.watch(statsPorMesProvider(mes));
    final envelopes = ref.watch(envelopesViseisProvider);
    final saldoGeral = ref.watch(saldoGeralProvider).valueOrNull ?? 0;
    final nomeMes = mesLabelLongo(mes).split(' ').first;

    final consumo = envelopes.where((e) => NaturezaEnvelope.from(e) == NaturezaEnvelope.consumo).map((e) => e['nome_envelope']).join(', ');
    final acumula = envelopes.where((e) => NaturezaEnvelope.from(e) != NaturezaEnvelope.consumo).map((e) => e['nome_envelope']).join(', ');

    final hoje = DateTime.now();
    final partes = mes.split('-');
    final ultimoDia = DateTime(int.parse(partes[0]), int.parse(partes[1]) + 1, 0);
    final faltam = ultimoDia.difference(DateTime(hoje.year, hoje.month, hoje.day)).inDays;

    return CascaSheet(
      filhos: [
        TopoSheet(titulo: 'Fechar ${nomeMes.toLowerCase()}?', subtitulo: 'O próximo ciclo começa assim que você confirmar.'),
        const SizedBox(height: NBSpacing.l),
        CartaoNB(
          child: Column(
            children: [
              LinhaPrevia(rotulo: 'Receita', valor: stats.totalReceita, corValor: NBColors.verde),
              LinhaPrevia(rotulo: 'Saídas', valor: stats.totalDespesa),
              const Divider(height: 16),
              LinhaPrevia(rotulo: 'Resultado', valor: stats.saldo, corValor: NBColors.verde),
            ],
          ),
        ),
        if (faltam > 0) ...[
          const SizedBox(height: NBSpacing.m),
          Text('Ainda faltam $faltam ${faltam == 1 ? 'dia' : 'dias'} neste ciclo.',
              style: NBText.rotulo.copyWith(color: NBColors.ambarTexto)),
        ],
        const SizedBox(height: NBSpacing.xl),
        const _Passo(1, 'Retrato de cada envelope', 'Fica salvo e alimenta a Retrospectiva.'),
        _Passo(2, 'Consumo volta a zero', consumo.isEmpty ? 'Nenhum envelope de consumo.' : consumo),
        _Passo(3, 'Reserva e objetivo acumulam', acumula.isEmpty ? 'Nenhum envelope de reserva ou objetivo.' : '$acumula seguem com o saldo.'),
        _Passo(4, 'Saldo geral volta a zero',
            'Hoje ele tem ${brl(saldoGeral)}. O resultado do mês fica guardado na Retrospectiva.'),
        const SizedBox(height: NBSpacing.m),
        Container(
          padding: const EdgeInsets.all(NBSpacing.m),
          decoration: BoxDecoration(color: NBColors.afundado, borderRadius: BorderRadius.circular(NBRadius.campo)),
          child: Text(
            'Fechou por engano? Fechar de novo no mesmo mês só atualiza o retrato, sem duplicar nada.',
            style: NBText.corpo.copyWith(fontSize: 14, color: NBColors.tintaSuave),
          ),
        ),
      ],
      botao: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _salvando ? null : () => Navigator.of(context).pop(),
              child: const Text('Agora não'),
            ),
          ),
          const SizedBox(width: NBSpacing.m),
          Expanded(child: BotaoPrincipal(rotulo: 'Fechar mês', carregando: _salvando, onPressed: () => _fechar(mes))),
        ],
      ),
    );
  }
}

class _Passo extends StatelessWidget {
  const _Passo(this.n, this.titulo, this.texto);
  final int n;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NBSpacing.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: NBColors.tinta, shape: BoxShape.circle),
            child: Text('$n', style: NBText.rotulo.copyWith(color: NBColors.papel, fontSize: 12)),
          ),
          const SizedBox(width: NBSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: NBText.rotulo.copyWith(fontSize: 15)),
                Text(texto, style: NBText.legenda.copyWith(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
