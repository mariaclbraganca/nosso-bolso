import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/compras_provider.dart';
import '../../core/providers/envelopes_provider.dart';
import '../../core/providers/insights_provider.dart';
import '../../core/services/app_navigator.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';
import '../sheets/sheet_lancamento.dart';
import '../sheets/sheet_remanejar.dart';
import 'widgets/home_aviso_captura.dart';
import 'widgets/home_cabecalho.dart';
import 'widgets/home_cartao_saldo.dart';
import 'widgets/home_fala_time.dart';
import 'widgets/home_grade_envelopes.dart';
import 'widgets/home_ritual_alarme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) prepararAlarmeFechamento(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final envelopesAsync = ref.watch(envelopesProvider);
    final envelopes = ref.watch(envelopesViseisProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.large(
        heroTag: 'fab_home',
        tooltip: 'Novo lançamento',
        onPressed: () => abrirLancamento(context),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: NBColors.verde,
          onRefresh: () async {
            ref.invalidate(envelopesProvider);
            ref.invalidate(comprasPendentesProvider);
            ref.invalidate(insightsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              NBSpacing.margemTela,
              NBSpacing.s,
              NBSpacing.margemTela,
              120,
            ),
            children: [
              const HomeCabecalho(),
              const SizedBox(height: NBSpacing.l),
              const HomeCartaoSaldo(),
              const SizedBox(height: NBSpacing.l),
              const HomeAvisoCaptura(),
              HomeFalaDoTime(envelopes: envelopes),
              const HomeAlertaIA(),
              const SizedBox(height: NBSpacing.l),
              CabecalhoSecao(
                titulo: 'Envelopes',
                acao: 'Remanejar',
                iconeAcao: Icons.swap_horiz_rounded,
                onAcao: () => abrirSheet(context, const SheetRemanejar()),
              ),
              const SizedBox(height: NBSpacing.s),
              if (envelopesAsync.isLoading && envelopes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(NBSpacing.x3),
                  child: UnicornCarregando(texto: 'Contando os envelopes…'),
                )
              else if (envelopes.isEmpty)
                UnicornVazio(
                  titulo: 'Nenhum envelope ainda',
                  texto: 'Crie o primeiro em Planos e comece a separar o dinheiro.',
                  acao: () => navegarParaAba(navPlanos),
                  rotuloAcao: 'Ir para Planos',
                )
              else
                HomeGradeEnvelopes(envelopes: envelopes),
            ],
          ),
        ),
      ),
    );
  }
}
