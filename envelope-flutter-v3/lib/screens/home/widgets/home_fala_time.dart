import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/plano/falas.dart';
import '../../../core/providers/compras_provider.dart';
import '../../../core/providers/fixos_provider.dart';
import '../../../core/providers/plano_provider.dart';
import '../../../core/services/app_navigator.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';
import '../../lancar/lancar.dart';
import '../../../ui/components/nb_components.dart';
import '../../sheets/sheet_remanejar.dart';

/// Uma fala do time no Início, escolhida pelo contexto (regras em falas.dart).
/// Sem nada útil a dizer, ninguém fala.
class HomeFalaDoTime extends ConsumerWidget {
  const HomeFalaDoTime({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(limiteMesProvider).valueOrNull;
    if (l == null) return const SizedBox.shrink();
    final fala = falaDoInicio(
      l: l,
      contas: ref.watch(fixosMesAtualProvider),
      pendentes: ref.watch(comprasPendentesProvider).valueOrNull?.length ?? 0,
      hoje: DateTime.now(),
    );
    if (fala == null) return const SizedBox.shrink();
    return FalaDoTime(fala: fala, onTap: () => executarAcaoFala(context, fala.acao));
  }
}

/// O que tocar na fala faz.
void executarAcaoFala(BuildContext context, AcaoFala acao) => switch (acao) {
      AcaoFala.transferir => abrirSheet(context, const SheetRemanejar()),
      AcaoFala.confirmarCompras => abrirNovoLancamento(context),
      AcaoFala.contas => navegarParaAba(navContas),
      AcaoFala.nenhuma => null,
    };

/// Unicórnio + balão com a fala.
class FalaDoTime extends StatelessWidget {
  const FalaDoTime({super.key, required this.fala, this.onTap, this.tamanho = 72});
  final Fala fala;
  final VoidCallback? onTap;
  final double tamanho;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: NBSpacing.m),
        child: GestureDetector(
          onTap: fala.acao == AcaoFala.nenhuma ? null : onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              UnicornWidget(key: ValueKey(fala.quem), type: fala.quem, mood: fala.humor, size: tamanho),
              const SizedBox(width: NBSpacing.s),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: tamanho * 0.4),
                  child: UnicornFala(type: fala.quem, texto: fala.texto, maxWidth: double.infinity),
                ),
              ),
            ],
          ),
        ),
      );
}

/// Fala compacta (unicórnio pequeno + balão), dentro de um cartão.
class FalaCurta extends StatelessWidget {
  const FalaCurta({super.key, required this.fala});
  final Fala fala;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          UnicornWidget(key: ValueKey(fala.quem), type: fala.quem, size: 40, mood: fala.humor),
          const SizedBox(width: 8),
          Expanded(child: UnicornFala(type: fala.quem, texto: fala.texto)),
        ],
      );
}
