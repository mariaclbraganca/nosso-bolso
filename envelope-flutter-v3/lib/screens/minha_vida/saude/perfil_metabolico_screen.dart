import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/saude_provider.dart';
import '../../../core/services/saude_api_service.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';
import '../../sheets/comum.dart';

/// Valores aceitos pelo backend (agente_metabolico.py).
const objetivosSaude = {'perda_peso': 'Perder peso', 'manutencao': 'Manter o peso', 'ganho_massa': 'Ganhar massa'};
const niveisAtividade = {
  'sedentario': 'Quase não me exercito',
  'leve': '1 a 3 vezes por semana',
  'moderado': '3 a 5 vezes por semana',
  'intenso': '6 a 7 vezes por semana',
};

/// Monta o corpo do POST /perfil-metabolico no formato que o cálculo lê
/// (antropometria + metabolico). A v2 mandava os campos soltos e o perfil
/// era gravado vazio.
Map<String, dynamic> corpoPerfilMetabolico({
  required String membroId,
  required String sexo,
  required int idade,
  required double pesoKg,
  required double alturaCm,
  required String objetivo,
  required String nivelAtividade,
}) =>
    {
      'membro_id': membroId,
      'antropometria': {'sexo': sexo, 'idade': idade, 'peso_kg': pesoKg, 'altura_cm': alturaCm},
      'metabolico': {'objetivo': objetivo, 'nivel_atividade': nivelAtividade},
    };

class PerfilMetabolicoScreen extends ConsumerWidget {
  const PerfilMetabolicoScreen({super.key, required this.membroId});
  final String membroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilMetabolicoProvider(membroId));
    void editar(Map<String, dynamic>? atual) =>
        abrirSheet(context, FormPerfilMetabolico(membroId: membroId, atual: atual));

    return Scaffold(
      appBar: AppBar(title: const Text('Meu plano de alimentação')),
      body: perfil.when(
        loading: () => const UnicornCarregando(texto: 'Calculando seu plano…'),
        error: (e, _) => UnicornErro(
          mensagem: 'Não consegui carregar o perfil.',
          onTentar: () => ref.invalidate(perfilMetabolicoProvider(membroId)),
        ),
        data: (p) {
          if (p == null) {
            return UnicornVazio(
              type: UnicornType.happy,
              titulo: 'Vamos montar seu plano?',
              texto: 'Com idade, peso, altura e rotina eu calculo quantas calorias e proteínas você precisa por dia.',
              acao: () => editar(null),
              rotuloAcao: 'Montar meu plano',
            );
          }
          final m = (p['metabolico'] as Map?) ?? const {};
          final a = (p['antropometria'] as Map?) ?? const {};
          final macros = (m['metas_macros'] as Map?) ?? const {};
          String n(dynamic v, [String suf = '']) => v == null ? '—' : '${(v as num).round()}$suf';

          return ListView(
            padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
            children: [
              Container(
                padding: const EdgeInsets.all(NBSpacing.xl),
                decoration: BoxDecoration(color: NBColors.verde, borderRadius: BorderRadius.circular(NBRadius.destaque)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sua meta por dia', style: NBText.rotulo.copyWith(color: NBColors.verdeClaro)),
                    Text(n(m['meta_calorica_kcal'], ' kcal'), style: NBText.saldo.copyWith(color: Colors.white)),
                    Text(
                      '${objetivosSaude[m['objetivo']] ?? 'Manter o peso'} · gasto diário ${n(m['tdee_kcal'], ' kcal')}',
                      style: NBText.corpo.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NBSpacing.l),
              Text('Macronutrientes por dia', style: NBText.secao),
              const SizedBox(height: NBSpacing.s),
              CartaoNB(
                child: Column(
                  children: [
                    _Linha('Proteína', n(macros['proteina_total_g'], ' g')),
                    _Linha('Carboidrato', n(macros['carboidrato_g'], ' g')),
                    _Linha('Gordura', n(macros['gordura_g'], ' g')),
                    const Divider(height: 16),
                    _Linha('Água', n(m['meta_agua_ml'], ' ml')),
                    _Linha('Fibra', n(m['meta_fibra_g'], ' g')),
                    _Linha('Metabolismo em repouso (TMB)', n(m['tmb_kcal'], ' kcal')),
                  ],
                ),
              ),
              const SizedBox(height: NBSpacing.l),
              Text(
                'Base: ${n(a['peso_kg'], ' kg')}, ${n(a['altura_cm'], ' cm')}, ${n(a['idade'], ' anos')} · '
                '${niveisAtividade[m['nivel_atividade']] ?? ''}',
                style: NBText.legenda,
              ),
              const SizedBox(height: NBSpacing.l),
              OutlinedButton.icon(
                onPressed: () => editar(p),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Atualizar meus dados'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha(this.rotulo, this.valor);
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(rotulo, style: NBText.corpo.copyWith(color: NBColors.tintaSuave))),
            Text(valor, style: NBText.corpo.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class FormPerfilMetabolico extends ConsumerStatefulWidget {
  const FormPerfilMetabolico({super.key, required this.membroId, this.atual});
  final String membroId;
  final Map<String, dynamic>? atual;

  @override
  ConsumerState<FormPerfilMetabolico> createState() => _FormPerfilMetabolicoState();
}

class _FormPerfilMetabolicoState extends ConsumerState<FormPerfilMetabolico> {
  final _idade = TextEditingController();
  final _peso = TextEditingController();
  final _altura = TextEditingController();
  String _sexo = 'M';
  String _objetivo = 'manutencao';
  String _nivel = 'sedentario';
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final a = (widget.atual?['antropometria'] as Map?) ?? const {};
    final m = (widget.atual?['metabolico'] as Map?) ?? const {};
    _sexo = a['sexo'] as String? ?? 'M';
    _objetivo = objetivosSaude.containsKey(m['objetivo']) ? m['objetivo'] as String : 'manutencao';
    _nivel = niveisAtividade.containsKey(m['nivel_atividade']) ? m['nivel_atividade'] as String : 'sedentario';
    if (a['idade'] != null) _idade.text = '${a['idade']}';
    if (a['peso_kg'] != null) _peso.text = '${a['peso_kg']}';
    if (a['altura_cm'] != null) _altura.text = '${(a['altura_cm'] as num).round()}';
  }

  @override
  void dispose() {
    _idade.dispose();
    _peso.dispose();
    _altura.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final idade = int.tryParse(_idade.text);
    final peso = double.tryParse(_peso.text.replaceAll(',', '.'));
    final altura = double.tryParse(_altura.text.replaceAll(',', '.'));
    if (idade == null || idade < 10 || idade > 110) return avisar('Informe a idade em anos.', erro: true);
    if (peso == null || peso < 25 || peso > 350) return avisar('Informe o peso em kg (ex.: 72,5).', erro: true);
    if (altura == null || altura < 100 || altura > 250) return avisar('Informe a altura em cm (ex.: 175).', erro: true);
    setState(() => _salvando = true);
    try {
      await SaudeApiService.criarPerfilMetabolico(corpoPerfilMetabolico(
        membroId: widget.membroId,
        sexo: _sexo,
        idade: idade,
        pesoKg: peso,
        alturaCm: altura,
        objetivo: _objetivo,
        nivelAtividade: _nivel,
      ));
      ref.invalidate(perfilMetabolicoProvider(widget.membroId));
      ref.invalidate(extratoDiarioProvider);
      avisar('Plano atualizado.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _numero(TextEditingController c, String rotulo, {bool decimal = false}) => Expanded(
        child: TextField(
          controller: c,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
          decoration: InputDecoration(labelText: rotulo),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return CascaSheet(
      filhos: [
        const TopoSheet(titulo: 'Seus dados', subtitulo: 'Usados só para calcular a sua meta do dia.'),
        const SizedBox(height: NBSpacing.l),
        Segmentado<String>(opcoes: const {'M': 'Masculino', 'F': 'Feminino'}, valor: _sexo, onChanged: (v) => setState(() => _sexo = v)),
        const SizedBox(height: NBSpacing.l),
        Row(children: [
          _numero(_idade, 'Idade'),
          const SizedBox(width: NBSpacing.s),
          _numero(_peso, 'Peso (kg)', decimal: true),
          const SizedBox(width: NBSpacing.s),
          _numero(_altura, 'Altura (cm)'),
        ]),
        const SizedBox(height: NBSpacing.l),
        const Rotulo('Objetivo'),
        Wrap(spacing: NBSpacing.s, runSpacing: NBSpacing.s, children: [
          for (final o in objetivosSaude.entries)
            ChipNB(rotulo: o.value, selecionado: _objetivo == o.key, onTap: () => setState(() => _objetivo = o.key)),
        ]),
        const SizedBox(height: NBSpacing.l),
        const Rotulo('Exercício'),
        Wrap(spacing: NBSpacing.s, runSpacing: NBSpacing.s, children: [
          for (final o in niveisAtividade.entries)
            ChipNB(rotulo: o.value, selecionado: _nivel == o.key, onTap: () => setState(() => _nivel = o.key)),
        ]),
      ],
      botao: BotaoPrincipal(rotulo: 'Calcular meu plano', carregando: _salvando, onPressed: _salvar),
    );
  }
}
