import 'package:flutter/material.dart';
import '../../ui/theme/nb_theme.dart';

/// Item da barra inferior de um módulo.
typedef ItemBarra = ({String rotulo, IconData icone, IconData iconeAtivo, int badge});

ItemBarra itemBarra(String rotulo, IconData icone, [IconData? ativo, int badge = 0]) =>
    (rotulo: rotulo, icone: icone, iconeAtivo: ativo ?? icone, badge: badge);

/// Barra inferior comum aos módulos: itens à esquerda e à direita do "+"
/// central. [ativo] é o índice do item aceso (−1 = nenhum).
class BarraModulo extends StatelessWidget {
  const BarraModulo({
    super.key,
    required this.itens,
    required this.ativo,
    required this.onItem,
    required this.onLancar,
    this.cor = NBColors.verde,
  });
  final List<ItemBarra> itens;
  final int ativo;
  final ValueChanged<int> onItem;
  final VoidCallback onLancar;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final meio = (itens.length + 1) ~/ 2;
    Widget item(int i) => _ItemBarra(item: itens[i], ativo: ativo == i, cor: cor, onTap: () => onItem(i));
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: NBColors.cartao,
        border: Border(top: BorderSide(color: NBColors.linha)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < meio; i++) item(i),
              Expanded(child: _BotaoLancar(onTap: onLancar, cor: cor)),
              for (var i = meio; i < itens.length; i++) item(i),
              if (itens.length.isOdd) const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemBarra extends StatelessWidget {
  const _ItemBarra({required this.item, required this.ativo, required this.cor, required this.onTap});
  final ItemBarra item;
  final bool ativo;
  final Color cor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ativo ? cor : NBColors.tintaSuave;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: item.badge > 0,
                backgroundColor: NBColors.estouro,
                label: Text('${item.badge}'),
                child: Icon(ativo ? item.iconeAtivo : item.icone, color: c),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(item.rotulo, style: NBText.legenda.copyWith(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "+" central da barra: abre o lançamento do módulo.
class _BotaoLancar extends StatelessWidget {
  const _BotaoLancar({required this.onTap, required this.cor});
  final VoidCallback onTap;
  final Color cor;

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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: cor.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 2),
              Text('Lançar', style: NBText.legenda.copyWith(fontSize: 12, color: cor, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
            ],
          ),
        ),
      );
}

/// "‹ Módulos": volta para a escolha do módulo.
class VoltarModulos extends StatelessWidget {
  const VoltarModulos({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), visualDensity: VisualDensity.compact),
        icon: const Icon(Icons.chevron_left_rounded, size: 20),
        label: const Text('Módulos'),
      );
}
