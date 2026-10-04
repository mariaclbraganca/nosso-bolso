import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/dia_provider.dart';
import '../../core/providers/envelopes_provider.dart';
import '../../core/services/financeiro_ext_service.dart';
import '../../core/services/notification_service.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';
import '../sheets/comum.dart';
import '../lancar/lancar.dart';
import 'widgets/cartao_resumo_dia.dart';
import 'widgets/fechamento_pendente_card.dart';
import 'widgets/seletor_envelope_modal.dart';

/// Ritual diário: confere o que entrou hoje, resolve compras capturadas sem
/// envelope (Nubank/iFood) e fecha o dia mantendo a sequência.
class FechamentoDiaScreen extends ConsumerStatefulWidget {
  const FechamentoDiaScreen({super.key});

  @override
  ConsumerState<FechamentoDiaScreen> createState() => _FechamentoDiaScreenState();
}

class _FechamentoDiaScreenState extends ConsumerState<FechamentoDiaScreen> {
  final Map<String, Map<String, dynamic>> _ajustes = {};
  final Set<String> _descartadas = {};
  bool _fechando = false;

  @override
  void initState() {
    super.initState();
    NotificationService.silenciarAlarmeAtivo();
  }

  Map<String, dynamic>? _envelopeDe(Map<String, dynamic> p) =>
      _ajustes[p['compra_id']] ?? (p['envelope_sugerido'] as Map<String, dynamic>?);

  Future<void> _escolherEnvelope(Map<String, dynamic> p) async {
    final envelopes = ref.read(envelopesViseisProvider);
    final escolhido = await mostrarModalEscolhaEnvelope(
      context: context,
      estabelecimento: p['estabelecimento'] as String? ?? 'Compra',
      envelopes: envelopes,
    );
    if (escolhido == null) return;
    setState(() {
      _ajustes[p['compra_id'] as String] = escolhido;
      _descartadas.remove(p['compra_id']);
    });
  }

  Future<void> _fechar() async {
    setState(() => _fechando = true);
    try {
      final r = await FinanceiroExtService.fecharDia(
        ajustes: {for (final e in _ajustes.entries) e.key: e.value['id'] as String},
        descartar: _descartadas.toList(),
      );
      ref.invalidate(resumoDiaProvider);
      if (r['fechado'] != true) {
        return avisar('Escolha o envelope das compras marcadas antes de fechar.', erro: true);
      }
      HapticFeedback.heavyImpact();
      await NotificationService.agendarAlarmeFechamento(hojeFechado: true);
      final streak = (r['resumo']?['streak'] as num?)?.toInt() ?? 0;
      ref.sweet(
        streak <= 1 ? 'Dia fechado! Amanhã a gente continua.' : '$streak dias seguidos fechando o dia. Que constância!',
        mood: UnicornMood.celebrate,
      );
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _fechando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(resumoDiaProvider);
    return Scaffold(
      appBar: AppBar(),
      body: async.when(
        loading: () => const UnicornCarregando(texto: 'Juntando o dia…'),
        error: (e, _) => UnicornErro(
          mensagem: 'Não consegui carregar o dia. Verifique a internet.',
          onTentar: () => ref.invalidate(resumoDiaProvider),
        ),
        data: _conteudo,
      ),
    );
  }

  Widget _conteudo(Map<String, dynamic> r) {
    final pendentes = (r['pendentes'] as List? ?? []).cast<Map<String, dynamic>>();
    final gastos = (r['gastos'] as List? ?? []).cast<Map<String, dynamic>>();
    final semEnvelope = pendentes.where((p) => !_descartadas.contains(p['compra_id']) && _envelopeDe(p) == null).length;
    final streak = (r['streak'] as num?)?.toInt() ?? 0;
    final totalDia = (r['total_dia'] as num?)?.toDouble() ?? 0;
    final porDia = r['pode_gastar_por_dia'] as num?;
    final dias = (r['dias_restantes'] as num?)?.toInt() ?? 0;
    final hoje = DateFormat("EEEE, d", 'pt_BR').format(DateTime.now());

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: NBColors.verde,
            onRefresh: () => ref.refresh(resumoDiaProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 0, NBSpacing.margemTela, NBSpacing.xxl),
              children: [
                if (streak > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SeloNB('$streak ${streak == 1 ? 'dia seguido' : 'dias seguidos'}',
                        cor: NBColors.ambarTexto, fundo: NBColors.ambarClaro),
                  ),
                const SizedBox(height: NBSpacing.s),
                Text('Fechamento do dia', style: NBText.tituloTela),
                Text(hoje, style: NBText.corpo.copyWith(color: NBColors.tintaSuave)),
                const SizedBox(height: NBSpacing.l),
                CartaoResumoDia(
                  gastos: gastos,
                  totalDia: totalDia,
                  porDia: porDia,
                  dias: dias,
                  fechado: r['fechado'] == true,
                  fechadoPor: r['fechado_por'] as String?,
                ),
                if (pendentes.isNotEmpty) ...[
                  const SizedBox(height: NBSpacing.xl),
                  Text('Para resolver (${pendentes.length})', style: NBText.secao),
                  Text('Confira o envelope sugerido. Toque para trocar.', style: NBText.legenda),
                  const SizedBox(height: NBSpacing.m),
                  for (final p in pendentes) FechamentoPendenteCard(
                    p: p,
                    envelope: _envelopeDe(p),
                    descartada: _descartadas.contains(p['compra_id']),
                    onEscolher: () => _escolherEnvelope(p),
                    onDescartar: () => setState(() {
                      final id = p['compra_id'] as String;
                      _descartadas.contains(id) ? _descartadas.remove(id) : _descartadas.add(id);
                    }),
                  ),
                ],
                const SizedBox(height: NBSpacing.xl),
                Text('Lançados hoje', style: NBText.secao),
                const SizedBox(height: NBSpacing.s),
                if (gastos.isEmpty) Text('Nenhum gasto lançado hoje.', style: NBText.legenda),
                for (final g in gastos)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: NBSpacing.s),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g['descricao'] as String? ?? '—', style: NBText.corpo.copyWith(fontWeight: FontWeight.w700)),
                              Text([g['envelope'], g['quem']].whereType<String>().join(' · '), style: NBText.legenda),
                            ],
                          ),
                        ),
                        Text(brl(-((g['valor'] as num?) ?? 0)), style: NBText.corpo.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                const SizedBox(height: NBSpacing.m),
                OutlinedButton.icon(
                  onPressed: () => abrirNovoLancamento(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Faltou algum gasto?'),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.l),
            child: BotaoPrincipal(
              rotulo: semEnvelope > 0
                  ? 'Escolha o envelope de $semEnvelope ${semEnvelope == 1 ? 'compra' : 'compras'}'
                  : 'Fechar o dia',
              carregando: _fechando,
              onPressed: semEnvelope > 0 ? null : _fechar,
            ),
          ),
        ),
      ],
    );
  }
}
