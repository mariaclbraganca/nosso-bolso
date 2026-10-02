import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/fixos_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';
import '../sheets/comum.dart';
import 'widgets/fixos_card.dart';
import 'widgets/fixos_resumo_card.dart';
import 'widgets/form_fixo_sheet.dart';

class FixosTab extends ConsumerStatefulWidget {
  const FixosTab({super.key});

  @override
  ConsumerState<FixosTab> createState() => _FixosTabState();
}

class _FixosTabState extends ConsumerState<FixosTab> {
  bool _modoSelecao = false;
  final Set<String> _selecionados = {};

  void _toggleSelecao(String id) {
    setState(() {
      if (_selecionados.contains(id)) {
        _selecionados.remove(id);
        if (_selecionados.isEmpty) _modoSelecao = false;
      } else {
        _selecionados.add(id);
      }
    });
  }

  /// Pagar gera a transação despesa_fixa no backend (o trigger debita o saldo
  /// geral); se não houver saldo, o backend recusa e o fixo continua pendente.
  Future<bool> _togglePago(String id, bool pago) async {
    try {
      await ApiService.patch('/fixos/$id', {'pago': pago});
      if (pago) NotificationService.cancelarAlertasFixo(id);
      return true;
    } catch (e) {
      final msg = mensagemErro(e);
      if (msg.toLowerCase().contains('saldo')) {
        ref.geronimo('Sem saldo geral para pagar esse fixo. Lance a receita ou remaneje antes.');
      } else {
        avisar(msg, erro: true);
      }
      return false;
    }
  }

  Future<void> _marcarSelecionadosComoPagos() async {
    if (_selecionados.isEmpty) return;
    var pagos = 0;
    for (final id in _selecionados.toList()) {
      if (!await _togglePago(id, true)) break;
      pagos++;
      _selecionados.remove(id);
    }
    if (pagos > 0) avisar('$pagos ${pagos == 1 ? 'fixo pago' : 'fixos pagos'}.');
    if (mounted) setState(() => _modoSelecao = _selecionados.isNotEmpty);
  }

  Future<void> _excluirFixo(String id, String nome) async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NBColors.cartao,
        title: const Text('Excluir Gasto Fixo', style: TextStyle(color: NBColors.tinta)),
        content: Text('Deseja excluir "$nome"?', style: NBText.corpo),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: NBColors.estouro)),
          ),
        ],
      ),
    );
    if (conf == true) {
      try {
        await ApiService.delete('/fixos/$id');
        avisar('Gasto fixo excluído.');
      } catch (e) {
        avisar(mensagemErro(e), erro: true);
      }
    }
  }

  void _abrirForm([Map<String, dynamic>? fixo]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NBColors.cartao,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NBRadius.sheet)),
      ),
      builder: (_) => FormFixoSheet(fixoParaEditar: fixo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fixos = ref.watch(fixosMesAtualProvider);
    final total = fixos.fold(0.0, (sum, f) => sum + ((f['valor'] as num?)?.toDouble() ?? 0.0));
    final pago = fixos.where((f) => f['pago'] == true).fold(0.0, (sum, f) => sum + ((f['valor'] as num?)?.toDouble() ?? 0.0));
    final reservado = total - pago;
    final pagosCount = fixos.where((f) => f['pago'] == true).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 12, NBSpacing.margemTela, 120),
      children: [
        FixosResumoCard(
          total: total,
          pago: pago,
          reservado: reservado,
          totalCount: fixos.length,
          pagosCount: pagosCount,
        ),
        const SizedBox(height: NBSpacing.l),
        Row(
          children: [
            const CabecalhoSecao(titulo: 'Gastos Recorrentes'),
            const Spacer(),
            if (_modoSelecao)
              TextButton(
                onPressed: () => setState(() {
                  _modoSelecao = false;
                  _selecionados.clear();
                }),
                child: const Text('Cancelar', style: TextStyle(color: NBColors.tintaSuave)),
              )
            else if (fixos.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _modoSelecao = true),
                child: const Text('Selecionar', style: TextStyle(color: NBColors.tintaSuave)),
              ),
          ],
        ),
        if (_modoSelecao && _selecionados.isNotEmpty) ...[
          const SizedBox(height: 8),
          BotaoPrincipal(
            rotulo: 'Marcar ${_selecionados.length} como pagos',
            onPressed: _marcarSelecionadosComoPagos,
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: NBSpacing.s),
        if (fixos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: UnicornVazio(
              type: UnicornType.happy,
              titulo: 'Nenhum gasto fixo',
              texto: 'Cadastre suas contas mensais para não perder os prazos.',
            ),
          )
        else
          for (final f in fixos)
            FixosCard(
              fixo: f,
              selecionado: _selecionados.contains(f['id']),
              modoSelecao: _modoSelecao,
              onTogglePago: (v) => _togglePago(f['id'] as String, v ?? false),
              onTap: () {
                if (_modoSelecao) {
                  _toggleSelecao(f['id'] as String);
                } else {
                  _togglePago(f['id'] as String, !(f['pago'] == true));
                }
              },
              onLongPress: () {
                setState(() {
                  _modoSelecao = true;
                  _selecionados.add(f['id'] as String);
                });
              },
              onEditar: () => _abrirForm(f),
              onExcluir: () => _excluirFixo(f['id'] as String, f['nome'] as String? ?? ''),
            ),
        const SizedBox(height: NBSpacing.m),
        BotaoSecundario(
          rotulo: '+ Adicionar Gasto Fixo',
          onPressed: () => _abrirForm(),
        ),
      ],
    );
  }
}
