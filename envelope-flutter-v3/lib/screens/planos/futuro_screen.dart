import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/plano_provider.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';
import '../config/simulador_gastos_screen.dart';
import 'plano_mes_tab.dart';
import 'widgets/plano_sheets.dart';

enum _AbaFuturo { meses, parcelas, simulacoes }

/// Futuro: o que os próximos meses já têm comprometido, as parcelas e quando
/// terminam, e as simulações "e se".
class FuturoScreen extends ConsumerStatefulWidget {
  const FuturoScreen({super.key});

  @override
  ConsumerState<FuturoScreen> createState() => _FuturoScreenState();
}

class _FuturoScreenState extends ConsumerState<FuturoScreen> {
  var _aba = _AbaFuturo.meses;

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(limiteMesProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Futuro')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: NBSpacing.margemTela, vertical: 8),
          child: Segmentado<_AbaFuturo>(
            opcoes: const {_AbaFuturo.meses: 'Próximos meses', _AbaFuturo.parcelas: 'Parcelas', _AbaFuturo.simulacoes: 'Simulações'},
            valor: _aba,
            onChanged: (a) => setState(() => _aba = a),
          ),
        ),
        Expanded(
          child: switch (_aba) {
            _AbaFuturo.meses => l == null
                ? const UnicornCarregando()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 4, NBSpacing.margemTela, NBSpacing.x4),
                    children: [ProximosMeses(limite: l)],
                  ),
            _AbaFuturo.parcelas => const ListaCompromissos(),
            _AbaFuturo.simulacoes => ListView(
                padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 4, NBSpacing.margemTela, NBSpacing.x4),
                children: [
                  CartaoNB(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SimuladorGastosScreen())),
                    child: Row(children: [
                      const Icon(Icons.calculate_outlined, color: NBColors.verde),
                      const SizedBox(width: NBSpacing.m),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Simular um cenário', style: NBText.rotulo),
                          Text('Mudar de apartamento, trocar de carro… quanto muda por mês', style: NBText.legenda),
                        ]),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: NBColors.tintaSuave),
                    ]),
                  ),
                ],
              ),
          },
        ),
      ]),
    );
  }
}
