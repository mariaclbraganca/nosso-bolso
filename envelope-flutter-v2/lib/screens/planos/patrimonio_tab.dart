import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../constants.dart';
import '../../providers/fixos_provider.dart';
import '../../providers/patrimonio_provider.dart';
import '../../providers/pin_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/gemini_patrimonio_service.dart';
import '../../widgets/unicorn/unicorn_system.dart';
import '../config/pin_screen.dart';
import 'simulador_realocacao_sheet.dart';

class PatrimonioTab extends ConsumerWidget {
  const PatrimonioTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinDesbloqueado = ref.watch(pinDesbloqueadoProvider);
    final pinConfigurado = ref.watch(pinConfiguradoProvider);

    if (!pinDesbloqueado) {
      return _PatrimonioBloqueado(pinConfigurado: pinConfigurado.asData?.value ?? true);
    }
    return const _PatrimonioConteudo();
  }
}

class _PatrimonioBloqueado extends ConsumerWidget {
  final bool pinConfigurado;
  const _PatrimonioBloqueado({required this.pinConfigurado});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.acc.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.account_balance_rounded, color: AppColors.acc, size: 32),
            ),
            const SizedBox(height: 20),
            Text('Patrimônio', style: AppTextStyles.title),
            const SizedBox(height: 8),
            Text(
              'Suas contas bancárias e investimentos.\nDigite seu PIN para acessar.',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.lock_rounded, size: 18),
                label: Text(
                  pinConfigurado ? 'Digitar PIN' : 'Configurar PIN',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.bg),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PinScreen(
                      mode: pinConfigurado ? PinMode.verify : PinMode.setup,
                      onSuccess: () {
                        Navigator.pop(context);
                        ref.invalidate(pinConfiguradoProvider);
                      },
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.acc,
                  foregroundColor: AppColors.bg,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatrimonioConteudo extends ConsumerStatefulWidget {
  const _PatrimonioConteudo();

  @override
  ConsumerState<_PatrimonioConteudo> createState() => _PatrimonioConteudoState();
}

class _PatrimonioConteudoState extends ConsumerState<_PatrimonioConteudo> {
  bool _snapshotSalvo = false;

  Future<void> _salvarSnapshotSeNecessario(
    List<Map<String, dynamic>> contas,
  ) async {
    if (_snapshotSalvo || contas.isEmpty) return;
    final perfil = ref.read(perfilUsuarioLogadoProvider).value;
    if (perfil == null) return;
    _snapshotSalvo = true;
    final familiaId = perfil['familia_id'] as String? ?? '';
    await salvarSnapshotMesAtual(contas, familiaId);
    if (mounted) ref.invalidate(snapshotsPatrimonioProvider);
  }

  @override
  Widget build(BuildContext context) {
    final contasAsync = ref.watch(patrimonioProvider);
    final total = ref.watch(totalPatrimonioProvider);
    final evolucao = ref.watch(evolucaoPatrimonioProvider);

    // Dispara snapshot quando os dados do stream chegam
    ref.listen(patrimonioProvider, (_, next) {
      final contas = next.value;
      if (contas != null && contas.isNotEmpty) {
        _salvarSnapshotSeNecessario(contas);
      }
    });
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return CustomScrollView(
      slivers: [
            // Card total patrimônio
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.card, AppColors.acc.withOpacity(0.08)],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  border: Border.all(color: AppColors.acc.withOpacity(0.2), width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.account_balance_rounded, color: AppColors.acc, size: 16),
                      const SizedBox(width: 8),
                      Text('Patrimônio total', style: AppTextStyles.caption.copyWith(color: AppColors.acc)),
                    ]),
                    const SizedBox(height: 10),
                    Text(
                      fmt.format(total),
                      style: AppTextStyles.display.copyWith(color: AppColors.tx),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${contasAsync.value?.length ?? 0} conta${(contasAsync.value?.length ?? 0) == 1 ? '' : 's'} registrada${(contasAsync.value?.length ?? 0) == 1 ? '' : 's'}',
                      style: AppTextStyles.caption,
                    ),
                    // Gráfico de evolução inline no card
                    if (evolucao.length >= 2) ...[
                      const SizedBox(height: 20),
                      _GraficoEvolucao(evolucao: evolucao, fmt: fmt),
                    ],
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Análise IA do portfólio
            const SliverToBoxAdapter(child: _PatrimonioIACard()),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Contas e investimentos', style: AppTextStyles.titleSm),
                    GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const FormContaPatrimonioSheet(),
                      ),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.acc.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.acc.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.add_rounded, color: AppColors.acc, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            contasAsync.when(
              loading: () => const SliverToBoxAdapter(child: UnicornLoading()),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(child: Text('Erro: $e', style: TextStyle(color: AppColors.red))),
              ),
              data: (contas) {
                if (contas.isEmpty) {
                  return SliverToBoxAdapter(
                    child: UnicornEmpty(
                      type: UnicornType.astrix,
                      title: 'Nenhuma conta ainda',
                      subtitle: 'Toque em + para registrar sua primeira conta ou investimento',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: contas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ContaCard(conta: contas[i]),
                  ),
                );
              },
            ),

            // Seção metas com prazo
            SliverToBoxAdapter(
              child: _MetasComPrazo(contasAsync: contasAsync),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _ContaCard extends StatelessWidget {
  final Map<String, dynamic> conta;
  const _ContaCard({required this.conta});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final saldo = (conta['saldo_atual'] as num?)?.toDouble() ?? 0.0;
    final nome = conta['nome'] as String? ?? '';
    final banco = conta['banco'] as String? ?? '';
    final tipo = conta['tipo'] as String? ?? 'conta_corrente';
    final emoji = conta['emoji'] as String? ?? '🏦';
    final rendimento = (conta['rendimento_mensal'] as num?)?.toDouble();
    final meta = (conta['meta_saldo'] as num?)?.toDouble();

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FormContaPatrimonioSheet(conta: conta),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.surf,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nome, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (banco.isNotEmpty) ...[
                      Text(banco, style: AppTextStyles.caption),
                      const SizedBox(width: 6),
                      Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.mu, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                    ],
                    Text(_labelTipo(tipo), style: AppTextStyles.caption),
                    if (rendimento != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.grn.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${rendimento.toStringAsFixed(2)}% a.m.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.grn, fontSize: 9),
                        ),
                      ),
                    ],
                  ]),
                  if (meta != null && meta > 0) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (saldo / meta).clamp(0.0, 1.0),
                        backgroundColor: AppColors.bord,
                        color: AppColors.acc,
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Meta: ${fmt.format(meta)}',
                      style: AppTextStyles.caption.copyWith(fontSize: 9),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              fmt.format(saldo),
              style: AppTextStyles.mono.copyWith(
                color: saldo >= 0 ? AppColors.tx : AppColors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelTipo(String tipo) {
    switch (tipo) {
      case 'poupanca': return 'Poupança';
      case 'investimento': return 'Investimento';
      case 'caixinha': return 'Caixinha';
      case 'carteira': return 'Carteira';
      default: return 'Conta corrente';
    }
  }
}

// ── Card de análise IA do portfólio ────────────────────────────────────────────

class _PatrimonioIACard extends ConsumerStatefulWidget {
  const _PatrimonioIACard();

  @override
  ConsumerState<_PatrimonioIACard> createState() => _PatrimonioIACardState();
}

class _PatrimonioIACardState extends ConsumerState<_PatrimonioIACard> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final analiseAsync = ref.watch(patrimonioAnaliseProvider);
    final contas = ref.watch(patrimonioProvider).value ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.acc.withOpacity(0.25), width: 0.5),
        ),
        child: Column(
          children: [
            // Cabeçalho sempre visível
            InkWell(
              onTap: () => setState(() => _expandido = !_expandido),
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.acc.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text('✨', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Análise do Astrix',
                            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            contas.isEmpty
                                ? 'Adicione contas para analisar'
                                : 'IA analisa seus rendimentos e sugere melhorias',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    if (contas.isNotEmpty) ...[
                      // Badge da nota quando expandido mostra resultado
                      if (!_expandido && analiseAsync.hasValue)
                        _NotaBadge(nota: analiseAsync.value!.notaGeral),
                      if (analiseAsync.isLoading && _expandido)
                        const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.acc,
                          ),
                        )
                      else
                        Icon(
                          _expandido ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          color: AppColors.mu,
                          size: 20,
                        ),
                    ],
                  ],
                ),
              ),
            ),

            // Conteúdo expansível
            if (_expandido) ...[
              const Divider(height: 1, color: AppColors.bord),
              if (contas.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Registre suas contas e investimentos para receber uma análise personalizada.',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                analiseAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: UnicornLoading(),
                  ),
                  error: (e, _) => _ErroAnalise(
                    erro: e is GeminiPatrimonioException ? e.message : e.toString(),
                    onRetry: () => ref.invalidate(patrimonioAnaliseProvider),
                  ),
                  data: (analise) => _AnaliseConteudo(
                    analise: analise,
                    contas: contas,
                    onRefresh: () => ref.invalidate(patrimonioAnaliseProvider),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotaBadge extends StatelessWidget {
  final double nota;
  const _NotaBadge({required this.nota});

  @override
  Widget build(BuildContext context) {
    final cor = nota >= 7.5 ? AppColors.grn : nota >= 5.0 ? AppColors.org : AppColors.red;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Text(
        '${nota.toStringAsFixed(1)}/10',
        style: AppTextStyles.caption.copyWith(color: cor, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ErroAnalise extends StatelessWidget {
  final String erro;
  final VoidCallback onRetry;
  const _ErroAnalise({required this.erro, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            '⚠️ $erro',
            style: AppTextStyles.caption.copyWith(color: AppColors.org),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Tentar novamente'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.acc,
              side: const BorderSide(color: AppColors.acc),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnaliseConteudo extends StatelessWidget {
  final PatrimonioAnalise analise;
  final List<Map<String, dynamic>> contas;
  final VoidCallback onRefresh;
  const _AnaliseConteudo({
    required this.analise,
    required this.contas,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nota + resumo
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NotaBadge(nota: analise.notaGeral),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  analise.resumo,
                  style: AppTextStyles.bodySm.copyWith(height: 1.5),
                ),
              ),
            ],
          ),

          if (analise.pontosPositivos.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SecaoLabel(label: 'PONTOS FORTES', cor: AppColors.grn),
            const SizedBox(height: 8),
            ...analise.pontosPositivos.map((p) => _BulletItem(texto: p, cor: AppColors.grn, icone: '✅')),
          ],

          if (analise.alertas.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SecaoLabel(label: 'ATENÇÃO', cor: AppColors.org),
            const SizedBox(height: 8),
            ...analise.alertas.map((a) => _BulletItem(texto: a, cor: AppColors.org, icone: '⚠️')),
          ],

          if (analise.sugestoes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SecaoLabel(label: 'SUGESTÕES DA IA', cor: AppColors.acc),
            const SizedBox(height: 10),
            ...analise.sugestoes.map((s) => _SugestaoCard(sugestao: s, contas: contas)),
          ],

          if (analise.distribuicaoIdeal.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.acc.withOpacity(0.07),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.acc.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DISTRIBUIÇÃO IDEAL',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.acc, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          analise.distribuicaoIdeal,
                          style: AppTextStyles.caption.copyWith(height: 1.5, color: AppColors.tx),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: onRefresh,
                child: Row(
                  children: [
                    const Icon(Icons.refresh_rounded, size: 14, color: AppColors.mu),
                    const SizedBox(width: 4),
                    Text('Atualizar análise', style: AppTextStyles.caption.copyWith(color: AppColors.mu)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SecaoLabel extends StatelessWidget {
  final String label;
  final Color cor;
  const _SecaoLabel({required this.label, required this.cor});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: AppTextStyles.caption.copyWith(
            color: cor, fontWeight: FontWeight.w700, letterSpacing: 0.8),
      );
}

class _BulletItem extends StatelessWidget {
  final String texto;
  final Color cor;
  final String icone;
  const _BulletItem({required this.texto, required this.cor, required this.icone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icone, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, style: AppTextStyles.caption.copyWith(color: AppColors.tx, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _SugestaoCard extends StatelessWidget {
  final Sugestao sugestao;
  final List<Map<String, dynamic>> contas;
  const _SugestaoCard({required this.sugestao, required this.contas});

  // Tenta encontrar a conta mencionada no título/descrição da sugestão
  Map<String, dynamic>? _contaRelacionada() {
    final texto = '${sugestao.titulo} ${sugestao.descricao}'.toLowerCase();
    for (final c in contas) {
      final nome = (c['nome'] as String? ?? '').toLowerCase();
      final banco = (c['banco'] as String? ?? '').toLowerCase();
      if (nome.isNotEmpty && texto.contains(nome)) return c;
      if (banco.isNotEmpty && texto.contains(banco)) return c;
    }
    return null;
  }

  bool get _podeSimular =>
      sugestao.descricao.toLowerCase().contains('cdb') ||
      sugestao.descricao.toLowerCase().contains('tesouro') ||
      sugestao.descricao.toLowerCase().contains('lci') ||
      sugestao.descricao.toLowerCase().contains('lca') ||
      sugestao.descricao.toLowerCase().contains('migr') ||
      sugestao.descricao.toLowerCase().contains('transfer') ||
      sugestao.titulo.toLowerCase().contains('realoc') ||
      sugestao.titulo.toLowerCase().contains('migr');

  @override
  Widget build(BuildContext context) {
    final corImpacto = sugestao.impacto == 'alto'
        ? AppColors.grn
        : sugestao.impacto == 'medio'
            ? AppColors.org
            : AppColors.mu;

    final labelUrgencia = sugestao.urgencia == 'agora'
        ? '🔴 Agora'
        : sugestao.urgencia == 'proximo_mes'
            ? '🟡 Próximo mês'
            : '🟢 Sem pressa';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sugestao.titulo,
                  style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: corImpacto.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'impacto ${sugestao.impacto}',
                  style: AppTextStyles.caption.copyWith(color: corImpacto, fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            sugestao.descricao,
            style: AppTextStyles.caption.copyWith(color: AppColors.tx, height: 1.5),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(labelUrgencia, style: AppTextStyles.caption.copyWith(fontSize: 10)),
              if (_podeSimular)
                GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => SimuladorRealocacaoSheet(
                      contaInicial: _contaRelacionada(),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.acc.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.acc.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calculate_rounded, size: 12, color: AppColors.acc),
                        const SizedBox(width: 4),
                        Text(
                          'Simular',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.acc, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Gráfico de evolução do patrimônio ─────────────────────────────────────────

class _GraficoEvolucao extends StatefulWidget {
  final List<({String mes, double total})> evolucao;
  final NumberFormat fmt;
  const _GraficoEvolucao({required this.evolucao, required this.fmt});

  @override
  State<_GraficoEvolucao> createState() => _GraficoEvolucaoState();
}

class _GraficoEvolucaoState extends State<_GraficoEvolucao> {
  int? _toucado;

  @override
  Widget build(BuildContext context) {
    final dados = widget.evolucao;
    final minY = dados.map((e) => e.total).reduce((a, b) => a < b ? a : b);
    final maxY = dados.map((e) => e.total).reduce((a, b) => a > b ? a : b);
    final range = (maxY - minY).clamp(1.0, double.infinity);
    // Padding visual de 10% acima/abaixo
    final chartMinY = (minY - range * 0.1).clamp(0.0, double.infinity);
    final chartMaxY = maxY + range * 0.1;

    final spots = dados.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.total))
        .toList();

    final cresceu = dados.last.total >= dados.first.total;
    final corLinha = cresceu ? AppColors.grn : AppColors.red;
    final diff = dados.last.total - dados.first.total;
    final pct = dados.first.total > 0
        ? (diff / dados.first.total * 100)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(
            'EVOLUÇÃO',
            style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
          const SizedBox(width: 8),
          if (dados.length >= 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: corLinha.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${diff >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}% em ${dados.length} meses',
                style: AppTextStyles.caption
                    .copyWith(color: corLinha, fontSize: 10),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: LineChart(
            LineChartData(
              minY: chartMinY,
              maxY: chartMaxY,
              clipData: const FlClipData.all(),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= dados.length) return const SizedBox.shrink();
                      final mes = dados[idx].mes; // 'YYYY-MM'
                      const meses = ['','jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'];
                      final m = int.tryParse(mes.split('-')[1]) ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          meses[m],
                          style: AppTextStyles.caption.copyWith(fontSize: 9),
                        ),
                      );
                    },
                    reservedSize: 18,
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchCallback: (event, response) {
                  if (response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
                    setState(() => _toucado = response.lineBarSpots!.first.spotIndex);
                  } else if (event is FlTapUpEvent || event is FlPanEndEvent) {
                    setState(() => _toucado = null);
                  }
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surf,
                  getTooltipItems: (spots) => spots.map((s) {
                    final idx = s.spotIndex;
                    final item = dados[idx];
                    return LineTooltipItem(
                      widget.fmt.format(item.total),
                      AppTextStyles.caption.copyWith(
                          color: corLinha, fontWeight: FontWeight.w700),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: corLinha,
                  barWidth: 2,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, idx) => FlDotCirclePainter(
                      radius: idx == _toucado ? 5 : 3,
                      color: idx == _toucado ? corLinha : AppColors.card,
                      strokeWidth: 2,
                      strokeColor: corLinha,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        corLinha.withOpacity(0.18),
                        corLinha.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Metas com prazo ────────────────────────────────────────────────────────────

class _MetasComPrazo extends ConsumerWidget {
  final AsyncValue<List<Map<String, dynamic>>> contasAsync;
  const _MetasComPrazo({required this.contasAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contas = contasAsync.value ?? [];
    final comMeta = contas
        .where((c) =>
            (c['meta_saldo'] as num?) != null &&
            (c['meta_saldo'] as num).toDouble() > 0)
        .toList();

    if (comMeta.isEmpty) return const SizedBox.shrink();

    final saldoLivre = ref.watch(saldoLivreProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(children: [
            Text('Metas de poupança', style: AppTextStyles.titleSm),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${comMeta.length}',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.gold, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          ...comMeta.map((c) => _MetaCard(conta: c, saldoLivreDisponivel: saldoLivre)),
        ],
      ),
    );
  }
}

class _MetaCard extends StatefulWidget {
  final Map<String, dynamic> conta;
  final double saldoLivreDisponivel;
  const _MetaCard({required this.conta, required this.saldoLivreDisponivel});

  @override
  State<_MetaCard> createState() => _MetaCardState();
}

class _MetaCardState extends State<_MetaCard> {
  late double _aporte;
  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    // Sugestão inicial: 20% do saldo livre, mínimo R$ 50
    _aporte = (widget.saldoLivreDisponivel * 0.2).clamp(50.0, 5000.0);
  }

  double get _saldo => (widget.conta['saldo_atual'] as num?)?.toDouble() ?? 0;
  double get _meta => (widget.conta['meta_saldo'] as num?)?.toDouble() ?? 0;
  double get _rendMensal => (widget.conta['rendimento_mensal'] as num?)?.toDouble() ?? 0;
  double get _progresso => _meta > 0 ? (_saldo / _meta).clamp(0.0, 1.0) : 0;
  double get _falta => (_meta - _saldo).clamp(0.0, double.infinity);

  // Meses para atingir a meta com juros compostos + aportes mensais
  // Fórmula: FV = PV*(1+r)^n + PMT*((1+r)^n - 1)/r
  // Resolvemos numericamente (iteração simples)
  int _calcularMeses(double aporte) {
    if (_falta <= 0) return 0;
    if (aporte <= 0 && _rendMensal <= 0) return 9999;
    double saldo = _saldo;
    final r = _rendMensal / 100;
    for (var i = 1; i <= 600; i++) {
      saldo = saldo * (1 + r) + aporte;
      if (saldo >= _meta) return i;
    }
    return 9999; // >50 anos
  }

  String _formatarPrazo(int meses) {
    if (meses == 0) return 'Meta atingida! 🎉';
    if (meses >= 9999) return 'Nunca (aporte insuficiente)';
    if (meses < 12) return '$meses ${meses == 1 ? 'mês' : 'meses'}';
    final anos = meses ~/ 12;
    final resto = meses % 12;
    if (resto == 0) return '$anos ${anos == 1 ? 'ano' : 'anos'}';
    return '$anos ${anos == 1 ? 'ano' : 'anos'} e $resto ${resto == 1 ? 'mês' : 'meses'}';
  }

  DateTime? _dataChegada(int meses) {
    if (meses <= 0 || meses >= 9999) return null;
    final now = DateTime.now();
    var mes = now.month + meses;
    var ano = now.year + (mes - 1) ~/ 12;
    mes = ((mes - 1) % 12) + 1;
    return DateTime(ano, mes);
  }

  @override
  Widget build(BuildContext context) {
    final nome = widget.conta['nome'] as String? ?? '';
    final emoji = widget.conta['emoji'] as String? ?? '🎯';
    final mesesAtual = _calcularMeses(_aporte);
    final dataChegada = _dataChegada(mesesAtual);
    final mesesSemAporte = _calcularMeses(0);
    final ganhoEmMeses = mesesSemAporte - mesesAtual;

    final corProgresso = _progresso >= 0.9
        ? AppColors.grn
        : _progresso >= 0.5
            ? AppColors.acc
            : AppColors.gold;

    final maxSlider = (widget.saldoLivreDisponivel * 0.8).clamp(200.0, 10000.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nome, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  '${(_progresso * 100).toStringAsFixed(0)}% da meta',
                  style: AppTextStyles.caption.copyWith(color: corProgresso),
                ),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmt.format(_saldo),
                  style: AppTextStyles.monoSm.copyWith(color: AppColors.tx)),
              Text('de ${_fmt.format(_meta)}',
                  style: AppTextStyles.caption.copyWith(fontSize: 10)),
            ]),
          ]),

          const SizedBox(height: 12),

          // Barra de progresso
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progresso,
              backgroundColor: AppColors.bord,
              color: corProgresso,
              minHeight: 6,
            ),
          ),

          if (_falta > 0) ...[
            const SizedBox(height: 16),

            // Prazo estimado
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.acc.withOpacity(0.07),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.acc.withOpacity(0.15)),
              ),
              child: Row(children: [
                const Text('📅', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      _formatarPrazo(mesesAtual),
                      style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700, color: AppColors.acc),
                    ),
                    if (dataChegada != null)
                      Text(
                        'Chegada em ${_nomeMes(dataChegada.month)}/${dataChegada.year}',
                        style: AppTextStyles.caption,
                      ),
                    if (ganhoEmMeses > 0 && _aporte > 0)
                      Text(
                        'Aportando ${_fmt.format(_aporte)}/mês economiza $ganhoEmMeses ${ganhoEmMeses == 1 ? 'mês' : 'meses'}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.grn, height: 1.4),
                      ),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Faltam', style: AppTextStyles.caption),
                  Text(
                    _fmt.format(_falta),
                    style: AppTextStyles.monoSm.copyWith(color: AppColors.org),
                  ),
                ]),
              ]),
            ),

            const SizedBox(height: 14),

            // Slider de aporte
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Aporte mensal', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
              Text(
                _fmt.format(_aporte),
                style: AppTextStyles.monoSm.copyWith(color: AppColors.acc, fontSize: 14),
              ),
            ]),
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.acc,
                inactiveTrackColor: AppColors.bord,
                thumbColor: AppColors.acc,
                overlayColor: AppColors.acc.withOpacity(0.12),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: _aporte.clamp(0, maxSlider),
                min: 0,
                max: maxSlider,
                divisions: 40,
                onChanged: (v) => setState(() => _aporte = v),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('R\$ 0', style: AppTextStyles.caption.copyWith(fontSize: 9)),
              Text(
                'Saldo livre: ${_fmt.format(widget.saldoLivreDisponivel)}',
                style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.mu),
              ),
            ]),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.grn.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                '🎉 Meta atingida!',
                style: AppTextStyles.body.copyWith(
                    color: AppColors.grn, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _nomeMes(int m) {
    const meses = ['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'];
    return meses[m - 1];
  }
}

// Import circular evitado — definido aqui mesmo
class FormContaPatrimonioSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? conta;
  const FormContaPatrimonioSheet({super.key, this.conta});

  @override
  ConsumerState<FormContaPatrimonioSheet> createState() => _FormContaPatrimonioSheetState();
}

class _FormContaPatrimonioSheetState extends ConsumerState<FormContaPatrimonioSheet> {
  final _nomeCtrl = TextEditingController();
  final _bancoCtrl = TextEditingController();
  final _saldoCtrl = TextEditingController();
  final _rendimentoCtrl = TextEditingController();
  final _metaCtrl = TextEditingController();

  String _tipo = 'conta_corrente';
  String _emoji = '🏦';
  bool _salvando = false;

  bool get _editando => widget.conta != null;

  static const _tipos = [
    ('conta_corrente', 'Conta corrente', '🏦'),
    ('poupanca', 'Poupança', '🐷'),
    ('investimento', 'Investimento', '📈'),
    ('caixinha', 'Caixinha', '📦'),
    ('carteira', 'Carteira física', '👛'),
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.conta;
    if (c != null) {
      _nomeCtrl.text = c['nome'] as String? ?? '';
      _bancoCtrl.text = c['banco'] as String? ?? '';
      _saldoCtrl.text = (c['saldo_atual'] as num?)?.toStringAsFixed(2).replaceAll('.', ',') ?? '';
      _tipo = c['tipo'] as String? ?? 'conta_corrente';
      _emoji = c['emoji'] as String? ?? '🏦';
      final rend = c['rendimento_mensal'];
      if (rend != null) _rendimentoCtrl.text = rend.toString().replaceAll('.', ',');
      final meta = c['meta_saldo'];
      if (meta != null) _metaCtrl.text = (meta as num).toStringAsFixed(2).replaceAll('.', ',');
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose(); _bancoCtrl.dispose(); _saldoCtrl.dispose();
    _rendimentoCtrl.dispose(); _metaCtrl.dispose();
    super.dispose();
  }

  double _parse(String v) => double.tryParse(v.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;

  Future<void> _salvar() async {
    if (_nomeCtrl.text.trim().isEmpty) return;
    final perfil = ref.read(perfilUsuarioLogadoProvider).value;
    if (perfil == null) return;

    setState(() => _salvando = true);
    try {
      final data = {
        'nome': _nomeCtrl.text.trim(),
        'banco': _bancoCtrl.text.trim().isEmpty ? null : _bancoCtrl.text.trim(),
        'tipo': _tipo,
        'emoji': _emoji,
        'saldo_atual': _parse(_saldoCtrl.text),
        'rendimento_mensal': _rendimentoCtrl.text.trim().isEmpty ? null : _parse(_rendimentoCtrl.text),
        'meta_saldo': _metaCtrl.text.trim().isEmpty ? null : _parse(_metaCtrl.text),
        'familia_id': perfil['familia_id'],
      };

      if (_editando) {
        await supabase.from('contas_patrimonio').update(data).eq('id', widget.conta!['id'] as String);
      } else {
        await supabase.from('contas_patrimonio').insert(data);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  Future<void> _deletar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
        title: Text('Excluir conta?', style: AppTextStyles.titleSm),
        content: Text('Esta ação não pode ser desfeita.', style: AppTextStyles.bodySm.copyWith(color: AppColors.mu)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar', style: TextStyle(color: AppColors.mu))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Excluir', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _salvando = true);
    await supabase.from('contas_patrimonio').delete().eq('id', widget.conta!['id'] as String);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
              child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text(_editando ? 'Editar conta' : 'Nova conta / investimento', style: AppTextStyles.titleSm),
            const SizedBox(height: 4),
            Text('Visível apenas para administradores', style: AppTextStyles.caption.copyWith(color: AppColors.org)),
            const SizedBox(height: 20),

            // Seletor de tipo com emoji
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _tipos.map((t) {
                  final sel = t.$1 == _tipo;
                  return GestureDetector(
                    onTap: () => setState(() { _tipo = t.$1; _emoji = t.$3; }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.acc.withOpacity(0.15) : AppColors.surf,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sel ? AppColors.acc : AppColors.bord, width: sel ? 1.5 : 0.5),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(t.$3, style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(t.$2, style: AppTextStyles.caption.copyWith(color: sel ? AppColors.acc : AppColors.mu, fontSize: 10)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Nome
            _Campo(ctrl: _nomeCtrl, label: 'NOME DA CONTA', hint: 'Ex: Nubank Principal'),
            const SizedBox(height: 12),
            // Banco
            _Campo(ctrl: _bancoCtrl, label: 'BANCO (opcional)', hint: 'Ex: Nubank, Itaú'),
            const SizedBox(height: 12),
            // Saldo
            _Campo(ctrl: _saldoCtrl, label: 'SALDO ATUAL (R\$)', hint: '0,00', keyboard: TextInputType.number),
            const SizedBox(height: 12),
            // Rendimento
            _Campo(ctrl: _rendimentoCtrl, label: 'RENDIMENTO MENSAL % (opcional)', hint: '0,00', keyboard: TextInputType.number),
            const SizedBox(height: 12),
            // Meta
            _Campo(ctrl: _metaCtrl, label: 'META DE SALDO (opcional)', hint: '0,00', keyboard: TextInputType.number),
            const SizedBox(height: 24),

            // Botão salvar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.acc,
                  foregroundColor: AppColors.bg,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                ),
                child: _salvando
                    ? const CircularProgressIndicator(color: AppColors.bg, strokeWidth: 2)
                    : Text(_editando ? 'Salvar alterações' : 'Adicionar conta',
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.bg)),
              ),
            ),

            if (_editando) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _salvando ? null : _deletar,
                  child: Text('EXCLUIR CONTA',
                    style: AppTextStyles.caption.copyWith(color: AppColors.red, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final TextInputType keyboard;

  const _Campo({required this.ctrl, required this.label, required this.hint, this.keyboard = TextInputType.text});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.mu),
        labelStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
        filled: true,
        fillColor: AppColors.surf,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
