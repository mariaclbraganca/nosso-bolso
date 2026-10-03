import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/patrimonio_provider.dart';
import '../../core/services/bcb_service.dart';
import '../../core/utils/moeda.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';

class DestinoInvestimento {
  const DestinoInvestimento(this.id, this.nome, this.descricao, this.emoji, this.taxaMensal);
  final String id;
  final String nome;
  final String descricao;
  final String emoji;
  final double Function(TaxasBrasil) taxaMensal;
}

final destinosInvestimento = [
  DestinoInvestimento('cdb_100', 'CDB 100% CDI', 'Liquidez diária, IR regressivo.', '📊', (t) => t.cdiMensal),
  DestinoInvestimento('tesouro_selic', 'Tesouro Selic', 'Risco do governo federal. Resgate em D+1.', '🏛️',
      (t) => t.selicMensal * 0.986), // ~0,2% a.a. de custódia
  DestinoInvestimento('lci_lca', 'LCI / LCA 90% CDI', 'Isento de IR. Carência mínima de 90 dias.', '🌾', (t) => t.cdiMensal * 0.9),
  DestinoInvestimento('poupanca', 'Poupança', '70% da Selic, sem IR. Costuma perder para a inflação.', '🐷', (t) => t.poupancaMensal),
];

/// Juros compostos: valor × (1 + taxa)^meses, taxa em % a.m.
double projetarValor(double valor, double taxaMensalPct, int meses) =>
    valor * math.pow(1 + taxaMensalPct / 100, meses);

final taxasBcbProvider = FutureProvider.autoDispose<TaxasBrasil>((ref) => BcbService.buscar());

/// Compara deixar o dinheiro onde está × mover para outro investimento,
/// com as taxas atuais do Banco Central.
class SimuladorRealocacaoScreen extends ConsumerStatefulWidget {
  const SimuladorRealocacaoScreen({super.key, this.contaInicial});
  final Map<String, dynamic>? contaInicial;

  @override
  ConsumerState<SimuladorRealocacaoScreen> createState() => _SimuladorRealocacaoScreenState();
}

class _SimuladorRealocacaoScreenState extends ConsumerState<SimuladorRealocacaoScreen> {
  final _valor = TextEditingController();
  Map<String, dynamic>? _conta;
  DestinoInvestimento _destino = destinosInvestimento.first;

  @override
  void initState() {
    super.initState();
    if (widget.contaInicial != null) _escolherConta(widget.contaInicial!);
  }

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  void _escolherConta(Map<String, dynamic> c) {
    _conta = c;
    final saldo = (c['saldo_atual'] as num?)?.toDouble() ?? 0;
    _valor.text = saldo > 0 ? saldo.toStringAsFixed(2).replaceAll('.', ',') : '';
  }

  @override
  Widget build(BuildContext context) {
    final contas = ref.watch(patrimonioProvider).valueOrNull ?? const [];
    final taxas = ref.watch(taxasBcbProvider);
    final valor = parseMoeda(_valor.text);
    final taxaOrigem = (_conta?['rendimento_mensal'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Simular realocação')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
        children: [
          Text('DE ONDE SAI', style: NBText.eyebrow),
          const SizedBox(height: NBSpacing.s),
          if (contas.isEmpty)
            Text('Cadastre uma conta no Patrimônio para simular.', style: NBText.legenda)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in contas)
                  ChipNB(
                    rotulo: c['nome'] as String? ?? '',
                    selecionado: _conta?['id'] == c['id'],
                    onTap: () => setState(() => _escolherConta(c)),
                  ),
              ],
            ),
          if (_conta != null)
            Padding(
              padding: const EdgeInsets.only(top: NBSpacing.s),
              child: Text(
                taxaOrigem > 0
                    ? 'Rende ${taxaOrigem.toStringAsFixed(2).replaceAll('.', ',')}% a.m. hoje'
                    : 'Sem rendimento cadastrado (conta como 0%). Edite a conta para informar.',
                style: NBText.legenda,
              ),
            ),
          const SizedBox(height: NBSpacing.l),
          CampoValor(controller: _valor, rotulo: 'QUANTO MOVER', onChanged: (_) => setState(() {})),
          const SizedBox(height: NBSpacing.l),
          Text('PARA ONDE', style: NBText.eyebrow),
          const SizedBox(height: NBSpacing.s),
          ...taxas.when(
            loading: () => [const LinearProgressIndicator()],
            error: (_, __) => [Text('Não consegui buscar as taxas do Banco Central agora.', style: NBText.legenda)],
            data: (t) => [
              for (final d in destinosInvestimento)
                Padding(
                  padding: const EdgeInsets.only(bottom: NBSpacing.s),
                  child: CartaoNB(
                    borda: d.id == _destino.id ? NBColors.verde : NBColors.linha,
                    onTap: () => setState(() => _destino = d),
                    padding: const EdgeInsets.all(NBSpacing.m),
                    child: Row(
                      children: [
                        Text(d.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: NBSpacing.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.nome, style: NBText.rotulo),
                              Text(d.descricao, style: NBText.legenda),
                            ],
                          ),
                        ),
                        Text('${d.taxaMensal(t).toStringAsFixed(2).replaceAll('.', ',')}% a.m.',
                            style: NBText.rotulo.copyWith(color: NBColors.verde)),
                      ],
                    ),
                  ),
                ),
              Text('Taxas do BCB · ${t.dataReferencia}. Valores brutos, antes do IR.', style: NBText.legenda),
              if (_conta != null && valor > 0) ...[
                const SizedBox(height: NBSpacing.l),
                _Resultado(valor: valor, taxaOrigem: taxaOrigem, taxaDestino: _destino.taxaMensal(t), destino: _destino.nome),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Resultado extends StatelessWidget {
  const _Resultado({required this.valor, required this.taxaOrigem, required this.taxaDestino, required this.destino});
  final double valor;
  final double taxaOrigem;
  final double taxaDestino;
  final String destino;

  @override
  Widget build(BuildContext context) {
    final ganho12 = projetarValor(valor, taxaDestino, 12) - projetarValor(valor, taxaOrigem, 12);
    return CartaoNB(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Onde está × $destino', style: NBText.rotulo)),
            ],
          ),
          const SizedBox(height: NBSpacing.m),
          for (final meses in const [3, 6, 12])
            Padding(
              padding: const EdgeInsets.only(bottom: NBSpacing.s),
              child: Row(
                children: [
                  SizedBox(width: 64, child: Text('$meses meses', style: NBText.legenda)),
                  Expanded(child: Text(brl(projetarValor(valor, taxaOrigem, meses)), style: NBText.corpo.copyWith(fontSize: 14))),
                  Expanded(child: Text(brl(projetarValor(valor, taxaDestino, meses)), style: NBText.corpo.copyWith(fontSize: 14))),
                  Text(
                    brl(projetarValor(valor, taxaDestino, meses) - projetarValor(valor, taxaOrigem, meses), sinal: true),
                    style: NBText.rotulo.copyWith(fontSize: 13, color: ganho12 >= 0 ? NBColors.verde : NBColors.estouro),
                  ),
                ],
              ),
            ),
          const Divider(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              UnicornWidget(type: UnicornType.astrix, size: 40, mood: ganho12 > 0 ? UnicornMood.celebrate : UnicornMood.focus),
              const SizedBox(width: NBSpacing.s),
              Expanded(
                child: Text(
                  ganho12 > 0
                      ? 'Em 12 meses, mover rende ${brl(ganho12)} a mais.'
                      : 'Onde está já rende igual ou mais. Não compensa mover.',
                  style: NBText.rotulo.copyWith(color: ganho12 > 0 ? NBColors.verde : NBColors.tinta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
