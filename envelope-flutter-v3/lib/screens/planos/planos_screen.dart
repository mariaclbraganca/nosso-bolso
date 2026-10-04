import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../retrospectiva/retrospectiva_screen.dart';
import '../sheets/sheet_fechar_mes.dart';
import '../../core/providers/mes_provider.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import 'metas_tab.dart';
import 'plano_mes_tab.dart';
import '../sheets/sheet_planejar_mes.dart';

enum AbaPlanos { orcamento, mes, metas }

class PlanosScreen extends ConsumerStatefulWidget {
  const PlanosScreen({super.key});

  @override
  ConsumerState<PlanosScreen> createState() => _PlanosScreenState();
}

class _PlanosScreenState extends ConsumerState<PlanosScreen> {
  AbaPlanos _aba = AbaPlanos.orcamento;

  @override
  Widget build(BuildContext context) {
    final abasMap = <AbaPlanos, String>{
      AbaPlanos.orcamento: 'Orçamento',
      AbaPlanos.mes: 'Resumo',
      AbaPlanos.metas: 'Metas',
    };

    return Scaffold(
      appBar: AppBar(
        title: const TituloMes(),
        actions: [
          IconButton(
            tooltip: 'Retrospectiva',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RetrospectivaScreen()),
            ),
          ),
          TextButton(
            onPressed: () => abrirSheet(context, const SheetFecharMes()),
            child: const Text('Fechar mês'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: NBSpacing.margemTela, vertical: 8),
              child: Segmentado<AbaPlanos>(
                opcoes: abasMap,
                valor: _aba,
                onChanged: (a) => setState(() => _aba = a),
              ),
            ),
            Expanded(
              child: switch (_aba) {
                AbaPlanos.orcamento => const OrcamentoMensal(),
                AbaPlanos.mes => const PlanoMesTab(),
                AbaPlanos.metas => const MetasTab(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Título "Outubro 2026 ▾" que troca o mês de referência do app.
class TituloMes extends ConsumerWidget {
  const TituloMes({super.key});

  Future<void> _escolher(BuildContext context, WidgetRef ref, String mesAtual) async {
    final escolhido = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const TopoSheet(titulo: 'Escolha o mês'),
            const SizedBox(height: 12),
            for (final m in gerarMesesDisponiveis())
              ListTile(
                title: Text(mesLabelLongo(m), style: NBText.corpo),
                selected: m == mesAtual,
                selectedColor: NBColors.verde,
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (escolhido != null) ref.read(mesAtualProvider.notifier).state = escolhido;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesAtualProvider);
    return GestureDetector(
      onTap: () => _escolher(context, ref, mes),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(mesLabelLongo(mes), style: NBText.secao))),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        ],
      ),
    );
  }
}
