import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/providers/envelopes_provider.dart';
import '../../core/providers/transacoes_provider.dart';
import '../../core/services/api_service.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';
import 'comum.dart';
import '../lancar/lancar.dart';
import 'sheet_planejar_mes.dart';
import 'sheet_envelope.dart';
import 'sheet_remanejar.dart';

/// Lançamentos de um envelope, mais recentes primeiro, sem os da lixeira.
final transacoesDoEnvelopeProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, envelopeId) {
  return supabase
      .from('transacoes')
      .stream(primaryKey: ['id'])
      .eq('envelope_id', envelopeId)
      .order('created_at', ascending: false)
      .map((rows) => rows.where((t) => t['deleted_at'] == null).toList());
});

Future<void> abrirDetalheEnvelope(BuildContext context, String envelopeId) =>
    abrirSheet(context, SheetEnvelopeDetalhe(envelopeId: envelopeId));

class SheetEnvelopeDetalhe extends ConsumerWidget {
  const SheetEnvelopeDetalhe({super.key, required this.envelopeId});
  final String envelopeId;

  Future<bool> _excluir(BuildContext context, WidgetRef ref, Map<String, dynamic> t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NBColors.cartao,
        title: Text('Mandar para a lixeira?', style: NBText.secao),
        content: Text('${t['descricao'] ?? 'Lançamento'} · ${brl((t['valor'] as num).toDouble())}. '
            'Dá para restaurar pela lixeira do Extrato.', style: NBText.corpo),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: NBColors.estouro)),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      final p = perfilOuErro(ref);
      await ApiService.delete('/transacoes/${t['id']}', familiaId: p['familia_id'] as String);
      HapticFeedback.mediumImpact();
      avisar('Lançamento na lixeira.');
      return true;
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(envelopesProvider).valueOrNull?.where((e) => e['id'] == envelopeId).firstOrNull;
    if (env == null) {
      return const SizedBox(height: 240, child: UnicornCarregando(texto: 'Abrindo o envelope…'));
    }
    final gasto = ref.watch(gastosPorEnvelopeNoMesProvider)[envelopeId] ?? 0.0;
    final e = EstadoEnvelope(env, gastoMes: gasto);
    final transacoes = ref.watch(transacoesDoEnvelopeProvider(envelopeId));

    void trocar(Widget sheet) {
      final nav = Navigator.of(context);
      nav.pop();
      abrirSheet(nav.context, sheet);
    }

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NBSpacing.margemTela),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(e.emoji ?? '📦', style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: NBSpacing.s),
                    Expanded(child: Text(e.nome, style: NBText.tituloTela.copyWith(fontSize: 24))),
                    IconButton(
                      tooltip: 'Editar envelope',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => trocar(SheetEnvelope(envelope: env)),
                    ),
                  ],
                ),
                const SizedBox(height: NBSpacing.s),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Saldo', style: NBText.legenda),
                          Text(brl(e.saldo),
                              style: NBText.saldo.copyWith(
                                  fontSize: 34, color: e.estourado ? NBColors.estouro : NBColors.tinta)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Despesas do mês', style: NBText.legenda),
                        Text(brl(gasto), style: NBText.corpo.copyWith(fontWeight: FontWeight.w700)),
                        if (e.planejado > 0) Text('de ${brl(e.planejado, curto: true)}', style: NBText.legenda),
                      ],
                    ),
                  ],
                ),
                if (e.natureza == NaturezaEnvelope.consumo && e.planejado > 0) ...[
                  const SizedBox(height: NBSpacing.s),
                  BarraProgresso(
                    fracao: e.fracaoGasta,
                    cor: e.estourado ? NBColors.estouro : (e.noLimite ? NBColors.ambarBarra : NBColors.verde),
                  ),
                ],
                const SizedBox(height: NBSpacing.l),
                Row(
                  children: [
                    Expanded(
                      child: _Acao(Icons.tune_rounded, 'Orçamento', () => trocar(const SheetPlanejarMes())),
                    ),
                    const SizedBox(width: NBSpacing.s),
                    Expanded(
                      child: _Acao(Icons.remove_rounded, 'Compra', () => trocar(SheetCompra(envelopeInicial: envelopeId))),
                    ),
                    const SizedBox(width: NBSpacing.s),
                    Expanded(
                      child: _Acao(
                        Icons.swap_horiz_rounded,
                        'Transferir',
                        () => trocar(e.estourado
                            ? SheetRemanejar(destinoId: envelopeId)
                            : SheetRemanejar(origemId: envelopeId)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: NBSpacing.l),
                Text('Lançamentos', style: NBText.secao),
                const SizedBox(height: NBSpacing.s),
              ],
            ),
          ),
          Expanded(
            child: transacoes.when(
              loading: () => const UnicornCarregando(texto: 'Buscando lançamentos…'),
              error: (err, _) => UnicornErro(
                mensagem: 'Não consegui carregar os lançamentos.',
                onTentar: () => ref.invalidate(transacoesDoEnvelopeProvider(envelopeId)),
              ),
              data: (lista) => lista.isEmpty
                  ? const UnicornVazio(titulo: 'Nenhum lançamento ainda', texto: 'Os gastos deste envelope aparecem aqui.')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 0, NBSpacing.margemTela, NBSpacing.xxl),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final t = lista[i];
                        return Dismissible(
                          key: ValueKey(t['id']),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _excluir(context, ref, t),
                          background: Container(
                            color: NBColors.estouroClaro,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: NBSpacing.xl),
                            child: const Icon(Icons.delete_outline_rounded, color: NBColors.estouro),
                          ),
                          child: _LinhaTransacao(t: t),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Acao extends StatelessWidget {
  const _Acao(this.icone, this.rotulo, this.onTap);
  final IconData icone;
  final String rotulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 8)),
        icon: Icon(icone, size: 18),
        label: Text(rotulo, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
}

class _LinhaTransacao extends StatelessWidget {
  const _LinhaTransacao({required this.t});
  final Map<String, dynamic> t;

  @override
  Widget build(BuildContext context) {
    final valor = (t['valor'] as num?)?.toDouble() ?? 0;
    final tipo = t['tipo'] as String? ?? '';
    final entra = tipo == 'abastecimento' || tipo == 'receita';
    final data = DateTime.tryParse(t['created_at']?.toString() ?? '')?.toLocal();
    final rotuloTipo = switch (tipo) {
      'abastecimento' => 'Abastecimento',
      'despesa_fixa' => 'Conta fixa',
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NBSpacing.s),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['descricao'] as String? ?? rotuloTipo ?? 'Gasto',
                    style: NBText.corpo.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  [if (data != null) DateFormat("d MMM · HH:mm", 'pt_BR').format(data), if (rotuloTipo != null) rotuloTipo]
                      .join(' · '),
                  style: NBText.legenda,
                ),
              ],
            ),
          ),
          Text(entra ? brl(valor, sinal: true) : brl(-valor),
              style: NBText.corpo.copyWith(fontWeight: FontWeight.w700, color: entra ? NBColors.verde : NBColors.tinta)),
        ],
      ),
    );
  }
}
