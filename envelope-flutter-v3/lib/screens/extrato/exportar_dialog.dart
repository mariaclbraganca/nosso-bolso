import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/app_navigator.dart';
import '../../ui/theme/nb_theme.dart';
import 'extrato_pdf.dart';

class ExportarDialog extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> transacoes;
  final String mes;

  const ExportarDialog({super.key, required this.transacoes, required this.mes});

  @override
  ConsumerState<ExportarDialog> createState() => _ExportarDialogState();
}

class _ExportarDialogState extends ConsumerState<ExportarDialog> {
  /// PDF com resumo, envelopes, lançamentos e análise da IA (mesmo da v2).
  /// Usa o contexto do navegador raiz: este diálogo fecha antes de terminar.
  Future<void> _exportarPDF() async {
    final raiz = navigatorKey.currentContext;
    Navigator.pop(context);
    if (raiz != null && raiz.mounted) await exportarPdf(raiz, ref, widget.mes);
  }

  bool _gerando = false;

  Future<void> _exportarCSV() async {
    setState(() => _gerando = true);
    try {
      final rows = <List<dynamic>>[
        ['Data', 'Tipo', 'Descrição', 'Valor', 'Envelope', 'Membro', 'Forma'],
      ];

      for (final t in widget.transacoes) {
        final data = t['data']?.toString() ?? t['created_at']?.toString() ?? '';
        final tipo = t['tipo']?.toString() ?? '';
        final desc = t['descricao']?.toString() ?? '';
        final valor = (t['valor'] as num?)?.toDouble() ?? 0.0;
        final env = (t['envelopes'] as Map?)?['nome_envelope']?.toString() ?? '';
        final membro = (t['usuarios'] as Map?)?['nome']?.toString() ?? '';
        final forma = t['forma_pagamento']?.toString() ?? '';

        rows.add([data, tipo, desc, valor.toStringAsFixed(2), env, membro, forma]);
      }

      final csvData = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/extrato_${widget.mes}.csv');
      await file.writeAsString(csvData);

      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context);
      await Share.shareXFiles([XFile(file.path)], text: 'Extrato Nosso Bolso - ${widget.mes}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar: $e'), backgroundColor: NBColors.estouro),
        );
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NBColors.cartao,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NBRadius.cartao)),
      title: Text('Exportar Extrato', style: NBText.secao),
      content: Text(
        '${widget.transacoes.length} lançamentos de ${widget.mes}. O PDF traz resumo, envelopes e uma análise da IA; '
        'o CSV abre em planilhas.',
        style: NBText.corpo.copyWith(color: NBColors.tintaSuave),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        OutlinedButton.icon(
          onPressed: _gerando ? null : _exportarPDF,
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
          label: const Text('PDF'),
        ),
        FilledButton.icon(
          onPressed: _gerando ? null : _exportarCSV,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          icon: _gerando
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.share_rounded, size: 16),
          label: const Text('CSV'),
        ),
      ],
    );
  }
}
