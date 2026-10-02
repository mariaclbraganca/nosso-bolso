import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../theme/app_theme.dart';
import '../../../providers/envelopes_provider.dart';
import '../../../providers/usuarios_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/app_navigator.dart';
import 'compras_confirmar_widgets.dart';

/// Diálogo Material para confirmação de compra pendente e vínculo a envelope.
class ConfirmarDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> compra;
  const ConfirmarDialog({super.key, required this.compra});

  @override
  ConsumerState<ConfirmarDialog> createState() => _ConfirmarDialogState();
}

class _ConfirmarDialogState extends ConsumerState<ConfirmarDialog> {
  String? _envelopeId;
  bool _confirmando = false;

  String _formatDate(String raw) {
    if (raw.length < 10) return raw;
    final p = raw.substring(0, 10).split('-');
    if (p.length < 3) return raw;
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
    final envelopesAsync = ref.watch(envelopesProvider);
    final itens = (widget.compra['itens'] as List?) ?? [];
    final valorTotal = (widget.compra['valor_total'] as num?)?.toDouble() ?? 0.0;

    Map<String, dynamic>? envelopeSel;
    if (_envelopeId != null && envelopesAsync.asData != null) {
      for (final e in envelopesAsync.asData!.value) {
        if (e['id'] == _envelopeId) {
          envelopeSel = e;
          break;
        }
      }
    }
    final saldoAtual = (envelopeSel?['saldo_atual'] as num?)?.toDouble() ?? 0.0;
    final estourado = envelopeSel != null && (saldoAtual < valorTotal);
    final diferenca = saldoAtual - valorTotal;

    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        side: const BorderSide(color: AppColors.bord, width: 0.5),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Confirmar Compra', style: AppTextStyles.titleSm),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.mu),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.compra['supermercado'] ?? 'Supermercado'} · ${_formatDate(widget.compra['data_compra'] as String? ?? '')}',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
            ),
            const SizedBox(height: 16),
            buildResumoValorCompra(valorTotal, itens),
            const SizedBox(height: 16),
            Text('Debitar de qual envelope?',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            buildSeletorEnvelopeCompra(
              envelopesAsync: envelopesAsync,
              envelopeIdSelecionado: _envelopeId,
              valorTotal: valorTotal,
              onChanged: (v) => setState(() => _envelopeId = v),
            ),
            if (estourado) ...[
              const SizedBox(height: 12),
              buildAlertaEstouroCompra(diferenca),
            ],
            const SizedBox(height: 20),
            _botaoConfirmar(perfil),
          ],
        ),
      ),
    );
  }

  Widget _botaoConfirmar(Map<String, dynamic>? perfil) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.acc,
          disabledBackgroundColor: AppColors.bord,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
        ),
        onPressed: (_envelopeId == null || _confirmando) ? null : () => _confirmar(perfil),
        child: _confirmando
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
            : const Text('Confirmar e Debitar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }

  Future<void> _confirmar(Map<String, dynamic>? perfil) async {
    if (perfil == null || _envelopeId == null) return;
    setState(() => _confirmando = true);
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/v1/compras/confirmar');
      final resp = await http.post(
        uri,
        headers: ApiService.authHeaders(json: true),
        body: jsonEncode({
          'compra_id': widget.compra['compra_id'],
          'familia_id': perfil['familia_id'],
          'usuario_id': perfil['id'],
          'envelope_id': _envelopeId,
        }),
      );
      if (resp.statusCode == 200) {
        if (mounted) Navigator.pop(context);
        scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(
          content: Text('Compra confirmada e debitada do envelope!'),
          backgroundColor: AppColors.grn,
          duration: Duration(seconds: 3),
        ));
      } else {
        final body = jsonDecode(resp.body);
        throw Exception(body['detail'] ?? resp.body);
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('Exception:')) msg = msg.replaceFirst('Exception:', '').trim();
        if (msg.contains('400') || msg.contains('Backend')) msg = 'Não foi possível confirmar. Verifique a conexão e o envelope.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }
}
