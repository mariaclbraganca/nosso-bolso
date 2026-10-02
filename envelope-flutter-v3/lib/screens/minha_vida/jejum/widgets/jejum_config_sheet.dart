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

  const JejumConfigSheet({
    super.key,
    required this.usuarioId,
    required this.familiaId,
    required this.protocoloAtual,
  });

  @override
  ConsumerState<JejumConfigSheet> createState() => _JejumConfigSheetState();
}

class _JejumConfigSheetState extends ConsumerState<JejumConfigSheet> {
  late String _protocolo;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _protocolo = widget.protocoloAtual;
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await JejumApiService.salvarConfig(widget.usuarioId, {
        'protocolo': _protocolo,
        'familia_id': widget.familiaId,
      });
      ref.invalidate(jejumConfigProvider);
      if (mounted) {
        Navigator.pop(context);
        avisar('Protocolo atualizado com sucesso! ✨');
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
          const TopoSheet(titulo: 'Escolher Protocolo'),
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
                onTap: () => setState(() => _protocolo = proto.id),
              ),
            );
          }),
          const SizedBox(height: 16),
          BotaoPrincipal(
            rotulo: 'Confirmar Protocolo',
            carregando: _salvando,
            onPressed: _salvar,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
