import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/saude_provider.dart';
import '../../../../core/services/saude_api_service.dart';
import '../../../../ui/components/nb_components.dart';
import '../../../../ui/theme/nb_theme.dart';
import '../../../sheets/comum.dart';

double _n(Map? m, String k) => (m?[k] as num?)?.toDouble() ?? 0;

/// Proteína, carboidrato e gordura consumidos no dia × meta do plano.
class MacrosCard extends StatelessWidget {
  const MacrosCard({super.key, required this.extrato});
  final Map<String, dynamic>? extrato;

  @override
  Widget build(BuildContext context) {
    final linhas = [
      ('Proteína', _n(extrato, 'proteina_consumida_g'), _n(extrato, 'proteina_meta_g'), NBColors.verde),
      ('Carboidrato', _n(extrato, 'carboidrato_consumido_g'), _n(extrato, 'carboidrato_meta_g'), NBColors.ambarBarra),
      ('Gordura', _n(extrato, 'gordura_consumida_g'), _n(extrato, 'gordura_meta_g'), NBColors.reserva),
    ];
    return CartaoNB(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Macronutrientes de hoje', style: NBText.rotulo),
          const SizedBox(height: NBSpacing.m),
          for (final (nome, feito, meta, cor) in linhas) ...[
            Row(
              children: [
                Expanded(child: Text(nome, style: NBText.corpo.copyWith(fontSize: 14))),
                Text(meta > 0 ? '${feito.round()} / ${meta.round()} g' : '${feito.round()} g', style: NBText.legenda),
              ],
            ),
            const SizedBox(height: 4),
            BarraProgresso(fracao: meta > 0 ? feito / meta : 0, cor: cor),
            const SizedBox(height: NBSpacing.s),
          ],
        ],
      ),
    );
  }
}

/// Último peso, média dos últimos 7 registros e o botão de registrar.
class PesoCard extends ConsumerWidget {
  const PesoCard({super.key, required this.membroId, required this.onHistorico});
  final String membroId;
  final VoidCallback onHistorico;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = ref.watch(historicoPesoProvider(membroId)).valueOrNull;
    final registros = ((dados?['registros'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final ultimo = registros.isEmpty ? null : (registros.first['peso_kg'] as num?)?.toDouble();
    final media = (dados?['media_movel_7d'] as num?)?.toDouble();

    return CartaoNB(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Peso', style: NBText.rotulo),
                const SizedBox(height: 2),
                Text(ultimo == null ? 'Sem registro' : '${ultimo.toStringAsFixed(1).replaceAll('.', ',')} kg',
                    style: NBText.valorCartao),
                if (media != null)
                  Text('Média dos últimos registros: ${media.toStringAsFixed(1).replaceAll('.', ',')} kg',
                      style: NBText.legenda),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: () => abrirSheet(context, SheetRegistrarPeso(membroId: membroId)),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                child: const Text('Registrar'),
              ),
              TextButton(onPressed: onHistorico, child: const Text('Ver evolução')),
            ],
          ),
        ],
      ),
    );
  }
}

class SheetRegistrarPeso extends ConsumerStatefulWidget {
  const SheetRegistrarPeso({super.key, required this.membroId});
  final String membroId;

  @override
  ConsumerState<SheetRegistrarPeso> createState() => _SheetRegistrarPesoState();
}

class _SheetRegistrarPesoState extends ConsumerState<SheetRegistrarPeso> {
  final _peso = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _peso.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final peso = double.tryParse(_peso.text.replaceAll(',', '.'));
    if (peso == null || peso < 25 || peso > 350) return avisar('Informe o peso em kg (ex.: 72,5).', erro: true);
    setState(() => _salvando = true);
    try {
      await SaudeApiService.registrarPeso({'membro_id': widget.membroId, 'peso_kg': peso});
      ref.invalidate(historicoPesoProvider(widget.membroId));
      ref.invalidate(historicoProvider);
      avisar('Peso registrado.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CascaSheet(
      filhos: [
        const TopoSheet(
          titulo: 'Registrar peso',
          subtitulo: 'Pese sempre no mesmo horário. O app olha a média, não uma pesagem isolada.',
        ),
        const SizedBox(height: NBSpacing.l),
        TextField(
          controller: _peso,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          style: NBText.valorCartao,
          decoration: const InputDecoration(labelText: 'Peso (kg)', suffixText: 'kg'),
        ),
      ],
      botao: BotaoPrincipal(rotulo: 'Salvar peso', carregando: _salvando, onPressed: _salvar),
    );
  }
}
