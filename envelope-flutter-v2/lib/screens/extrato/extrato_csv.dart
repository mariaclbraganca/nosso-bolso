import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import 'extrato_pdf.dart' show buscarTransacoesExtrato;

Future<void> exportarCsv(
  BuildContext context,
  WidgetRef ref,
  String mes,
) async {
  final messenger = ScaffoldMessenger.of(context);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Gerando CSV...'),
      duration: Duration(seconds: 2),
    ));
  }
  try {
    final rows = await buscarTransacoesExtrato(ref, mes);
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final List<List<dynamic>> csvRows = [
      ['Data', 'Tipo', 'Descrição', 'Envelope', 'Usuário', 'Valor'],
      ...rows.map((t) {
        final dataStr = t['data']?.toString() ?? '';
        String dataFmt = dataStr;
        try {
          dataFmt = DateFormat('dd/MM/yyyy').format(DateTime.parse(dataStr));
        } catch (_) {}
        return [
          dataFmt,
          (t['tipo'] ?? '').toString(),
          (t['descricao'] ?? '').toString(),
          ((t['envelopes'] as Map?)?['nome_envelope'] ?? '').toString(),
          ((t['usuarios'] as Map?)?['nome'] ?? '').toString(),
          fmt.format((t['valor'] as num?)?.toDouble() ?? 0),
        ];
      }),
    ];

    final csvStr = const ListToCsvConverter().convert(csvRows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/extrato_$mes.csv');
    await file.writeAsString(csvStr, encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Extrato $mes',
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text('Erro ao gerar CSV: $e',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.tx)),
      backgroundColor: AppColors.red,
      duration: const Duration(seconds: 3),
    ));
  }
}
