import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/saude_provider.dart';
import '../../../core/services/saude_api_service.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';
import '../../sheets/comum.dart';

/// Macros de uma sugestão: o planificador manda em `macros_totais`.
Map<String, num> macrosDaSugestao(Map<String, dynamic> s) {
  final m = (s['macros_totais'] as Map?) ?? s;
  num v(String k) => (m[k] as num?) ?? 0;
  return {
    'calorias_kcal': v('calorias_kcal'),
    'proteina_g': v('proteina_g'),
    'carboidrato_g': v('carboidrato_g'),
    'gordura_g': v('gordura_g'),
  };
}

/// Jantar com o que tem em casa: planificador cruza estoque, validade e o que
/// falta de macros no dia.
class SugestaoJantarScreen extends ConsumerStatefulWidget {
  const SugestaoJantarScreen({super.key, required this.membroId, required this.familiaId});
  final String membroId;
  final String familiaId;

  @override
  ConsumerState<SugestaoJantarScreen> createState() => _SugestaoJantarScreenState();
}

class _SugestaoJantarScreenState extends ConsumerState<SugestaoJantarScreen> {
  Map<String, dynamic>? _resultado;
  Object? _erro;
  bool _carregando = true;
  final List<String> _ausentes = [];

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  Future<void> _buscar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final r = await SaudeApiService.getSugestaoJantar(widget.familiaId, [widget.membroId], itensAusentes: _ausentes);
      if (mounted) setState(() => _resultado = r);
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _escolher(Map<String, dynamic> s) async {
    final hoje = DateTime.now().toIso8601String().substring(0, 10);
    final macros = macrosDaSugestao(s);
    try {
      await SaudeApiService.registrarRefeicao({
        'membro_id': widget.membroId,
        'familia_id': widget.familiaId,
        'tipo_refeicao': 'jantar',
        'offline_timestamp': hoje,
        'modalidade': 'manual',
        'dados_entrada': {'descricao': s['nome'] ?? 'Jantar sugerido', ...macros},
      });
      ref.invalidate(extratoDiarioProvider);
      ref.invalidate(refeicoesDiaProvider);
      ref.happy('Jantar registrado: ${macros['calorias_kcal']!.round()} kcal. Bom apetite!', mood: UnicornMood.celebrate);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sugestoes = ((_resultado?['sugestoes'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final suspeitos = ((_resultado?['itens_suspeitos'] as List?) ?? const []).cast<Map<String, dynamic>>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jantar de hoje'),
        actions: [
          IconButton(tooltip: 'Outras ideias', onPressed: _carregando ? null : _buscar, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _carregando
          ? const UnicornCarregando(texto: 'Olhando o que tem em casa…')
          : _erro != null
              ? UnicornErro(mensagem: 'Não consegui pensar no jantar agora.', onTentar: _buscar)
              : sugestoes.isEmpty
                  ? const UnicornVazio(
                      type: UnicornType.happy,
                      titulo: 'Sem estoque para sugerir',
                      texto: 'Escaneie a nota da última compra em Compras e eu monto jantares com o que tem em casa.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
                      children: [
                        Text('Com o que vocês têm em casa', style: NBText.legenda),
                        const SizedBox(height: NBSpacing.m),
                        if (suspeitos.isNotEmpty) ...[
                          CartaoNB(
                            cor: NBColors.ambarClaro,
                            borda: NBColors.ambarClaro,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ainda tem em casa?', style: NBText.rotulo.copyWith(color: NBColors.ambarTexto)),
                                const SizedBox(height: NBSpacing.s),
                                for (final item in suspeitos)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text('${item['nome']} · ${item['dias_na_geladeira'] ?? '?'} dias',
                                            style: NBText.corpo.copyWith(fontSize: 14)),
                                      ),
                                      TextButton(
                                        onPressed: () => setState(() => suspeitos.remove(item)),
                                        child: const Text('Tem'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          _ausentes.add(item['nome'] as String);
                                          _buscar();
                                        },
                                        child: const Text('Acabou', style: TextStyle(color: NBColors.estouro)),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: NBSpacing.l),
                        ],
                        _CartaoSugestao(s: sugestoes.first, destaque: true, onEscolher: () => _escolher(sugestoes.first)),
                        if (sugestoes.length > 1) ...[
                          const SizedBox(height: NBSpacing.xl),
                          Text('Outras ideias', style: NBText.secao),
                          const SizedBox(height: NBSpacing.s),
                          for (final s in sugestoes.skip(1))
                            Padding(
                              padding: const EdgeInsets.only(bottom: NBSpacing.m),
                              child: _CartaoSugestao(s: s, onEscolher: () => _escolher(s)),
                            ),
                        ],
                      ],
                    ),
    );
  }
}

class _CartaoSugestao extends StatelessWidget {
  const _CartaoSugestao({required this.s, required this.onEscolher, this.destaque = false});
  final Map<String, dynamic> s;
  final VoidCallback onEscolher;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final m = macrosDaSugestao(s);
    final ingredientes = ((s['ingredientes_usados'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final substituicoes = ((s['substituicoes'] as List?) ?? const []).cast<String>();
    final minutos = (s['preparo_minutos'] as num?)?.round();

    return CartaoNB(
      borda: destaque ? NBColors.verde : NBColors.linha,
      larguraBorda: destaque ? 1.5 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (destaque) Text('MELHOR OPÇÃO', style: NBText.eyebrow.copyWith(color: NBColors.verde)),
          Text(s['nome'] as String? ?? 'Sugestão', style: destaque ? NBText.secao : NBText.rotulo.copyWith(fontSize: 15)),
          const SizedBox(height: NBSpacing.s),
          Wrap(
            spacing: NBSpacing.s,
            runSpacing: 4,
            children: [
              SeloNB('${m['calorias_kcal']!.round()} kcal', cor: NBColors.verde, fundo: NBColors.verdeClaro),
              SeloNB('Proteína ${m['proteina_g']!.round()} g'),
              if (minutos != null && minutos > 0) SeloNB('$minutos min'),
            ],
          ),
          if (ingredientes.isNotEmpty) ...[
            const SizedBox(height: NBSpacing.s),
            Text(ingredientes.map((i) => i['nome']).join(' · '), style: NBText.legenda),
          ],
          if (substituicoes.isNotEmpty)
            Text(substituicoes.join(' · '), style: NBText.legenda.copyWith(color: NBColors.ambarTexto)),
          if (destaque && s['modo_preparo_resumido'] != null) ...[
            const SizedBox(height: NBSpacing.s),
            Text(s['modo_preparo_resumido'] as String, style: NBText.corpo.copyWith(fontSize: 14)),
          ],
          const SizedBox(height: NBSpacing.m),
          destaque
              ? FilledButton(onPressed: onEscolher, child: const Text('Escolher este jantar'))
              : Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: onEscolher,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    child: const Text('Escolher'),
                  ),
                ),
        ],
      ),
    );
  }
}
