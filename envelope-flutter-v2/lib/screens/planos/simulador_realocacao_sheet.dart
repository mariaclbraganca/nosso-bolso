import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/patrimonio_provider.dart';
import '../../services/bcb_service.dart';

// ── Destinos de realocação disponíveis ────────────────────────────────────────

class _Destino {
  final String id;
  final String nome;
  final String descricao;
  final String emoji;
  final double Function(TaxasBrasil) taxaMensal;

  const _Destino({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.emoji,
    required this.taxaMensal,
  });
}

final _destinos = [
  _Destino(
    id: 'cdb_100',
    nome: 'CDB 100% CDI',
    descricao: 'Liquidez diária, IR regressivo. Disponível em Nubank, Inter, C6.',
    emoji: '📊',
    taxaMensal: (t) => t.cdiMensal,
  ),
  _Destino(
    id: 'tesouro_selic',
    nome: 'Tesouro Selic',
    descricao: 'Risco zero (governo federal). Liquidez D+1. Tributação IR regressivo.',
    emoji: '🏛️',
    taxaMensal: (t) => t.selicMensal * 0.986, // ~taxa custódia 0,2% a.a.
  ),
  _Destino(
    id: 'lci_lca',
    nome: 'LCI / LCA 90% CDI',
    descricao: 'Isento de IR para pessoa física. Carência mínima de 90 dias.',
    emoji: '🌾',
    taxaMensal: (t) => t.cdiMensal * 0.9,
  ),
  _Destino(
    id: 'poupanca',
    nome: 'Poupança',
    descricao: '70% da Selic. Sem IR. Mas quase sempre perde para a inflação real.',
    emoji: '🐷',
    taxaMensal: (t) => t.poupancaMensal,
  ),
];

// ── Sheet principal ───────────────────────────────────────────────────────────

class SimuladorRealocacaoSheet extends ConsumerStatefulWidget {
  /// Conta pré-selecionada (opcional — vem da sugestão da IA)
  final Map<String, dynamic>? contaInicial;

  const SimuladorRealocacaoSheet({super.key, this.contaInicial});

  @override
  ConsumerState<SimuladorRealocacaoSheet> createState() =>
      _SimuladorRealocacaoSheetState();
}

class _SimuladorRealocacaoSheetState
    extends ConsumerState<SimuladorRealocacaoSheet> {
  final _valorCtrl = TextEditingController();
  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  Map<String, dynamic>? _contaSelecionada;
  _Destino _destino = _destinos[0]; // CDB 100% CDI por padrão
  double _valor = 0;
  TaxasBrasil? _taxas;
  bool _carregandoTaxas = true;

  @override
  void initState() {
    super.initState();
    _contaSelecionada = widget.contaInicial;
    if (_contaSelecionada != null) {
      final saldo = (_contaSelecionada!['saldo_atual'] as num?)?.toDouble() ?? 0;
      _valor = saldo;
      _valorCtrl.text = saldo.toStringAsFixed(2).replaceAll('.', ',');
    }
    _carregarTaxas();
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarTaxas() async {
    final taxas = await BcbService.buscar();
    if (mounted) setState(() { _taxas = taxas; _carregandoTaxas = false; });
  }

  double _parse(String v) =>
      double.tryParse(v.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

  // Juros compostos: P * (1 + r)^n
  double _projetar(double principal, double taxaMensal, int meses) =>
      principal * math.pow(1 + taxaMensal / 100, meses);

  // Taxa mensal da conta origem (usa rendimento_mensal se cadastrado, senão 0)
  double _taxaOrigem() {
    if (_contaSelecionada == null) return 0;
    return (_contaSelecionada!['rendimento_mensal'] as num?)?.toDouble() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final contas = ref.watch(patrimonioProvider).value ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 20, left: 20, right: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.bord,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),

            // Título
            Row(children: [
              const Text('🔄', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Simulador de realocação',
                    style: AppTextStyles.titleSm),
                Text('Compare cenários em 3, 6 e 12 meses',
                    style: AppTextStyles.caption),
              ]),
            ]),
            const SizedBox(height: 24),

            // ── Seleção da conta origem ──────────────────────────────────────
            _Label('DE QUAL CONTA'),
            const SizedBox(height: 8),
            if (contas.isEmpty)
              Text('Nenhuma conta registrada.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.mu))
            else
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: contas.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = contas[i];
                    final sel = _contaSelecionada?['id'] == c['id'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _contaSelecionada = c;
                          final saldo =
                              (c['saldo_atual'] as num?)?.toDouble() ?? 0;
                          _valor = saldo;
                          _valorCtrl.text =
                              saldo.toStringAsFixed(2).replaceAll('.', ',');
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.acc.withOpacity(0.12)
                              : AppColors.surf,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel
                                ? AppColors.acc
                                : AppColors.bord,
                            width: sel ? 1.5 : 0.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(c['emoji'] as String? ?? '🏦',
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(height: 4),
                            Text(
                              (c['nome'] as String? ?? '').length > 10
                                  ? '${(c['nome'] as String).substring(0, 10)}…'
                                  : c['nome'] as String? ?? '',
                              style: AppTextStyles.caption.copyWith(
                                color: sel ? AppColors.acc : AppColors.mu,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),

            // ── Valor a realocar ─────────────────────────────────────────────
            _Label('VALOR A REALOCAR (R\$)'),
            const SizedBox(height: 8),
            TextField(
              controller: _valorCtrl,
              keyboardType: TextInputType.number,
              style: AppTextStyles.body,
              onChanged: (v) => setState(() => _valor = _parse(v)),
              decoration: InputDecoration(
                hintText: '0,00',
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.mu),
                filled: true,
                fillColor: AppColors.surf,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusInput),
                  borderSide: BorderSide.none,
                ),
                suffixText: _contaSelecionada != null
                    ? 'máx ${_fmt.format((_contaSelecionada!['saldo_atual'] as num?)?.toDouble() ?? 0)}'
                    : null,
                suffixStyle: AppTextStyles.caption,
              ),
            ),
            const SizedBox(height: 20),

            // ── Seleção do destino ───────────────────────────────────────────
            _Label('PARA ONDE'),
            const SizedBox(height: 8),
            ...(_destinos.map((d) {
              final sel = d.id == _destino.id;
              final taxa = _taxas != null ? d.taxaMensal(_taxas!) : null;
              return GestureDetector(
                onTap: () => setState(() => _destino = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.acc.withOpacity(0.08)
                        : AppColors.surf,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? AppColors.acc : AppColors.bord,
                      width: sel ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(children: [
                    Text(d.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.nome,
                              style: AppTextStyles.bodySm.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: sel ? AppColors.acc : AppColors.tx)),
                          Text(d.descricao,
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 10, height: 1.4)),
                        ],
                      ),
                    ),
                    if (taxa != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.grn.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${taxa.toStringAsFixed(2)}% a.m.',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.grn,
                              fontWeight: FontWeight.w700,
                              fontSize: 10),
                        ),
                      ),
                  ]),
                ),
              );
            })),

            const SizedBox(height: 8),

            // ── Resultado ────────────────────────────────────────────────────
            if (_carregandoTaxas)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.acc, strokeWidth: 2)),
              )
            else if (_taxas != null && _valor > 0 && _contaSelecionada != null)
              _ResultadoSimulacao(
                valor: _valor,
                taxaOrigem: _taxaOrigem(),
                taxaDestino: _destino.taxaMensal(_taxas!),
                nomeOrigem: _contaSelecionada!['nome'] as String? ?? 'Conta atual',
                nomeDestino: _destino.nome,
                projetar: _projetar,
                fmt: _fmt,
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surf,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  'Selecione uma conta e informe o valor para ver a simulação.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.mu),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 8),

            // Nota sobre taxas
            if (_taxas != null)
              Text(
                '📡 Taxas do Banco Central — ${_taxas!.dataReferencia}. Selic ${_taxas!.selicMensal.toStringAsFixed(2)}% a.m. / IPCA ${_taxas!.ipcaAnual.toStringAsFixed(2)}% a.a.',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.mu, fontSize: 10, height: 1.5),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 4),
            Text(
              'Simulação para fins educativos. Valores brutos antes de IR e taxas.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.mu, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tabela de resultado ───────────────────────────────────────────────────────

class _ResultadoSimulacao extends StatelessWidget {
  final double valor;
  final double taxaOrigem;
  final double taxaDestino;
  final String nomeOrigem;
  final String nomeDestino;
  final double Function(double, double, int) projetar;
  final NumberFormat fmt;

  const _ResultadoSimulacao({
    required this.valor,
    required this.taxaOrigem,
    required this.taxaDestino,
    required this.nomeOrigem,
    required this.nomeDestino,
    required this.projetar,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final periodos = [3, 6, 12];
    final ganhoExtra12 =
        projetar(valor, taxaDestino, 12) - projetar(valor, taxaOrigem, 12);
    final corGanho = ganhoExtra12 > 0 ? AppColors.grn : AppColors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Destaque do ganho anual
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: corGanho.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(color: corGanho.withOpacity(0.3)),
          ),
          child: Column(children: [
            Text(
              ganhoExtra12 > 0 ? '💰 Você ganharia a mais em 12 meses' : '⚠️ Diferença em 12 meses',
              style: AppTextStyles.caption
                  .copyWith(color: corGanho, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              fmt.format(ganhoExtra12.abs()),
              style: AppTextStyles.mono.copyWith(
                  color: corGanho,
                  fontSize: 28,
                  fontWeight: FontWeight.w800),
            ),
            Text(
              ganhoExtra12 > 0
                  ? 'migrando para $nomeDestino'
                  : '$nomeDestino rende menos que a origem',
              style: AppTextStyles.caption,
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Tabela comparativa
        Container(
          decoration: BoxDecoration(
            color: AppColors.surf,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(color: AppColors.bord, width: 0.5),
          ),
          child: Column(children: [
            // Cabeçalho
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Text(nomeOrigem,
                      style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                ),
                Expanded(
                  child: Text(nomeDestino,
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.acc, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                ),
                const SizedBox(width: 8),
                Text('GANHO',
                    style: AppTextStyles.caption
                        .copyWith(fontWeight: FontWeight.w700, fontSize: 9)),
              ]),
            ),
            const Divider(height: 1, color: AppColors.bord),

            ...periodos.asMap().entries.map((entry) {
              final i = entry.key;
              final meses = entry.value;
              final vOrigem = projetar(valor, taxaOrigem, meses);
              final vDestino = projetar(valor, taxaDestino, meses);
              final diff = vDestino - vOrigem;
              final corDiff = diff > 0 ? AppColors.grn : AppColors.red;

              return Column(children: [
                if (i > 0)
                  const Divider(height: 1, color: AppColors.bord),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        '$meses\nMeses',
                        style: AppTextStyles.caption
                            .copyWith(fontWeight: FontWeight.w700, height: 1.3),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        fmt.format(vOrigem),
                        style: AppTextStyles.monoSm,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        fmt.format(vDestino),
                        style: AppTextStyles.monoSm
                            .copyWith(color: AppColors.acc),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        '${diff >= 0 ? '+' : ''}${fmt.format(diff)}',
                        style: AppTextStyles.caption.copyWith(
                            color: corDiff,
                            fontWeight: FontWeight.w700,
                            fontSize: 10),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ]),
                ),
              ]);
            }),
          ]),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w700, letterSpacing: 0.8),
      );
}
