import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../core/providers/contas_provider.dart';
import '../../../core/providers/mes_provider.dart';
import '../../../core/services/financeiro_ext_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';
import '../sheets/comum.dart';
import 'widgets/contas_card.dart';
import 'widgets/form_conta_sheet.dart';

class ContasTab extends ConsumerWidget {
  const ContasTab({super.key});

  Future<void> _togglePago(WidgetRef ref, BuildContext context, String id, bool pago) async {
    try {
      try {
        await FinanceiroExtService.marcarPaga(id, pago: pago);
      } catch (_) {
        await supabase.from('contas_pagar').update({'pago': pago}).eq('id', id);
      }
      if (pago) {
        final idNum = (id.hashCode).abs() % 100000;
        NotificationService.cancelarAlertaConta(idNum);
      }
      final mes = ref.read(mesAtualProvider);
      ref.invalidate(contasMesProvider(mes));
      ref.invalidate(resumoContasProvider(mes));
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    }
  }

  Future<void> _excluirConta(WidgetRef ref, BuildContext context, String id) async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NBColors.cartao,
        title: const Text('Excluir Conta', style: TextStyle(color: NBColors.tinta)),
        content: Text('Deseja realmente excluir este boleto?', style: NBText.corpo),
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
        try {
          await FinanceiroExtService.deletarConta(id);
        } catch (_) {
          await supabase.from('contas_pagar').delete().eq('id', id);
        }
        final mes = ref.read(mesAtualProvider);
        ref.invalidate(contasMesProvider(mes));
        ref.invalidate(resumoContasProvider(mes));
        avisar('Conta excluída.');
      } catch (e) {
        avisar(mensagemErro(e), erro: true);
      }
    }
  }

  void _abrirForm(BuildContext context, WidgetRef ref) async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NBColors.cartao,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const FormContaSheet(),
    );
    if (res == true) {
      final mes = ref.read(mesAtualProvider);
      ref.invalidate(contasMesProvider(mes));
      ref.invalidate(resumoContasProvider(mes));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesAtualProvider);
    final contasAsync = ref.watch(contasMesProvider(mes));

    return contasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: NBColors.verde)),
      error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: NBColors.estouro))),
      data: (contas) {
        final total = contas.fold(0.0, (sum, c) => sum + ((c['valor'] as num?)?.toDouble() ?? 0.0));
        final pago = contas.where((c) => c['pago'] == true).fold(0.0, (sum, c) => sum + ((c['valor'] as num?)?.toDouble() ?? 0.0));
        final aPagar = total - pago;

        return ListView(
          padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 12, NBSpacing.margemTela, 120),
          children: [
            CartaoNB(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BOLETOS & CONSUMO', style: NBText.eyebrow),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total de faturas', style: NBText.legenda),
                            const SizedBox(height: 2),
                            Text(brl(total), style: NBText.valorCartao),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Pendente', style: NBText.legenda),
                          const SizedBox(height: 2),
                          Text(
                            brl(aPagar),
                            style: NBText.valorCartao.copyWith(
                              color: aPagar > 0 ? NBColors.estouro : NBColors.verde,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: NBSpacing.l),
            const CabecalhoSecao(titulo: 'Contas do Mês'),
            const SizedBox(height: NBSpacing.s),
            if (contas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: UnicornVazio(
                  type: UnicornType.geronimo,
                  titulo: 'Nenhuma conta cadastrada',
                  texto: 'Cadastre suas contas com vencimento para receber lembretes.',
                ),
              )
            else
              for (final c in contas)
                ContasCard(
                  conta: c,
                  onTogglePago: (v) => _togglePago(ref, context, c['id'] as String, v),
                  onExcluir: () => _excluirConta(ref, context, c['id'] as String),
                ),
            const SizedBox(height: NBSpacing.m),
            BotaoSecundario(
              rotulo: '+ Nova Conta / Boleto',
              onPressed: () => _abrirForm(context, ref),
            ),
          ],
        );
      },
    );
  }
}
