import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/compras_provider.dart';
import '../../core/providers/exercicio_provider.dart';
import '../../core/providers/fixos_provider.dart';
import '../../core/providers/plano_provider.dart';
import '../../core/providers/saude_provider.dart';
import '../../core/providers/usuarios_provider.dart';
import '../../core/providers/mes_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_navigator.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../config/config_screen.dart';
import '../extrato/extrato_screen.dart';
import '../home/home_screen.dart';
import '../lancar/lancar.dart';
import '../planos/contas_tab.dart';
import '../planos/planos_screen.dart';
import '../planos/futuro_screen.dart';
import '../sheets/comum.dart';
import 'barra_modulo.dart';
import 'modulos_saude.dart';

enum Modulo { financas, alimentacao, exercicios }

/// Módulo aberto (null = escolha do módulo, a tela inicial).
final moduloProvider = StateProvider<Modulo?>((ref) => null);

/// Aba de Finanças: Início, Envelopes ou Contas.
final abaFinancasProvider = StateProvider<int>((ref) => navHome);

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  @override
  void initState() {
    super.initState();
    registrarDestinos(_abrir);
    ref.listenManual(perfilUsuarioLogadoProvider, (_, perfil) {
      final fam = perfil.valueOrNull?['familia_id'] as String?;
      if (fam != null) _fecharMesAnterior(fam);
    }, fireImmediately: true);
  }

  static bool _fechamentoConferido = false;

  /// O mês fecha sozinho: na primeira abertura do mês, o backend fecha o
  /// anterior (se ainda não foi). Falha de rede não atrapalha o uso.
  Future<void> _fecharMesAnterior(String familiaId) async {
    if (_fechamentoConferido) return;
    _fechamentoConferido = true;
    try {
      final r = await ApiService.post('/fechamento/automatico', {'familia_id': familiaId});
      if (r['fechado'] == true) avisar('O mês de ${mesLabelLongo(r['mes'] as String).toLowerCase()} foi fechado.');
    } catch (e) {
      _fechamentoConferido = false;
      debugPrint('[Fechamento] automático não rodou: $e');
    }
  }

  @override
  void dispose() {
    cancelarDestinos();
    super.dispose();
  }

  void _abrir(Destino d) {
    if (!mounted) return;
    void modulo(Modulo m) => ref.read(moduloProvider.notifier).state = m;
    void financas(int aba) {
      modulo(Modulo.financas);
      ref.read(abaFinancasProvider.notifier).state = aba;
    }

    void empilhar(Widget tela) => navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => tela));
    switch (d) {
      case Destino.modulos:
        _voltar();
      case Destino.financas:
        financas(navHome);
      case Destino.envelopes:
        financas(navPlanos);
      case Destino.contas:
        financas(navContas);
      case Destino.extrato:
        modulo(Modulo.financas);
        empilhar(const ExtratoScreen());
      case Destino.compras:
        modulo(Modulo.financas);
        final ctx = navigatorKey.currentContext;
        if (ctx != null) abrirNovoLancamento(ctx);
      case Destino.alimentacao:
        modulo(Modulo.alimentacao);
      case Destino.jejum:
        modulo(Modulo.alimentacao);
        ref.read(abaAlimentacaoProvider.notifier).state = 2;
      case Destino.exercicios:
        modulo(Modulo.exercicios);
    }
  }

  void _voltar() => ref.read(moduloProvider.notifier).state = null;

  @override
  Widget build(BuildContext context) {
    final modulo = ref.watch(moduloProvider);
    return PopScope(
      canPop: modulo == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _voltar();
      },
      child: switch (modulo) {
        null => EscolhaModuloScreen(onEscolher: (m) => ref.read(moduloProvider.notifier).state = m),
        Modulo.financas => const _FinancasShell(),
        Modulo.alimentacao => AlimentacaoShell(onVoltar: _voltar),
        Modulo.exercicios => ExerciciosShell(onVoltar: _voltar),
      },
    );
  }
}

// ── Finanças ───────────────────────────────────────────────────────────

/// Finanças: Início · Envelopes · + · Contas · Mais.
class _FinancasShell extends ConsumerWidget {
  const _FinancasShell();

  Future<void> _abrirMais(BuildContext context) async {
    final escolha = await showModalBottomSheet<Widget>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 4), child: TopoSheet(titulo: 'Mais')),
            ListTile(
              leading: const Icon(Icons.update_rounded),
              title: const Text('Futuro'),
              subtitle: const Text('O que já devo, parcelas e simulações'),
              onTap: () => Navigator.pop(ctx, const FuturoScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.format_list_bulleted_rounded),
              title: const Text('Extrato'),
              subtitle: const Text('O que aconteceu, meses fechados e relatórios'),
              onTap: () => Navigator.pop(ctx, const ExtratoScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.savings_outlined),
              title: const Text('Patrimônio e reserva'),
              subtitle: const Text('Contas, investimentos, reserva e metas'),
              onTap: () => Navigator.pop(ctx, const PatrimonioScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Configurações'),
              onTap: () => Navigator.pop(ctx, const ConfigScreen()),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (escolha == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => escolha));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aba = ref.watch(abaFinancasProvider);
    return Scaffold(
      body: IndexedStack(
        index: aba,
        children: const [HomeScreen(), PlanosScreen(), ContasScreen()],
      ),
      bottomNavigationBar: BarraModulo(
        itens: [
          itemBarra('Início', Icons.home_outlined, Icons.home_rounded),
          itemBarra('Envelopes', Icons.mail_outline_rounded, Icons.mail_rounded),
          itemBarra('Contas', Icons.receipt_outlined, Icons.receipt_rounded),
          itemBarra('Mais', Icons.menu_rounded),
        ],
        ativo: aba,
        onItem: (i) => i == 3 ? _abrirMais(context) : ref.read(abaFinancasProvider.notifier).state = i,
        onLancar: () => abrirNovoLancamento(context),
      ),
    );
  }
}

// ── Escolha do módulo ──────────────────────────────────────────────────

/// Tela inicial: os três módulos com um resumo de cada.
class EscolhaModuloScreen extends ConsumerWidget {
  const EscolhaModuloScreen({super.key, required this.onEscolher});
  final ValueChanged<Modulo> onEscolher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilUsuarioLogadoProvider).valueOrNull;
    final nome = ((perfil?['nome'] as String?) ?? '').split(' ').first;
    final eu = perfil?['id'] as String? ?? '';
    final agora = DateTime.now();
    final hoje = DateFormat('yyyy-MM-dd').format(agora);
    final data = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(agora);

    // Finanças
    final l = ref.watch(limiteMesProvider).valueOrNull;
    final vencendo = ref
        .watch(fixosMesAtualProvider)
        .where((f) => f['pago'] != true && f['dia_vencimento'] is int)
        .where((f) => (f['dia_vencimento'] as int) >= agora.day && (f['dia_vencimento'] as int) <= agora.day + 7)
        .toList();
    final valorVencendo = vencendo.fold(0.0, (s, f) => s + ((f['valor'] as num?)?.toDouble() ?? 0) - ((f['valor_pago'] as num?)?.toDouble() ?? 0));
    final pendentes = ref.watch(comprasPendentesProvider).valueOrNull?.length ?? 0;

    // Alimentação e exercícios (sempre o seu)
    final args = (membroId: eu, data: hoje);
    final saude = eu.isEmpty ? null : ref.watch(extratoDiarioProvider(args)).valueOrNull;
    final exercicio = eu.isEmpty ? null : ref.watch(exercicioDiaProvider(args)).valueOrNull;
    final kcal = (saude?['calorias_consumidas_kcal'] as num?)?.round();
    final meta = (saude?['meta_calorica_kcal'] as num?)?.round();
    final minutos = (exercicio?['total_duracao_min'] as num?)?.round();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 20, NBSpacing.margemTela, 24),
          children: [
            Text(nome.isEmpty ? 'Olá' : 'Olá, $nome', style: NBText.tituloTela.copyWith(fontSize: 26)),
            const SizedBox(height: 2),
            Text('${data[0].toUpperCase()}${data.substring(1)} · o que vamos cuidar agora?', style: NBText.legenda),
            const SizedBox(height: NBSpacing.xl),
            _CartaoModulo(
              titulo: 'Finanças',
              icone: Icons.account_balance_wallet_outlined,
              cor: NBColors.verde,
              fundo: NBColors.verdeClaro,
              linhas: [
                if (l != null) ('Pode gastar ainda', brl(l.podeGastar)),
                ('Contas vencendo em 7 dias', vencendo.isEmpty ? 'nenhuma' : '${vencendo.length} · ${brl(valorVencendo)}'),
                if (pendentes > 0) ('Compras a confirmar', '$pendentes'),
              ],
              onTap: () => onEscolher(Modulo.financas),
            ),
            const SizedBox(height: NBSpacing.m),
            _CartaoModulo(
              titulo: 'Alimentação e jejum',
              icone: Icons.restaurant_outlined,
              cor: NBColors.lavanda,
              fundo: NBColors.lavandaClara,
              linhas: [
                ('Consumido hoje', kcal == null ? '—' : '$kcal${meta == null ? '' : ' de $meta'} kcal'),
              ],
              onTap: () => onEscolher(Modulo.alimentacao),
            ),
            const SizedBox(height: NBSpacing.m),
            _CartaoModulo(
              titulo: 'Exercícios',
              icone: Icons.directions_run_rounded,
              cor: NBColors.ambarTexto,
              fundo: NBColors.ambarClaro,
              linhas: [('Atividade de hoje', minutos == null ? '—' : '$minutos min')],
              onTap: () => onEscolher(Modulo.exercicios),
            ),
            const SizedBox(height: NBSpacing.xl),
            BotaoSecundario(
              rotulo: 'Configurações',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConfigScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoModulo extends StatelessWidget {
  const _CartaoModulo({
    required this.titulo,
    required this.icone,
    required this.cor,
    required this.fundo,
    required this.linhas,
    required this.onTap,
  });
  final String titulo;
  final IconData icone;
  final Color cor;
  final Color fundo;
  final List<(String, String)> linhas;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Abrir $titulo',
        child: CartaoNB(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icone, color: cor, size: 22),
                ),
                const SizedBox(width: NBSpacing.m),
                Expanded(child: Text(titulo, style: NBText.rotulo.copyWith(fontSize: 17))),
                Icon(Icons.chevron_right_rounded, color: cor),
              ]),
              const SizedBox(height: NBSpacing.s),
              for (final (r, v) in linhas)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text(r, style: NBText.corpo.copyWith(fontSize: 14, color: NBColors.tintaSuave))),
                    const SizedBox(width: 8),
                    Text(v, style: NBText.corpo.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ],
          ),
        ),
      );
}
