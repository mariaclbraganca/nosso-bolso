import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/contas_provider.dart';
import '../../../core/providers/fixos_provider.dart';
import '../../../core/providers/mes_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/financeiro_ext_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';
import '../sheets/comum.dart';
import 'widgets/contas_card.dart';
import 'widgets/fixos_card.dart';
import 'widgets/form_conta_sheet.dart';
import 'widgets/form_fixo_sheet.dart';
import 'widgets/plano_sheets.dart';
import '../../../core/providers/plano_provider.dart';

/// Boleto do mês seguinte para uma conta recorrente (mesmo dia, limitado
/// ao último dia do mês: 31/01 → 28/02). Null se já existe um com o mesmo nome.
Map<String, dynamic>? proximoBoletoRecorrente(Map<String, dynamic> conta, List<Map<String, dynamic>> contasMesSeguinte) {
  if (conta['recorrente'] != true) return null;
  final venc = DateTime.tryParse(conta['vencimento'] as String? ?? '');
  if (venc == null) return null;
  if (contasMesSeguinte.any((c) => c['nome'] == conta['nome'])) return null;
  final ultimoDia = DateTime(venc.year, venc.month + 2, 0).day;
  final prox = DateTime(venc.year, venc.month + 1, venc.day > ultimoDia ? ultimoDia : venc.day);
  return {
    'familia_id': conta['familia_id'],
    'nome': conta['nome'],
    'valor': conta['valor'],
    'categoria': conta['categoria'] ?? 'outro',
    'vencimento': '${prox.year}-${prox.month.toString().padLeft(2, '0')}-${prox.day.toString().padLeft(2, '0')}',
    'observacao': conta['observacao'] ?? '',
    'recorrente': true,
  };
}

/// Dia do mês em que a conta vence (fixo: dia_vencimento; boleto: data).
int diaDaConta(Map<String, dynamic> c) => c['origem'] == 'fixo'
    ? (c['dia_vencimento'] as int?) ?? 99
    : DateTime.tryParse(c['vencimento'] as String? ?? '')?.day ?? 99;

/// Fixos e boletos numa lista só: pendentes primeiro, por dia de vencimento.
List<Map<String, dynamic>> juntarContas(List<Map<String, dynamic>> fixos, List<Map<String, dynamic>> boletos) {
  final todas = [
    for (final f in fixos) {...f, 'origem': 'fixo'},
    for (final b in boletos) {...b, 'origem': 'boleto'},
  ];
  todas.sort((a, b) {
    final pa = a['pago'] == true ? 1 : 0, pb = b['pago'] == true ? 1 : 0;
    return pa != pb ? pa - pb : diaDaConta(a).compareTo(diaDaConta(b));
  });
  return todas;
}

/// Contas do mês: gastos fixos (Supabase) e boletos (com data e código) juntos.
class ContasTab extends ConsumerWidget {
  const ContasTab({super.key});

  void _recarregarBoletos(WidgetRef ref) {
    final mes = ref.read(mesAtualProvider);
    ref.invalidate(contasMesProvider(mes));
    ref.invalidate(resumoContasProvider(mes));
  }

  Future<void> _pagarBoleto(WidgetRef ref, Map<String, dynamic> conta, bool pago) async {
    final id = idMongo(conta);
    try {
      await FinanceiroExtService.marcarPaga(id, pago: pago);
      if (pago && conta['recorrente'] == true) await _lancarProximo(conta);
      if (pago) NotificationService.cancelarAlertaConta((id.hashCode).abs() % 100000);
      _recarregarBoletos(ref);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    }
  }

  Future<void> _lancarProximo(Map<String, dynamic> conta) async {
    final venc = DateTime.tryParse(conta['vencimento'] as String? ?? '');
    final familiaId = conta['familia_id'] as String?;
    if (venc == null || familiaId == null) return;
    final proxMes = DateTime(venc.year, venc.month + 1);
    final mes = '${proxMes.year}-${proxMes.month.toString().padLeft(2, '0')}';
    try {
      final existentes = await FinanceiroExtService.getContas(familiaId, mes: mes);
      final novo = proximoBoletoRecorrente(conta, existentes);
      if (novo == null) return;
      await FinanceiroExtService.criarConta(novo);
      avisar('Próximo ${conta['nome']} já lançado para ${novo['vencimento'].toString().substring(8)}/${novo['vencimento'].toString().substring(5, 7)}.');
    } catch (e) {
      avisar('Pago, mas não consegui lançar o próximo: ${mensagemErro(e)}', erro: true);
    }
  }

  /// Pagar um fixo gera a despesa no backend, que recusa se o saldo geral não cobre.
  Future<void> _pagarFixo(WidgetRef ref, String id, bool pago) async {
    try {
      await ApiService.patch('/fixos/$id', {'pago': pago});
      if (pago) NotificationService.cancelarAlertasFixo(id);
    } catch (e) {
      final msg = mensagemErro(e);
      if (msg.toLowerCase().contains('saldo')) {
        ref.geronimo('Sem saldo geral para pagar. Lance o resgate da reserva (ou a receita) antes.');
      } else {
        avisar(msg, erro: true);
      }
    }
  }

  Future<bool> _confirmarExclusao(BuildContext context, String nome) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: NBColors.cartao,
          title: const Text('Excluir conta', style: TextStyle(color: NBColors.tinta)),
          content: Text('Deseja excluir "$nome"?', style: NBText.corpo),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir', style: TextStyle(color: NBColors.estouro)),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _excluir(BuildContext context, WidgetRef ref, Map<String, dynamic> c) async {
    if (!await _confirmarExclusao(context, c['nome'] as String? ?? '')) return;
    try {
      if (c['origem'] == 'fixo') {
        await ApiService.delete('/fixos/${c['id']}');
      } else {
        await FinanceiroExtService.deletarConta(idMongo(c));
        _recarregarBoletos(ref);
      }
      avisar('Conta excluída.');
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    }
  }

  Future<void> _abrir(BuildContext context, WidgetRef ref, Widget sheet) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NBColors.cartao,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => sheet,
    );
    _recarregarBoletos(ref);
  }

  /// Um botão só: conta mensal (só o dia) ou boleto (data e código de barras).
  Future<void> _novaConta(BuildContext context, WidgetRef ref) async {
    final tipo = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: TopoSheet(titulo: 'Nova conta')),
            ListTile(
              leading: const Icon(Icons.event_repeat_rounded),
              title: const Text('Conta recorrente'),
              subtitle: const Text('Aluguel, Unimed, faculdade… só o dia do vencimento'),
              onTap: () => Navigator.pop(ctx, 'fixo'),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded),
              title: const Text('Boleto avulso'),
              subtitle: const Text('Com data, categoria e código de barras ou PIX para copiar'),
              onTap: () => Navigator.pop(ctx, 'boleto'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (tipo == null || !context.mounted) return;
    await _abrir(context, ref, tipo == 'fixo' ? const FormFixoSheet() : const FormContaSheet());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesAtualProvider);
    final boletos = ref.watch(contasMesProvider(mes));
    final contas = juntarContas(ref.watch(fixosMesAtualProvider), boletos.valueOrNull ?? const []);
    double soma(Iterable<Map<String, dynamic>> l) => l.fold(0.0, (s, c) => s + ((c['valor'] as num?)?.toDouble() ?? 0));
    final total = soma(contas);
    final pendente = soma(contas.where((c) => c['pago'] != true));

    return ListView(
      padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 12, NBSpacing.margemTela, 120),
      children: [
        CartaoNB(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CONTAS A PAGAR', style: NBText.eyebrow),
                    const SizedBox(height: 4),
                    Text(brl(total), style: NBText.valorCartao),
                    Text('${contas.where((c) => c['pago'] == true).length} de ${contas.length} pagas', style: NBText.legenda),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Falta pagar', style: NBText.legenda),
                  Text(brl(pendente),
                      style: NBText.valorCartao.copyWith(color: pendente > 0 ? NBColors.estouro : NBColors.verde, fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
        if (boletos.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Não consegui carregar os boletos agora; mostrando só as contas mensais.', style: NBText.legenda),
          ),
        const SizedBox(height: NBSpacing.l),
        if (contas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: UnicornVazio(
              type: UnicornType.geronimo,
              titulo: 'Nenhuma conta neste mês',
              texto: 'Cadastre as contas para receber lembretes antes de vencer.',
            ),
          )
        else
          for (final c in contas)
            c['origem'] == 'fixo'
                ? FixosCard(
                    fixo: c,
                    selecionado: false,
                    modoSelecao: false,
                    onTogglePago: (v) => _pagarFixo(ref, c['id'] as String, v ?? false),
                    onTap: () => _pagarFixo(ref, c['id'] as String, c['pago'] != true),
                    onLongPress: () => _abrir(context, ref, FormFixoSheet(fixoParaEditar: c)),
                    onEditar: () => _abrir(context, ref, FormFixoSheet(fixoParaEditar: c)),
                    onExcluir: () => _excluir(context, ref, c),
                  )
                : ContasCard(
                    conta: c,
                    onTogglePago: (v) => _pagarBoleto(ref, c, v),
                    onExcluir: () => _excluir(context, ref, c),
                  ),
        const SizedBox(height: NBSpacing.m),
        BotaoSecundario(rotulo: '+ Nova conta', onPressed: () => _novaConta(context, ref)),
        const SizedBox(height: NBSpacing.xl),
        const FaturaEmFormacao(),
      ],
    );
  }
}

/// Fatura do cartão que vence dia 7 do mês seguinte, calculada a cada compra:
/// lançamentos futuros (parcelas e assinaturas) + compras no crédito do mês.
class FaturaEmFormacao extends ConsumerWidget {
  const FaturaEmFormacao({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(limiteMesProvider).valueOrNull;
    if (l == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Fatura em formação', style: NBText.secao),
        const SizedBox(height: NBSpacing.s),
        Container(
          padding: const EdgeInsets.all(NBSpacing.l),
          decoration: BoxDecoration(color: NBColors.reservaClaro, borderRadius: BorderRadius.circular(NBRadius.cartao)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('Fatura Nubank · vence 7/${l.mesFatura.substring(5)}', style: NBText.rotulo)),
                Text(brl(l.faturaEmFormacao), style: NBText.valorCartao.copyWith(fontSize: 18)),
              ]),
              const SizedBox(height: 4),
              Text(
                'Calculada: lançamentos futuros ${brl(l.lancamentosFuturos)} + compras no crédito ${brl(l.comprasNoCredito)}. '
                'Atualiza a cada compra.',
                style: NBText.legenda,
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompromissosScreen())),
                child: const Text('Ver lançamentos futuros'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
