import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/compras_provider.dart';
import '../../../core/providers/mes_provider.dart';
import '../../../core/providers/usuarios_provider.dart';
import '../../../core/services/app_navigator.dart';
import '../../config/config_screen.dart';
import '../../../ui/theme/nb_theme.dart';

class HomeCabecalho extends ConsumerWidget {
  const HomeCabecalho({super.key});

  static const _cores = [
    NBColors.verde,
    NBColors.ambar,
    NBColors.reserva,
    NBColors.lavanda,
  ];

  static String _iniciais(List<Map<String, dynamic>> membros, int i) {
    String nome(int k) => ((membros[k]['nome'] as String?) ?? '?').trim();
    final n = nome(i);
    if (n.isEmpty) return '?';
    final repetida = [for (var k = 0; k < i; k++) nome(k)].any(
      (o) => o.isNotEmpty && o[0].toUpperCase() == n[0].toUpperCase(),
    );
    return repetida && n.length > 1
        ? '${n[0].toUpperCase()}${n[1].toLowerCase()}'
        : n[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membros = ref.watch(listaUsuariosProvider).valueOrNull ?? [];
    final pendentes = ref.watch(comprasPendentesProvider).valueOrNull?.length ?? 0;
    final mes = mesLabelLongo(ref.watch(mesAtualProvider));

    // Título curto: não quebra mesmo com a fonte do celular aumentada.
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('Início', style: NBText.tituloTela.copyWith(fontSize: 24)),
              ),
              Text(
                mes,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NBText.legenda.copyWith(color: NBColors.tintaSuave),
              ),
            ],
          ),
        ),
        if (membros.length > 1)
          Semantics(
            label: '${membros.length} membros na família',
            child: SizedBox(
              width: 30 + (membros.take(4).length - 1) * 22.0,
              height: 30,
              child: Stack(
                children: [
                  for (var i = 0; i < membros.take(4).length; i++)
                    Positioned(
                      left: i * 22.0,
                      child: _Avatar(
                        iniciais: _iniciais(membros, i),
                        cor: _cores[i % _cores.length],
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(width: 10),
        Badge(
          isLabelVisible: pendentes > 0,
          backgroundColor: NBColors.estouro,
          smallSize: 9,
          child: IconButton.outlined(
            tooltip: pendentes > 0
                ? '$pendentes lançamentos para revisar'
                : 'Lançados automaticamente',
            style: IconButton.styleFrom(
              backgroundColor: NBColors.cartao,
              side: const BorderSide(color: NBColors.linha),
              fixedSize: const Size(44, 44),
            ),
            onPressed: () => abrirDestino(Destino.compras),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: NBColors.tinta,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'Configurações',
          style: IconButton.styleFrom(
            backgroundColor: NBColors.cartao,
            side: const BorderSide(color: NBColors.linha),
            fixedSize: const Size(44, 44),
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ConfigScreen()),
          ),
          icon: const Icon(Icons.settings_outlined, color: NBColors.tinta, size: 20),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.iniciais, required this.cor});
  final String iniciais;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final escuro = cor != NBColors.ambar;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cor,
        shape: BoxShape.circle,
        border: Border.all(color: NBColors.papel, width: 2),
      ),
      child: Text(
        iniciais,
        style: NBText.rotulo.copyWith(
          fontSize: 12,
          color: escuro ? Colors.white : NBColors.tinta,
        ),
      ),
    );
  }
}
