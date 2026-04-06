import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class TransacaoItem extends StatelessWidget {
  final Map<String, dynamic> t;
  const TransacaoItem({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final isDsp = t['tipo'] == 'despesa';
    final userColor = AppColors.corDoUsuario(t['usuarios']['nome'] ?? '?');
    final abbr = t['usuarios']['nome'].substring(0, 2).toUpperCase();
    final mainColor = isDsp ? AppColors.red : AppColors.grn;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: mainColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              isDsp ? (t['envelopes']?['emoji'] ?? '📦') : '💰',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t['descricao'] ?? (isDsp ? 'Compra' : 'Entrada'),
                  style: const TextStyle(fontSize: 14, color: AppColors.tx),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 9,
                      backgroundColor: userColor.withOpacity(0.15),
                      child: Text(abbr, style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: userColor)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${t['usuarios']['nome'].split(' ')[0]}${isDsp ? ' · ${t['envelopes']?['nome_envelope']?.split(' ')?.first ?? 'Env'}' : ''}',
                      style: const TextStyle(fontSize: 11, color: AppColors.mu),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (t['comprovante_url'] != null) ...[
            GestureDetector(
              onTap: () => _mostrarComprovante(context),
              child: const Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.acc),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            '${isDsp ? '-' : '+'}${NumberFormat.simpleCurrency(locale: 'pt_BR').format(t['valor'])}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: mainColor),
          ),
        ],
      ),
    );
  }

  void _mostrarComprovante(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(t['comprovante_url']!),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('FECHAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
