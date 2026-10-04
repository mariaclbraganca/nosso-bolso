import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/saude_provider.dart';
import '../../core/providers/usuarios_provider.dart';
import '../../core/services/saude_api_service.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../core/providers/compras_provider.dart';
import '../../core/services/api_service.dart';
import '../compras/nfce_fluxo.dart';
import '../compras/widgets/compras_falhas_card.dart';
import '../compras/widgets/feedback_consumo_tab.dart';
import '../compras/widgets/lista_compras_tab.dart';
import '../minha_vida/exercicio/exercicio_historico_view.dart';
import '../minha_vida/exercicio/exercicio_tab.dart';
import '../minha_vida/exercicio/widgets/form_treino_sheet.dart';
import '../minha_vida/jejum/jejum_tab.dart';
import '../minha_vida/saude/historico_saude_screen.dart';
import '../minha_vida/saude/perfil_metabolico_screen.dart';
import '../minha_vida/saude/saude_tab.dart';
import '../minha_vida/saude/sugestao_jantar_screen.dart';
import '../minha_vida/saude/widgets/form_refeicao_sheet.dart';
import '../minha_vida/saude/widgets/refeicoes_card.dart';
import '../sheets/comum.dart';
import 'barra_modulo.dart';

/// Aba aberta em cada módulo (global para notificações e atalhos abrirem direto).
final abaAlimentacaoProvider = StateProvider<int>((ref) => 0); // 0 Hoje, 1 Refeições, 2 Jejum
final abaExerciciosProvider = StateProvider<int>((ref) => 0); // 0 Hoje, 1 Semana, 2 Histórico

String _hoje() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

Future<void> _folha(BuildContext context, Widget filho) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NBColors.papel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => filho,
    );

AppBar _topo(String titulo, VoidCallback onVoltar, {List<Widget>? acoes}) => AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: 112,
      leading: Padding(padding: const EdgeInsets.only(left: 8), child: VoltarModulos(onTap: onVoltar)),
      title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(titulo, style: NBText.secao)),
      centerTitle: false,
      actions: acoes,
    );

// ── Alimentação e jejum ────────────────────────────────────────────────

/// Módulo Alimentação e jejum: Hoje · Refeições · + · Jejum · Mais.
/// Abre sempre no seu; dá para ver o de outro membro pelo seletor do topo.
class AlimentacaoShell extends ConsumerWidget {
  const AlimentacaoShell({super.key, required this.onVoltar});
  final VoidCallback onVoltar;

  static const _titulos = ['Hoje', 'Refeições', 'Jejum'];

  void _lancar(BuildContext context, WidgetRef ref, String membroId, String familiaId) {
    Future<void> agua(int ml) async {
      try {
        await SaudeApiService.registrarHidratacao(membroId, familiaId, volumeMl: ml, data: _hoje());
        ref.invalidate(hidratacaoDiaProvider);
        ref.invalidate(extratoDiarioProvider);
        avisar('+$ml ml de água registrados.');
      } catch (e) {
        avisar(mensagemErro(e), erro: true);
      }
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 4), child: TopoSheet(titulo: 'Novo lançamento')),
            ListTile(
              leading: const Icon(Icons.restaurant_rounded),
              title: const Text('Refeição'),
              subtitle: const Text('Texto, foto ou manual'),
              onTap: () {
                Navigator.pop(ctx);
                _folha(context, FormRefeicaoSheet(membroId: membroId, familiaId: familiaId, data: _hoje()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.water_drop_outlined),
              title: const Text('Água'),
              subtitle: Row(children: [
                TextButton(onPressed: () => {Navigator.pop(ctx), agua(250)}, child: const Text('+250 ml')),
                TextButton(onPressed: () => {Navigator.pop(ctx), agua(500)}, child: const Text('+500 ml')),
              ]),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Jejum'),
              subtitle: const Text('Iniciar ou concluir'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(abaAlimentacaoProvider.notifier).state = 2;
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _mais(BuildContext context, String membroId, String familiaId) {
    void ir(Widget tela) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => tela));
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 4), child: TopoSheet(titulo: 'Mais')),
            for (final (icone, titulo, sub, tela) in [
              (Icons.kitchen_outlined, 'Despensa', 'Lista de compras e estoque de casa', const DespensaScreen() as Widget),
              (Icons.assignment_outlined, 'Plano alimentar', 'Meta diária e perfil metabólico', PerfilMetabolicoScreen(membroId: membroId)),
              (Icons.show_chart_rounded, 'Peso e evolução', 'Calorias, proteína e peso', HistoricoSaudeScreen(membroId: membroId)),
              (Icons.dinner_dining_outlined, 'Sugestão de jantar', 'Com o que tem em casa',
                  SugestaoJantarScreen(membroId: membroId, familiaId: familiaId)),
            ])
              ListTile(
                leading: Icon(icone),
                title: Text(titulo),
                subtitle: Text(sub),
                onTap: () {
                  Navigator.pop(ctx);
                  ir(tela);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aba = ref.watch(abaAlimentacaoProvider);
    final perfil = ref.watch(perfilUsuarioLogadoProvider).valueOrNull;
    final familiaId = perfil?['familia_id'] as String? ?? '';
    final membroId = ref.watch(membroSaudeProvider) ?? perfil?['id'] as String? ?? '';
    return Scaffold(
      appBar: _topo(_titulos[aba], onVoltar, acoes: const [SeletorMembroSaude(), SizedBox(width: 8)]),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: aba,
          children: [
            SaudeTab(key: ValueKey('saude$membroId'), membroId: membroId, familiaId: familiaId, comRefeicoes: false),
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [RefeicoesCard(membroId: membroId, familiaId: familiaId, data: _hoje())],
            ),
            JejumTab(key: ValueKey('jejum$membroId'), membroId: membroId, familiaId: familiaId),
          ],
        ),
      ),
      bottomNavigationBar: BarraModulo(
        cor: NBColors.lavanda,
        itens: [
          itemBarra('Hoje', Icons.today_outlined, Icons.today_rounded),
          itemBarra('Refeições', Icons.restaurant_outlined, Icons.restaurant_rounded),
          itemBarra('Jejum', Icons.timer_outlined, Icons.timer_rounded),
          itemBarra('Mais', Icons.menu_rounded),
        ],
        ativo: aba,
        onItem: (i) => i == 3 ? _mais(context, membroId, familiaId) : ref.read(abaAlimentacaoProvider.notifier).state = i,
        // O + lança sempre para quem está logado (ver o outro é só consulta).
        onLancar: () => _lancar(context, ref, perfil?['id'] as String? ?? membroId, familiaId),
      ),
    );
  }
}

/// "Ver alimentação de: Nome ▾". Abre no seu; os outros só se você escolher.
class SeletorMembroSaude extends ConsumerWidget {
  const SeletorMembroSaude({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilUsuarioLogadoProvider).valueOrNull;
    final eu = perfil?['id'] as String?;
    // Abre no seu; os outros só aparecem se deixaram a família ver.
    final membros = [
      for (final m in ref.watch(listaUsuariosProvider).valueOrNull ?? const <Map<String, dynamic>>[])
        if (m['id'] == eu || alimentacaoVisivel(m)) m,
    ];
    if (membros.length < 2) return const SizedBox.shrink();
    final atual = ref.watch(membroSaudeProvider) ?? eu;
    String nome(Map m) {
      final n = (m['nome'] as String? ?? '').split(' ').first;
      return m['id'] == eu ? '$n (você)' : n;
    }

    final atualNome = membros.where((m) => m['id'] == atual).map(nome).firstOrNull ?? 'Você';
    return PopupMenuButton<String>(
      tooltip: 'Ver alimentação de',
      initialValue: atual,
      onSelected: (id) => ref.read(membroSaudeProvider.notifier).state = id,
      itemBuilder: (_) => [
        const PopupMenuItem<String>(enabled: false, child: Text('Ver alimentação de')),
        for (final m in membros) PopupMenuItem(value: m['id'] as String, child: Text(nome(m))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: atual == eu ? NBColors.afundado : NBColors.lavandaClara,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_rounded, size: 16, color: NBColors.tinta),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: Text(atualNome, style: NBText.legenda.copyWith(color: NBColors.tinta), overflow: TextOverflow.ellipsis),
          ),
          const Icon(Icons.arrow_drop_down_rounded, size: 18, color: NBColors.tinta),
        ]),
      ),
    );
  }
}

/// Despensa: lista de compras sugerida, controle de estoque (vem das notas
/// fiscais) e as notas que falharam na leitura.
class DespensaScreen extends ConsumerStatefulWidget {
  const DespensaScreen({super.key});

  @override
  ConsumerState<DespensaScreen> createState() => _DespensaScreenState();
}

class _DespensaScreenState extends ConsumerState<DespensaScreen> {
  var _estoque = false;

  Future<void> _dispensarFalhas() async {
    try {
      await ApiService.delete('/api/v1/compras/falhas', familiaId: perfilOuErro(ref)['familia_id'] as String);
      ref.invalidate(comprasFalhasProvider);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final falhas = ref.watch(comprasFalhasProvider).valueOrNull ?? const [];
    final feedback = ref.watch(feedbackPendenteProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text('Despensa', style: NBText.secao)),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          if (falhas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 8, NBSpacing.margemTela, 0),
              child: ComprasFalhasCard(
                falhas: falhas,
                onTentarDeNovo: (url) => processarNota(ref, url),
                onDispensar: _dispensarFalhas,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NBSpacing.margemTela, vertical: 8),
            child: Segmentado<bool>(
              opcoes: {false: 'Lista de compras', true: feedback.isEmpty ? 'Estoque' : 'Estoque (${feedback.length})'},
              valor: _estoque,
              onChanged: (v) => setState(() => _estoque = v),
            ),
          ),
          Expanded(child: _estoque ? const FeedbackConsumoTab() : const ListaComprasTab()),
        ]),
      ),
    );
  }
}

// ── Exercícios ─────────────────────────────────────────────────────────

/// Módulo Exercícios: Hoje · Semana · + · Histórico (sempre o seu).
class ExerciciosShell extends ConsumerWidget {
  const ExerciciosShell({super.key, required this.onVoltar});
  final VoidCallback onVoltar;

  static const _titulos = ['Hoje', 'Semana', 'Histórico'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aba = ref.watch(abaExerciciosProvider);
    final perfil = ref.watch(perfilUsuarioLogadoProvider).valueOrNull;
    final familiaId = perfil?['familia_id'] as String? ?? '';
    final membroId = perfil?['id'] as String? ?? '';
    return Scaffold(
      appBar: _topo(_titulos[aba], onVoltar),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: aba,
          children: [
            ExercicioHoje(membroId: membroId, familiaId: familiaId),
            ExercicioHistoricoView(membroId: membroId, mostrarHistorico: false),
            ExercicioHistoricoView(membroId: membroId, mostrarSemana: false),
          ],
        ),
      ),
      bottomNavigationBar: BarraModulo(
        cor: NBColors.ambarBarra,
        itens: [
          itemBarra('Hoje', Icons.today_outlined, Icons.today_rounded),
          itemBarra('Semana', Icons.bar_chart_rounded),
          itemBarra('Histórico', Icons.history_rounded),
        ],
        ativo: aba,
        onItem: (i) => ref.read(abaExerciciosProvider.notifier).state = i,
        onLancar: () => _folha(context, FormTreinoSheet(membroId: membroId, familiaId: familiaId, data: _hoje())),
      ),
    );
  }
}
