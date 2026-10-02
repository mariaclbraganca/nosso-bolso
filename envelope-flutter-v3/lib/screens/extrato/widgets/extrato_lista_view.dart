import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';
import 'extrato_transacao_card.dart';

/// Lista de transações agrupadas por data com subtotais diários
class ExtratoListaView extends StatelessWidget {
  final List<Map<String, dynamic>> transacoes;
  final String termoBusca;
  final String? envelopeFiltroId;
  final String? usuarioFiltroId;

  const ExtratoListaView({
    super.key,
    required this.transacoes,
    required this.termoBusca,
    this.envelopeFiltroId,
    this.usuarioFiltroId,
  });

  String _formatarDataGrupo(String dataStr) {
    try {
      final data = DateTime.parse(dataStr);
      final hoje = DateTime.now();
      final ontem = hoje.subtract(const Duration(days: 1));

      if (data.year == hoje.year && data.month == hoje.month && data.day == hoje.day) {
        return 'Hoje';
      }
      if (data.year == ontem.year && data.month == ontem.month && data.day == ontem.day) {
        return 'Ontem';
      }
      return DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(data);
    } catch (_) {
      return dataStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = transacoes.where((t) {
      if (envelopeFiltroId != null && t['envelope_id'] != envelopeFiltroId) return false;
      if (usuarioFiltroId != null && t['usuario_id'] != usuarioFiltroId) return false;
      if (termoBusca.isNotEmpty) {
        final desc = (t['descricao'] as String? ?? '').toLowerCase();
        final env = (((t['envelopes'] as Map?)?['nome_envelope'] as String?) ?? '').toLowerCase();
        final usr = (((t['usuarios'] as Map?)?['nome'] as String?) ?? '').toLowerCase();
        final q = termoBusca.toLowerCase();
        if (!desc.contains(q) && !env.contains(q) && !usr.contains(q)) return false;
      }
      return true;
    }).toList();

    if (filtradas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: UnicornVazio(
          type: UnicornType.astrix,
          titulo: termoBusca.isNotEmpty ? 'Nenhuma transação encontrada' : 'Nenhuma transação no período',
          texto: termoBusca.isNotEmpty
              ? 'Tente buscar por outro termo ou limpe os filtros.'
              : 'As movimentações deste ciclo aparecerão aqui.',
        ),
      );
    }

    // Agrupar por data (yyyy-MM-dd)
    final Map<String, List<Map<String, dynamic>>> grupos = {};
    for (final t in filtradas) {
      final raw = t['data']?.toString() ?? t['created_at']?.toString() ?? '';
      final chave = raw.length >= 10 ? raw.substring(0, 10) : 'Outros';
      grupos.putIfAbsent(chave, () => []).add(t);
    }

    final chavesOrdenadas = grupos.keys.toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: NBSpacing.margemTela),
      itemCount: chavesOrdenadas.length,
      itemBuilder: (context, i) {
        final chave = chavesOrdenadas[i];
        final itens = grupos[chave]!;

        double subtotal = 0;
        for (final item in itens) {
          final val = (item['valor'] as num?)?.toDouble() ?? 0.0;
          if (item['tipo'] == 'receita') {
            subtotal += val;
          } else {
            subtotal -= val;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatarDataGrupo(chave),
                    style: NBText.eyebrow.copyWith(
                      color: NBColors.tinta,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    brl(subtotal, sinal: true, curto: true),
                    style: NBText.legenda.copyWith(
                      color: subtotal < 0 ? NBColors.tintaSuave : NBColors.verde,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            for (final tx in itens)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ExtratoTransacaoCard(transacao: tx),
              ),
          ],
        );
      },
    );
  }
}
