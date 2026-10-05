import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/compras_provider.dart';
import '../../core/providers/dia_provider.dart';
import '../../core/services/app_navigator.dart';
import '../../core/services/notification_service.dart';
import '../../core/providers/envelopes_provider.dart';
import '../../core/providers/plano_provider.dart';
import '../../core/providers/insights_provider.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';
import '../shell/barra_modulo.dart';
import '../sheets/sheet_envelope.dart';
import '../sheets/sheet_remanejar.dart';
import 'widgets/home_aviso_captura.dart';
import 'widgets/home_cabecalho.dart';
import 'widgets/home_cartao_saldo.dart';
import 'widgets/home_fala_time.dart';
import 'widgets/home_jejum_chip.dart';
import 'widgets/home_grade_envelopes.dart';
import 'widgets/home_ritual_alarme.dart';

/// Envelopes que acabaram de ficar negativos (ainda não avisados nesta sessão).
/// Atualiza [avisados]: quem voltou ao positivo sai, para avisar de novo depois.
List<Map<String, dynamic>> novosNegativos(Set<String> avisados, List<Map<String, dynamic>> envelopes) {
  final novos = <Map<String, dynamic>>[];
  for (final env in envelopes) {
    final id = env['id'] as String?;
    if (id == null) continue;
    if (((env['saldo_atual'] as num?) ?? 0) < 0) {
      if (avisados.add(id)) novos.add(env);
    } else {
      avisados.remove(id);
    }
  }
  return novos;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _negativosAvisados = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) prepararAlarmeFechamento(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Envelope ficou negativo: aviso local (respeita a chave notif_envelope_negativo).
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(envelopesProvider, (_, next) {
      final envelopes = next.valueOrNull;
      if (envelopes == null) return;
      for (final env in novosNegativos(_negativosAvisados, envelopes)) {
        NotificationService.notificarEnvelopeNegativo(
          envelopeId: env['id'] as String,
          nomeEnvelope: env['nome_envelope'] as String? ?? 'Envelope',
          saldoAtual: (env['saldo_atual'] as num).toDouble(),
        );
      }
    });

    // Alguém da família já fechou hoje: não toca o alarme de hoje neste celular.
    ref.listen<AsyncValue<Map<String, dynamic>>>(resumoDiaProvider, (_, next) {
      if (next.valueOrNull?['fechado'] == true) {
        NotificationService.agendarAlarmeFechamento(hojeFechado: true);
      }
    });

    final envelopesAsync = ref.watch(envelopesProvider);
    // O vale-alimentação tem card próprio logo abaixo do disponível.
    // Só os ativos (com valor planejado), do maior para o menor; reservas e VA
    // ficam no Orçamento.
    final envelopes = ref
        .watch(envelopesViseisProvider)
        .where((e) => !ehEnvelopeVa(e) && !ehReserva(e) && ((e['valor_planejado'] as num?) ?? 0) > 0)
        .toList()
      ..sort((a, b) => ((b['valor_planejado'] as num?) ?? 0).compareTo((a['valor_planejado'] as num?) ?? 0));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: NBColors.verde,
          onRefresh: () async {
            ref.invalidate(envelopesProvider);
            ref.invalidate(comprasPendentesProvider);
            ref.invalidate(compromissosCartaoProvider);
            ref.invalidate(entradasMesProvider);
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
              Align(
                alignment: Alignment.centerLeft,
                child: VoltarModulos(onTap: () => abrirDestino(Destino.modulos)),
              ),
              const HomeCabecalho(),
              const SizedBox(height: NBSpacing.l),
              const HomeCartaoSaldo(),
              const SizedBox(height: NBSpacing.l),
              const HomeJejumChip(),
              const HomeAvisoCaptura(),
              const HomeFalaDoTime(),
              const SizedBox(height: NBSpacing.l),
              Row(
                children: [
                  Expanded(child: Text('Envelopes', style: NBText.secao)),
                  TextButton.icon(
                    onPressed: () => abrirSheet(context, const SheetRemanejar()),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('Transferir'),
                  ),
                ],
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
                  texto: 'Crie o primeiro e comece a separar o dinheiro da família.',
                  acao: () => abrirEnvelope(context),
                  rotuloAcao: 'Criar envelope',
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
