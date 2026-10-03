import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nosso_bolso_v3/core/services/jejum_api_service.dart';
import 'package:nosso_bolso_v3/core/services/jejum_notification_service.dart';
import 'package:nosso_bolso_v3/screens/sheets/comum.dart';
import 'package:nosso_bolso_v3/ui/components/nb_components.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';
import 'package:nosso_bolso_v3/ui/unicorn/unicorn.dart';

class JejumConclusaoSheet extends ConsumerStatefulWidget {
  final String registroId;
  final Duration decorrido;
  final double metaHoras;

  const JejumConclusaoSheet({
    super.key,
    required this.registroId,
    required this.decorrido,
    required this.metaHoras,
  });

  @override
  ConsumerState<JejumConclusaoSheet> createState() => _JejumConclusaoSheetState();
}

class _JejumConclusaoSheetState extends ConsumerState<JejumConclusaoSheet> {
  String _sentimento = 'leve';
  bool _salvando = false;

  final _sentimentos = const [
    ('leve', '✨ Super leve'),
    ('energia', '⚡ Com energia'),
    ('cansada_firme', '💪 Firme'),
    ('dificuldade', '🍎 Sentindo fome'),
  ];

  Future<void> _concluir(String status) async {
    setState(() => _salvando = true);
    try {
      await JejumApiService.finalizar(
        widget.registroId,
        status: status,
        sentimento: _sentimento,
      );
      JejumNotificationService.encerrar(); // sem await: não segura o fechamento da tela
      if (mounted) {
        Navigator.pop(context);
        final msg = status == 'completo'
            ? 'Parabéns pelo seu jejum concluído! 🎉'
            : 'Descanso acolhido com carinho! Amanhã é um novo dia. 🌸';
        avisar(msg);
      }
    } catch (e) {
      if (mounted) avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metaAtingida = widget.decorrido.inMinutes >= (widget.metaHoras * 60);

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
          const TopoSheet(titulo: 'Finalizar Jejum'),
          const SizedBox(height: 12),
          const Row(
            children: [
              UnicornWidget(type: UnicornType.sweet, size: 40, mood: UnicornMood.love),
              SizedBox(width: 8),
              Expanded(
                child: UnicornFala(
                  type: UnicornType.sweet,
                  texto: 'Ouça seu corpo com muito carinho e gentileza.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Como você está se sentindo?', style: NBText.secao),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sentimentos.map((s) {
              final sel = _sentimento == s.$1;
              return ChoiceChip(
                label: Text(s.$2),
                selected: sel,
                onSelected: (val) {
                  if (val) setState(() => _sentimento = s.$1);
                },
                selectedColor: NBColors.lavanda.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: sel ? NBColors.lavanda : NBColors.tinta,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          BotaoPrincipal(
            rotulo: metaAtingida ? 'Concluir Jejum 🎉' : 'Completar até aqui',
            carregando: _salvando,
            onPressed: () => _concluir('completo'),
          ),
          const SizedBox(height: 8),
          BotaoSecundario(
            rotulo: 'Dia de descanso 🌸',
            onPressed: () => _concluir('interrompido'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
