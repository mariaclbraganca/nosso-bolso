import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/jejum_provider.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';

/// Rótulo gentil para o status do registro: interrupção é "dia de descanso".
String rotuloStatusJejum(String? status) => switch (status) {
      'completo' => 'Concluído',
      'em_andamento' => 'Em andamento',
      'joker' => 'Folga',
      _ => 'Dia de descanso',
    };

class JejumHistoricoView extends ConsumerWidget {
  const JejumHistoricoView({super.key, required this.membroId});
  final String membroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(jejumHistoricoProvider(membroId)).when(
          loading: () => const UnicornCarregando(type: UnicornType.happy, texto: 'Lembrando seus jejuns…'),
          error: (e, _) => UnicornErro(
            mensagem: 'Não consegui carregar o histórico.',
            onTentar: () => ref.invalidate(jejumHistoricoProvider(membroId)),
          ),
          data: (d) {
            final registros = ((d['registros'] as List?) ?? const []).cast<Map<String, dynamic>>();
            final stats = (d['stats'] as Map?) ?? const {};
            if (registros.isEmpty) {
              return const UnicornVazio(
                type: UnicornType.sweet,
                titulo: 'Seu primeiro jejum vai aparecer aqui',
                texto: 'Cada jejum, completo ou não, conta como cuidado com você.',
              );
            }
            final mediaMin = (stats['duracao_media_min'] as num?)?.toInt() ?? 0;
            return ListView(
              padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
              children: [
                Row(
                  children: [
                    Expanded(child: _Numero('${stats['completos'] ?? 0}', 'concluídos')),
                    const SizedBox(width: NBSpacing.s),
                    Expanded(child: _Numero('${stats['taxa_sucesso'] ?? 0}%', 'chegaram na meta')),
                    const SizedBox(width: NBSpacing.s),
                    Expanded(child: _Numero('${mediaMin ~/ 60}h${(mediaMin % 60).toString().padLeft(2, '0')}', 'duração média')),
                  ],
                ),
                const SizedBox(height: NBSpacing.l),
                _Semana(registros: registros),
                const SizedBox(height: NBSpacing.l),
                Text('Registros', style: NBText.secao),
                const SizedBox(height: NBSpacing.s),
                for (final r in registros) _LinhaRegistro(r: r),
              ],
            );
          },
        );
  }
}

class _Numero extends StatelessWidget {
  const _Numero(this.valor, this.rotulo);
  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) => CartaoNB(
        padding: const EdgeInsets.symmetric(vertical: NBSpacing.m, horizontal: NBSpacing.s),
        child: Column(
          children: [
            Text(valor, style: NBText.valorCartao.copyWith(color: NBColors.lavanda)),
            Text(rotulo, style: NBText.legenda, textAlign: TextAlign.center),
          ],
        ),
      );
}

/// Últimos 7 dias: barra com as horas jejuadas e a linha da meta.
class _Semana extends StatelessWidget {
  const _Semana({required this.registros});
  final List<Map<String, dynamic>> registros;

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final dias = [for (var i = 6; i >= 0; i--) DateTime(hoje.year, hoje.month, hoje.day - i)];
    double horasNoDia(DateTime d) {
      var total = 0.0;
      for (final r in registros) {
        final ini = DateTime.tryParse(r['iniciado_em']?.toString() ?? '')?.toLocal();
        if (ini != null && ini.year == d.year && ini.month == d.month && ini.day == d.day) {
          total += ((r['duracao_real_min'] as num?) ?? 0) / 60;
        }
      }
      return total;
    }

    final meta = registros
            .map((r) => (r['meta_horas'] as num?)?.toDouble())
            .firstWhere((m) => m != null, orElse: () => 16) ??
        16;
    final horas = dias.map(horasNoDia).toList();
    final atingidos = horas.where((h) => h >= meta).length;
    final teto = [meta, ...horas].reduce((a, b) => a > b ? a : b);

    return CartaoNB(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Esta semana', style: NBText.rotulo)),
              Text('meta ${meta.round()}h · $atingidos de 7', style: NBText.legenda),
            ],
          ),
          const SizedBox(height: NBSpacing.m),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: 80 * (horas[i] / teto).clamp(0.02, 1.0),
                            decoration: BoxDecoration(
                              color: horas[i] >= meta ? NBColors.lavanda : NBColors.lavandaClara,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(DateFormat('E', 'pt_BR').format(dias[i]).substring(0, 3), style: NBText.legenda.copyWith(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaRegistro extends StatelessWidget {
  const _LinhaRegistro({required this.r});
  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context) {
    final ini = DateTime.tryParse(r['iniciado_em']?.toString() ?? '')?.toLocal();
    final min = (r['duracao_real_min'] as num?)?.toInt() ?? 0;
    final status = r['status'] as String?;
    final completo = status == 'completo';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NBSpacing.s),
      child: Row(
        children: [
          Icon(completo ? Icons.check_circle_rounded : Icons.spa_outlined,
              color: completo ? NBColors.lavanda : NBColors.tintaSuave, size: 20),
          const SizedBox(width: NBSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ini == null ? '—' : DateFormat("EEEE, d 'de' MMM", 'pt_BR').format(ini),
                    style: NBText.corpo.copyWith(fontWeight: FontWeight.w700)),
                Text(rotuloStatusJejum(status), style: NBText.legenda),
              ],
            ),
          ),
          Text('${min ~/ 60}h${(min % 60).toString().padLeft(2, '0')}', style: NBText.corpo.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
