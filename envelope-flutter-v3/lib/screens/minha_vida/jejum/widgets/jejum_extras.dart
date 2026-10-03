import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nosso_bolso_v3/core/providers/jejum_provider.dart';
import 'package:nosso_bolso_v3/core/services/jejum_api_service.dart';
import 'package:nosso_bolso_v3/screens/sheets/comum.dart';
import 'package:nosso_bolso_v3/ui/components/nb_components.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';
import 'package:nosso_bolso_v3/ui/unicorn/unicorn.dart';

/// Texto "faltam Xh Ymin para <fase>" ou null na última fase.
String? textoProximaFase(Duration decorrido) {
  final prox = FaseMetabolica.proxima(decorrido);
  if (prox == null) return null;
  final falta = Duration(minutes: (prox.inicioHoras * 60).round()) - decorrido;
  final h = falta.inHours;
  final m = falta.inMinutes % 60;
  return 'Faltam ${h > 0 ? '${h}h ' : ''}${m}min para ${prox.emoji} ${prox.nome}';
}

/// Linha do tempo das fases metabólicas, marcando a atual.
class JejumFasesSheet extends StatelessWidget {
  const JejumFasesSheet({super.key, required this.decorrido});
  final Duration decorrido;

  @override
  Widget build(BuildContext context) {
    final atual = FaseMetabolica.atual(decorrido);
    return CascaSheet(
      filhos: [
        const TopoSheet(titulo: 'Fases do jejum', subtitulo: 'O que acontece no corpo ao longo das horas.'),
        const SizedBox(height: NBSpacing.l),
        for (final f in FaseMetabolica.fases)
          Padding(
            padding: const EdgeInsets.only(bottom: NBSpacing.s),
            child: Container(
              padding: const EdgeInsets.all(NBSpacing.m),
              decoration: BoxDecoration(
                color: f == atual ? NBColors.lavandaClara : null,
                borderRadius: BorderRadius.circular(NBRadius.cartao),
                border: Border.all(color: f == atual ? NBColors.lavanda : NBColors.linha),
              ),
              child: Row(
                children: [
                  Text(f.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: NBSpacing.m),
                  Expanded(child: Text(f.nome, style: NBText.rotulo)),
                  Text('${f.inicioHoras.round()}h+', style: NBText.legenda),
                  if (f == atual) ...[
                    const SizedBox(width: NBSpacing.s),
                    const SeloNB('agora', cor: NBColors.lavanda, fundo: NBColors.papel),
                  ],
                ],
              ),
            ),
          ),
      ],
      botao: BotaoPrincipal(rotulo: 'Entendi', onPressed: () => Navigator.pop(context)),
    );
  }
}

/// Corrige o início de um jejum em andamento (esqueceu de apertar na hora).
Future<void> ajustarInicioJejum(BuildContext context, WidgetRef ref, Map<String, dynamic> ativo, String membroId) async {
  final inicio = DateTime.tryParse(ativo['iniciado_em']?.toString() ?? '')?.toLocal() ?? DateTime.now();
  final hora = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(inicio),
    helpText: 'Quando você começou?',
  );
  if (hora == null) return;
  final agora = DateTime.now();
  var novo = DateTime(agora.year, agora.month, agora.day, hora.hour, hora.minute);
  if (novo.isAfter(agora)) novo = novo.subtract(const Duration(days: 1)); // começou ontem
  try {
    await JejumApiService.ajustarInicio(ativo['id'].toString(), novo);
    ref.invalidate(jejumAtivoProvider(membroId));
    avisar('Início ajustado.');
  } catch (e) {
    avisar(mensagemErro(e), erro: true);
  }
}

/// Primeiro uso: Happy sugere um protocolo e janela para começar.
class JejumOnboardingCard extends ConsumerWidget {
  const JejumOnboardingCard({super.key, required this.membroId, required this.onUsar});
  final String membroId;
  final ValueChanged<Map<String, dynamic>> onUsar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(jejumSugestaoProtocoloProvider(membroId)).valueOrNull;
    if (s == null) return const SizedBox.shrink();
    final proto = ProtocoloJejum.porId(s['protocolo'] as String? ?? '');
    return CartaoNB(
      borda: NBColors.lavanda,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const UnicornWidget(type: UnicornType.happy, size: 44, mood: UnicornMood.focus),
              const SizedBox(width: NBSpacing.s),
              Expanded(child: Text('Para começar, que tal o ${proto?.label ?? s['protocolo']}?', style: NBText.rotulo)),
            ],
          ),
          const SizedBox(height: NBSpacing.s),
          Text(s['justificativa'] as String? ?? '', style: NBText.corpo.copyWith(fontSize: 14)),
          if (s['janela_inicio'] != null)
            Text('Janela para comer: ${s['janela_inicio']} às ${s['janela_fim']}', style: NBText.legenda),
          const SizedBox(height: NBSpacing.m),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () => onUsar(s),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              child: const Text('Usar esta sugestão'),
            ),
          ),
        ],
      ),
    );
  }
}
