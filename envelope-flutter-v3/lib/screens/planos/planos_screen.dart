import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../retrospectiva/retrospectiva_screen.dart';
import '../sheets/sheet_fechar_mes.dart';
import '../../core/providers/mes_provider.dart';
import '../../core/providers/usuarios_provider.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import 'contas_tab.dart';
import 'fixos_tab.dart';
import 'metas_tab.dart';
import 'patrimonio_tab.dart';
import 'plano_mes_tab.dart';

enum AbaPlanos { mes, fixos, boletos, metas, patrimonio }

class PlanosScreen extends ConsumerStatefulWidget {
  const PlanosScreen({super.key});

  @override
  ConsumerState<PlanosScreen> createState() => _PlanosScreenState();
}

class _PlanosScreenState extends ConsumerState<PlanosScreen> {
  AbaPlanos _aba = AbaPlanos.mes;

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
    final perfil = ref.watch(perfilUsuarioLogadoProvider).valueOrNull;
    final isAdmin = perfil?['role'] == 'admin' || perfil?['is_admin'] == true;

    final abasMap = <AbaPlanos, String>{
      AbaPlanos.mes: '📊 Mês',
      AbaPlanos.fixos: '📌 Fixos',
      AbaPlanos.boletos: '🧾 Boletos',
      AbaPlanos.metas: '🎯 Metas',
      if (isAdmin) AbaPlanos.patrimonio: '💰 Patrimônio',
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
                AbaPlanos.mes => const PlanoMesTab(),
                AbaPlanos.fixos => const FixosTab(),
                AbaPlanos.boletos => const ContasTab(),
                AbaPlanos.metas => const MetasTab(),
                AbaPlanos.patrimonio => const PatrimonioTab(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
