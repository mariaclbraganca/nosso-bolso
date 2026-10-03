import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nosso_bolso_v3/core/providers/jejum_provider.dart';
import 'package:nosso_bolso_v3/core/services/jejum_api_service.dart';
import 'package:nosso_bolso_v3/screens/sheets/comum.dart';
import 'package:nosso_bolso_v3/ui/components/nb_components.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';

class JejumConfigSheet extends ConsumerStatefulWidget {
  final String usuarioId;
  final String familiaId;
  final String protocoloAtual;
  final Map<String, dynamic> config;

  const JejumConfigSheet({
    super.key,
    required this.usuarioId,
    required this.familiaId,
    required this.protocoloAtual,
    this.config = const {},
  });

  @override
  ConsumerState<JejumConfigSheet> createState() => _JejumConfigSheetState();
}

class _JejumConfigSheetState extends ConsumerState<JejumConfigSheet> {
  late String _protocolo;
  bool _salvando = false;
  late String _janelaInicio;
  late String _janelaFim;
  late int _folgas;

  @override
  void initState() {
    super.initState();
    _protocolo = widget.protocoloAtual;
    _janelaInicio = (widget.config['janela_inicio'] as String?)?.substring(0, 5) ?? '12:00';
    _janelaFim = (widget.config['janela_fim'] as String?)?.substring(0, 5) ?? '20:00';
    _folgas = (widget.config['joker_days_mes'] as num?)?.toInt() ?? 2;
  }

  /// Ao trocar o protocolo, o fim da janela acompanha a duração.
  void _escolherProtocolo(ProtocoloJejum p) {
    setState(() {
      _protocolo = p.id;
      _janelaFim = _somar(_janelaInicio, 24 - (p.horas ?? 16));
    });
  }

  static String _somar(String hhmm, double horas) {
    final partes = hhmm.split(':').map(int.parse).toList();
    final min = (partes[0] * 60 + partes[1] + (horas * 60).round()) % (24 * 60);
    return '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _escolherHora(bool inicio) async {
    final atual = (inicio ? _janelaInicio : _janelaFim).split(':').map(int.parse).toList();
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: atual[0], minute: atual[1]),
      helpText: inicio ? 'Primeira refeição' : 'Última refeição',
    );
    if (t == null) return;
    final txt = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (inicio) {
        _janelaInicio = txt;
        _janelaFim = _somar(txt, 24 - (ProtocoloJejum.porId(_protocolo)?.horas ?? 16));
      } else {
        _janelaFim = txt;
      }
    });
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await JejumApiService.salvarConfig(widget.usuarioId, {
        'protocolo': _protocolo,
        if (ProtocoloJejum.porId(_protocolo)?.horas != null) 'duracao_horas': ProtocoloJejum.porId(_protocolo)!.horas,
        'janela_inicio': _janelaInicio,
        'janela_fim': _janelaFim,
        'joker_days_mes': _folgas,
      });
      ref.invalidate(jejumConfigProvider);
      if (mounted) {
        Navigator.pop(context);
        avisar('Jejum configurado! ✨');
      }
    } catch (e) {
      if (mounted) avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TopoSheet(titulo: 'Configurar jejum'),
          const SizedBox(height: 16),
          ...ProtocoloJejum.todos.where((p) => p.horas != null).map((proto) {
            final sel = _protocolo == proto.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: sel ? NBColors.lavanda : NBColors.afundado,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                tileColor: sel ? NBColors.lavanda.withValues(alpha: 0.1) : null,
                leading: Text(
                  proto.label,
                  style: NBText.secao.copyWith(
                    color: sel ? NBColors.lavanda : NBColors.tinta,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                title: Text(proto.descricao, style: NBText.legenda),
                trailing: sel
                    ? const Icon(Icons.check_circle_rounded, color: NBColors.lavanda)
                    : null,
                onTap: () => _escolherProtocolo(proto),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text('Janela para comer', style: NBText.rotulo),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _escolherHora(true),
                  child: Text('Das $_janelaInicio'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _escolherHora(false),
                  child: Text('Até $_janelaFim'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Folgas por mês', style: NBText.rotulo),
                    Text('Dias livres que não quebram a sequência', style: NBText.legenda),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Menos folgas',
                onPressed: _folgas > 0 ? () => setState(() => _folgas--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_folgas', style: NBText.secao),
              IconButton(
                tooltip: 'Mais folgas',
                onPressed: _folgas < 8 ? () => setState(() => _folgas++) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BotaoPrincipal(
            rotulo: 'Salvar',
            carregando: _salvando,
            onPressed: _salvar,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
