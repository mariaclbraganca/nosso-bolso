import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../retrospectiva/retrospectiva_screen.dart';
import '../sheets/sheet_fechar_mes.dart';
import '../../core/providers/mes_provider.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import 'contas_tab.dart';
import 'metas_tab.dart';
import 'plano_mes_tab.dart';
import '../sheets/sheet_planejar_mes.dart';

enum AbaPlanos { orcamento, mes, contas, metas }

class PlanosScreen extends ConsumerStatefulWidget {
  const PlanosScreen({super.key});

  @override
  ConsumerState<PlanosScreen> createState() => _PlanosScreenState();
}

class _PlanosScreenState extends ConsumerState<PlanosScreen> {
  AbaPlanos _aba = AbaPlanos.orcamento;

  Future<void> _escolherMes(BuildContext context, String mesAtual) async {
    final meses = gerarMesesDisponiveis();
    final escolhido = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const TopoSheet(titulo: 'Escolha o mês'),
            const SizedBox(height: 12),
            for (final m in meses)
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
  Widget build(BuildContext context) {
    final mes = ref.watch(mesAtualProvider);
    final abasMap = <AbaPlanos, String>{
      AbaPlanos.orcamento: 'Orçamento',
      AbaPlanos.mes: 'Resumo',
      AbaPlanos.contas: 'Contas',
      AbaPlanos.metas: 'Metas',
    };

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _escolherMes(context, mes),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(mesLabelLongo(mes), style: NBText.secao),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            ],
          ),
        ),
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
                AbaPlanos.contas => const ContasTab(),
                AbaPlanos.metas => const MetasTab(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
