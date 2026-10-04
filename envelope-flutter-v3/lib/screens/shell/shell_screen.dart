import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/compras_provider.dart';
import '../../core/services/app_navigator.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../compras/compras_screen.dart';
import '../config/config_screen.dart';
import '../extrato/extrato_screen.dart';
import '../home/home_screen.dart';
import '../lancar/lancar.dart';
import '../minha_vida/minha_vida_screen.dart';
import '../planos/planos_screen.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _aba = navHome;

  @override
  void initState() {
    super.initState();
    registerNavCallback((i) {
      if (mounted) setState(() => _aba = i);
    });
  }

  @override
  void dispose() {
    unregisterNavCallback();
    super.dispose();
  }

  Future<void> _abrirMais(int pendentes) async {
    final escolha = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 4), child: TopoSheet(titulo: 'Mais')),
            ListTile(
              leading: Badge(
                isLabelVisible: pendentes > 0,
                backgroundColor: NBColors.estouro,
                label: Text('$pendentes'),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
              title: const Text('Compras'),
              subtitle: const Text('Notas fiscais, compras a confirmar e lista de compras'),
              onTap: () => Navigator.pop(ctx, navCompras),
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border_rounded),
              title: const Text('Minha Vida'),
              subtitle: const Text('Alimentação, exercício e jejum'),
              onTap: () => Navigator.pop(ctx, navVida),
            ),
            ListTile(
              leading: const Icon(Icons.savings_outlined),
              title: const Text('Patrimônio e reserva'),
              onTap: () => Navigator.pop(ctx, -1),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Configurações'),
              onTap: () => Navigator.pop(ctx, -2),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (escolha == null || !mounted) return;
    if (escolha >= 0) return setState(() => _aba = escolha);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => escolha == -1 ? const PatrimonioScreen() : const ConfigScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pendentes = ref.watch(comprasPendentesProvider).valueOrNull?.length ?? 0;
    final noMais = _aba == navCompras || _aba == navVida;

    return Scaffold(
      body: IndexedStack(
        index: _aba,
        children: const [
          HomeScreen(),
          PlanosScreen(),
          ExtratoScreen(),
          ComprasScreen(),
          MinhaVidaScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: NBColors.cartao,
          border: Border(top: BorderSide(color: NBColors.linha)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _ItemBarra(
                  rotulo: 'Início',
                  icone: Icons.home_outlined,
                  iconeAtivo: Icons.home_rounded,
                  ativo: _aba == navHome,
                  onTap: () => setState(() => _aba = navHome),
                ),
                _ItemBarra(
                  rotulo: 'Orçamento',
                  icone: Icons.tune_rounded,
                  iconeAtivo: Icons.tune_rounded,
                  ativo: _aba == navPlanos,
                  onTap: () => setState(() => _aba = navPlanos),
                ),
                Expanded(child: _BotaoLancar(onTap: () => abrirNovoLancamento(context))),
                _ItemBarra(
                  rotulo: 'Extrato',
                  icone: Icons.format_list_bulleted_rounded,
                  iconeAtivo: Icons.format_list_bulleted_rounded,
                  ativo: _aba == navExtrato,
                  onTap: () => setState(() => _aba = navExtrato),
                ),
                _ItemBarra(
                  rotulo: 'Mais',
                  icone: Icons.menu_rounded,
                  iconeAtivo: Icons.menu_rounded,
                  ativo: noMais,
                  badge: pendentes,
                  onTap: () => _abrirMais(pendentes),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemBarra extends StatelessWidget {
  const _ItemBarra({
    required this.rotulo,
    required this.icone,
    required this.iconeAtivo,
    required this.ativo,
    required this.onTap,
    this.badge = 0,
  });
  final String rotulo;
  final IconData icone;
  final IconData iconeAtivo;
  final bool ativo;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final cor = ativo ? NBColors.verde : NBColors.tintaSuave;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badge > 0,
                backgroundColor: NBColors.estouro,
                label: Text('$badge'),
                child: Icon(ativo ? iconeAtivo : icone, color: cor),
              ),
              const SizedBox(height: 3),
              Text(rotulo, style: NBText.legenda.copyWith(fontSize: 12, color: cor, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "+" central da barra: abre o novo lançamento (compra ou receita).
class _BotaoLancar extends StatelessWidget {
  const _BotaoLancar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Novo lançamento',
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: NBColors.verde,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: NBColors.verde.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 2),
              Text('Lançar', style: NBText.legenda.copyWith(fontSize: 12, color: NBColors.verdeProfundo, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
            ],
          ),
        ),
      );
}
