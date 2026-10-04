import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/exercicio_provider.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';

/// Meta da OMS: 150 min de atividade por semana.
const metaSemanalMin = 150;

String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Painel da semana + dias anteriores. Cada item do histórico é um dia:
/// {data, exercicios[], total_duracao_min, total_calorias_kcal}.
class ExercicioHistoricoView extends ConsumerWidget {
  const ExercicioHistoricoView({super.key, required this.membroId, this.mostrarSemana = true, this.mostrarHistorico = true});
  final String membroId;

  /// Mostra o resumo dos últimos 7 dias e/ou a lista de treinos por dia.
  final bool mostrarSemana;
  final bool mostrarHistorico;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(historicoExercicioProvider(membroId)).when(
          loading: () => const UnicornCarregando(type: UnicornType.happy, texto: 'Somando seus treinos…'),
          error: (e, _) => UnicornErro(
            mensagem: 'Não consegui carregar o histórico.',
            onTentar: () => ref.invalidate(historicoExercicioProvider(membroId)),
          ),
          data: (dias) {
            final comTreino = dias.where((d) => ((d['exercicios'] as List?) ?? const []).isNotEmpty).toList();
            if (comTreino.isEmpty) {
              return const UnicornVazio(
                type: UnicornType.happy,
                titulo: 'Nenhum treino ainda',
                texto: 'Registre a primeira atividade na aba Hoje. Qualquer movimento conta!',
              );
            }
            final porData = {for (final d in dias) d['data'] as String? ?? '': d};
            final hoje = DateTime.now();
            final semana = [for (var i = 6; i >= 0; i--) DateTime(hoje.year, hoje.month, hoje.day - i)];
            int min(DateTime d) => ((porData[_iso(d)]?['total_duracao_min'] as num?) ?? 0).round();
            int kcal(DateTime d) => ((porData[_iso(d)]?['total_calorias_kcal'] as num?) ?? 0).round();
            final minSemana = semana.fold<int>(0, (a, d) => a + min(d));
            final kcalSemana = semana.fold<int>(0, (a, d) => a + kcal(d));
            final diasAtivos = semana.where((d) => min(d) > 0).length;
            final teto = semana.map(min).fold<int>(30, (a, b) => b > a ? b : a);

            return ListView(
              padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
              children: [
                if (mostrarSemana)
                  CartaoNB(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Últimos 7 dias', style: NBText.rotulo),
                        const SizedBox(height: 4),
                        Text(
                            '$minSemana min · $kcalSemana kcal · $diasAtivos ${diasAtivos == 1 ? 'dia ativo' : 'dias ativos'}',
                            style: NBText.legenda),
                        const SizedBox(height: NBSpacing.s),
                        BarraProgresso(fracao: minSemana / metaSemanalMin, cor: NBColors.verde),
                        const SizedBox(height: 4),
                        Text(
                          minSemana >= metaSemanalMin
                              ? 'Meta de $metaSemanalMin min da semana alcançada! 🌟'
                              : 'Faltam ${metaSemanalMin - minSemana} min para os $metaSemanalMin da semana',
                          style: NBText.legenda
                              .copyWith(color: minSemana >= metaSemanalMin ? NBColors.verde : NBColors.tintaSuave),
                        ),
                        const SizedBox(height: NBSpacing.m),
                        SizedBox(
                          height: 100,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final d in semana)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (min(d) > 0) Text('${min(d)}', style: NBText.legenda.copyWith(fontSize: 10)),
                                        Container(
                                          height: 64 * (min(d) / teto).clamp(0.03, 1.0),
                                          decoration: BoxDecoration(
                                            color: min(d) > 0 ? NBColors.verde : NBColors.afundado,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(DateFormat('E', 'pt_BR').format(d).substring(0, 3),
                                            style: NBText.legenda.copyWith(fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (mostrarSemana && mostrarHistorico) const SizedBox(height: NBSpacing.l),
                if (mostrarHistorico)
                  for (final dia in comTreino) _Dia(dia: dia),
              ],
            );
          },
        );
  }
}

class _Dia extends StatelessWidget {
  const _Dia({required this.dia});
  final Map<String, dynamic> dia;

  @override
  Widget build(BuildContext context) {
    final data = DateTime.tryParse(dia['data'] as String? ?? '');
    final itens = ((dia['exercicios'] as List?) ?? const []).cast<Map<String, dynamic>>();
    return Padding(
      padding: const EdgeInsets.only(bottom: NBSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data == null ? '—' : DateFormat("EEEE, d 'de' MMM", 'pt_BR').format(data).toUpperCase(),
                  style: NBText.eyebrow,
                ),
              ),
              Text('${((dia['total_calorias_kcal'] as num?) ?? 0).round()} kcal', style: NBText.legenda),
            ],
          ),
          const SizedBox(height: NBSpacing.s),
          for (final ex in itens)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Text(categoriaEmoji[ex['categoria']] ?? '🏃', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: NBSpacing.s),
                  Expanded(
                      child: Text(ex['nome'] as String? ?? 'Exercício', style: NBText.corpo.copyWith(fontSize: 14))),
                  Text('${((ex['duracao_min'] as num?) ?? 0).round()} min', style: NBText.legenda),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Minutos de exercício nos últimos 7 dias (hoje incluso).
int minutosDaSemana(List<Map<String, dynamic>>? dias, [DateTime? agora]) {
  if (dias == null) return 0;
  final hoje = agora ?? DateTime.now();
  final semana = {for (var i = 0; i < 7; i++) _iso(DateTime(hoje.year, hoje.month, hoje.day - i))};
  return dias
      .where((d) => semana.contains(d['data']))
      .fold(0, (s, d) => s + ((d['total_duracao_min'] as num?) ?? 0).round());
}
