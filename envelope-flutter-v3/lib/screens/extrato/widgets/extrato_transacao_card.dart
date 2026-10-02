import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../edit_transacao_sheet.dart';

/// Card individual para exibir uma transação no estilo papel e tinta
class ExtratoTransacaoCard extends ConsumerWidget {
  final Map<String, dynamic> transacao;

  const ExtratoTransacaoCard({super.key, required this.transacao});

  Future<void> _excluir(BuildContext context, WidgetRef ref) async {
    final id = transacao['id']?.toString();
    if (id == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NBColors.cartao,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NBRadius.cartao),
          side: const BorderSide(color: NBColors.linha),
        ),
        title: Text('Mover para lixeira?', style: NBText.secao),
        content: Text(
          'A transação pode ser restaurada depois na Lixeira.',
          style: NBText.corpo.copyWith(color: NBColors.tintaSuave),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: NBText.rotulo.copyWith(color: NBColors.tintaSuave)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NBColors.estouro,
              minimumSize: const Size(90, 42),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await supabase.from('transacoes').update({
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      HapticFeedback.lightImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transação movida para a lixeira'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Desfazer',
              textColor: NBColors.ambar,
              onPressed: () async {
                await supabase.from('transacoes').update({'deleted_at': null}).eq('id', id);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: NBColors.estouro),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipo = transacao['tipo'] as String? ?? 'despesa';
    final valor = (transacao['valor'] as num?)?.toDouble() ?? 0.0;
    final descricao = (transacao['descricao'] as String?)?.trim();
    final envelope = transacao['envelopes'] as Map?;
    final envNome = envelope?['nome_envelope'] as String? ?? '';
    final envEmoji = envelope?['emoji'] as String? ?? '💰';
    final usuario = transacao['usuarios'] as Map?;
    final usrNome = usuario?['nome'] as String? ?? '';
    final forma = transacao['forma_pagamento'] as String?;

    final isReceita = tipo == 'receita';
    final isAporte = tipo == 'abastecimento';

    final Color corValor = isReceita
        ? NBColors.verde
        : isAporte
            ? NBColors.reserva
            : NBColors.tinta;

    final String sinalValor = isReceita ? '+ ' : isAporte ? '📥 ' : '− ';

    return Dismissible(
      key: ValueKey('tx_${transacao['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: NBColors.estouroClaro,
          borderRadius: BorderRadius.circular(NBRadius.cartao),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: NBColors.estouro, size: 24),
      ),
      confirmDismiss: (_) async {
        await _excluir(context, ref);
        return false; // Controle manual de exclusão
      },
      child: CartaoNB(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => EditTransacaoSheet(transacao: transacao),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isReceita
                    ? NBColors.verdeClaro
                    : isAporte
                        ? NBColors.reservaClaro
                        : NBColors.afundado,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isReceita ? '💵' : isAporte ? '📥' : envEmoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    descricao != null && descricao.isNotEmpty
                        ? descricao
                        : isReceita
                            ? 'Receita'
                            : envNome.isNotEmpty
                                ? envNome
                                : 'Despesa',
                    style: NBText.corpo.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (!isReceita && envNome.isNotEmpty) ...[
                        Flexible(
                          child: Text(
                            envNome,
                            style: NBText.legenda,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('·', style: NBText.legenda),
                        const SizedBox(width: 4),
                      ],
                      if (usrNome.isNotEmpty) ...[
                        Text(usrNome, style: NBText.legenda),
                      ],
                      if (forma != null && forma.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        SeloNB(forma.toUpperCase()),
                      ],
                    ],
                  ),

                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$sinalValor${brl(valor)}',
              style: NBText.valorCartao.copyWith(
                color: corValor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
