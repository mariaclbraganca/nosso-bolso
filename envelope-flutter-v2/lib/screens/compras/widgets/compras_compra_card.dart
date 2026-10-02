import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/compras_provider.dart';
import '../../../providers/usuarios_provider.dart';
import 'compras_confirmar_dialog.dart';
import 'compras_compra_card_widgets.dart';
import 'compras_card_actions.dart';

/// Card de exibição e interação com uma compra pendente.
class CompraCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> compra;
  const CompraCard({super.key, required this.compra});

  @override
  ConsumerState<CompraCard> createState() => _CompraCardState();
}

class _CompraCardState extends ConsumerState<CompraCard> {
  bool _expandido = false;
  bool _processandoCupom = false;

  String _formatDate(String raw) {
    if (raw.length < 10) return raw;
    final p = raw.substring(0, 10).split('-');
    if (p.length < 3) return raw;
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final compra = widget.compra;
    final itens = (compra['itens'] as List?) ?? [];
    final supermercado = compra['supermercado'] as String? ?? 'Supermercado';
    final valorTotal = (compra['valor_total'] as num?)?.toDouble() ?? 0.0;
    final dataCompra = _formatDate(compra['data_compra'] as String? ?? '');

    final Map<String, List<Map<String, dynamic>>> porCategoria = {};
    for (final item in itens) {
      final cat = item['categoria'] as String? ?? 'Outros';
      porCategoria.putIfAbsent(cat, () => []).add(Map<String, dynamic>.from(item as Map));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord),
      ),
      child: Column(
        children: [
          _buildHeader(compra, supermercado, dataCompra, itens, valorTotal),
          if (_expandido && compra['fonte'] != 'ifood')
            buildItensExpandidosCompra(porCategoria),
          if (itens.isEmpty)
            _buildBotaoCupom(compra),
          _buildAcoes(context, ref),
        ],
      ),
    );
  }

  Widget _buildHeader(Map compra, String supermercado, String dataCompra, List itens, double valorTotal) {
    return InkWell(
      onTap: () => setState(() => _expandido = !_expandido),
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePad),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: (compra['fonte'] == 'ifood' ? AppColors.red : AppColors.gold).withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 4),
              ),
              child: compra['fonte'] == 'ifood'
                  ? const Text('🍔', style: TextStyle(fontSize: 22), textAlign: TextAlign.center)
                  : const Icon(Icons.storefront_rounded, color: AppColors.gold, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supermercado, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    compra['fonte'] == 'ifood' ? '$dataCompra · iFood Benefícios' : '$dataCompra · ${itens.length} item${itens.length != 1 ? 's' : ''}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('R\$ ${valorTotal.toStringAsFixed(2)}', style: AppTextStyles.monoSm.copyWith(color: AppColors.acc)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.org.withOpacity(0.15), borderRadius: BorderRadius.circular(AppSpacing.radiusChip)),
                  child: Text('Pendente', style: AppTextStyles.caption.copyWith(color: AppColors.org)),
                ),
              ],
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: _expandido ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mu, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotaoCupom(Map compra) {
    final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
    final familiaId = perfil?['familia_id'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pagePad, 0, AppSpacing.pagePad, 10),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: _processandoCupom
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.acc))
              : const Icon(Icons.camera_alt_rounded, size: 16, color: AppColors.acc),
          label: Text(_processandoCupom ? 'Processando cupom...' : 'Tenho o cupom', style: AppTextStyles.bodySm.copyWith(color: AppColors.acc, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.acc),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onPressed: _processandoCupom
              ? null
              : () async {
                  setState(() => _processandoCupom = true);
                  await escanearCupomParaCompra(context, ref, compra['compra_id'] as String? ?? '', familiaId);
                  if (mounted) setState(() => _processandoCupom = false);
                },
        ),
      ),
    );
  }

  Widget _buildAcoes(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pagePad, 0, AppSpacing.pagePad, AppSpacing.pagePad),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.red),
              label: const Text('Rejeitar', style: TextStyle(color: AppColors.red, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () => rejeitarCompraDialog(context, ref, widget.compra),
            ),
          ),
          const SizedBox(width: AppSpacing.cardGap),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded, size: 16, color: Colors.black),
              label: const Text('CONFIRMAR COMPRA', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.3)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.acc,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () async {
                await showDialog(context: context, builder: (_) => ConfirmarDialog(compra: widget.compra));
                ref.invalidate(comprasPendentesProvider);
              },
            ),
          ),
        ],
      ),
    );
  }
}
