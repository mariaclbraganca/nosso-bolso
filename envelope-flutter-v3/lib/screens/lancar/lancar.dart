import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/plano/falas.dart';
import '../../core/plano/plano_mes.dart';
import '../../core/providers/compras_provider.dart';
import '../../core/providers/envelopes_provider.dart';
import '../../core/providers/mes_provider.dart';
import '../../core/providers/plano_provider.dart';
import '../../core/providers/transacoes_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/moeda.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../compras/nfce_fluxo.dart';
import '../compras/widgets/compras_pendente_card.dart';
import '../compras/widgets/inserir_url_dialog.dart';
import '../compras/widgets/qr_scanner_sheet.dart';
import '../sheets/comum.dart';

/// Botão "+ Lançar": compra (digitada ou pela nota fiscal), compras
/// capturadas a confirmar e receita.
Future<void> abrirNovoLancamento(BuildContext context) => abrirSheet(context, const SheetNovoLancamento());

class SheetNovoLancamento extends ConsumerStatefulWidget {
  const SheetNovoLancamento({super.key});

  @override
  ConsumerState<SheetNovoLancamento> createState() => _SheetNovoLancamentoState();
}

class _SheetNovoLancamentoState extends ConsumerState<SheetNovoLancamento> {
  String _etapa = '';

  void _ir(Widget folha) {
    final nav = Navigator.of(context);
    nav.pop();
    abrirSheet(nav.context, folha);
  }

  /// A nota vira uma compra a confirmar logo abaixo (a sheet continua aberta).
  Future<void> _processar(String url) async {
    if (_etapa.isNotEmpty) return;
    await processarNota(ref, url, onEtapa: (e) {
      if (mounted) setState(() => _etapa = e);
    });
    if (mounted) setState(() => _etapa = '');
  }

  void _escanear() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => QrScannerSheet(onCodeScanned: _processar),
      );

  Future<void> _colarLink() async {
    final url = await showDialog<String>(context: context, builder: (_) => const InserirUrlDialog());
    if (url != null) await _processar(url);
  }

  @override
  Widget build(BuildContext context) {
    final pendentes = ref.watch(comprasPendentesProvider).valueOrNull ?? const [];
    return CascaSheet(
      filhos: [
        const TopoSheet(titulo: 'Novo lançamento'),
        const SizedBox(height: NBSpacing.l),
        Row(
          children: [
            Expanded(
              child: _OpcaoLancamento(
                icone: Icons.south_rounded,
                cor: NBColors.estouro,
                fundo: NBColors.estouroClaro,
                titulo: 'Compra',
                texto: 'Cartão, Pix ou vale-alimentação',
                onTap: () => _ir(const SheetCompra()),
              ),
            ),
            const SizedBox(width: NBSpacing.m),
            Expanded(
              child: _OpcaoLancamento(
                icone: Icons.north_rounded,
                cor: NBColors.verdeProfundo,
                fundo: NBColors.verdeClaro,
                titulo: 'Receita',
                texto: 'Salário, aluguel ou trabalho de alguém da casa',
                onTap: () => _ir(const SheetReceita()),
              ),
            ),
          ],
        ),
        const SizedBox(height: NBSpacing.s),
        Wrap(spacing: 4, children: [
          TextButton.icon(
            onPressed: _escanear,
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
            label: const Text('Escanear nota fiscal'),
          ),
          TextButton.icon(
            onPressed: _colarLink,
            icon: const Icon(Icons.link_rounded, size: 20),
            label: const Text('Link da NFC-e'),
          ),
        ]),
        if (_etapa.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
              const SizedBox(width: NBSpacing.m),
              Expanded(child: Text(_etapa, style: NBText.corpo)),
            ]),
          ),
        if (pendentes.isNotEmpty) ...[
          const SizedBox(height: NBSpacing.m),
          Text('COMPRAS A CONFIRMAR', style: NBText.eyebrow),
          Text('Chegaram pelo Nubank ou pela nota fiscal; falta escolher o envelope.', style: NBText.legenda),
          const SizedBox(height: 4),
          for (final c in pendentes) ComprasPendenteCard(compra: c),
        ],
      ],
      botao: BotaoSecundario(rotulo: 'Cancelar', onPressed: () => Navigator.pop(context)),
    );
  }
}

class _OpcaoLancamento extends StatelessWidget {
  const _OpcaoLancamento({
    required this.icone,
    required this.cor,
    required this.fundo,
    required this.titulo,
    required this.texto,
    required this.onTap,
  });
  final IconData icone;
  final Color cor;
  final Color fundo;
  final String titulo;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: NBColors.papel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: NBColors.linha),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(NBSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icone, color: cor),
                ),
                const SizedBox(height: NBSpacing.s),
                Text(titulo, style: NBText.secao),
                Text(texto, style: NBText.legenda),
              ],
            ),
          ),
        ),
      );
}

/// Uma linha "Agora → Depois" da prévia.
typedef LinhaPrevia2 = ({String rotulo, double agora, double depois});

/// Prévia do efeito de um lançamento: Agora × Depois, alerta e parcelas.
class PreviaImpacto extends StatelessWidget {
  const PreviaImpacto({super.key, required this.titulo, required this.linhas, this.alerta, this.parcelas, this.nota});
  final String titulo;
  final List<LinhaPrevia2> linhas;
  final String? alerta;
  final ({int total, double valor, List<String> meses})? parcelas;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    TextStyle num0(double v, {bool forte = false}) => NBText.corpo.copyWith(
          fontSize: 14,
          fontWeight: forte ? FontWeight.w700 : FontWeight.w400,
          color: v < 0 ? NBColors.estouro : (forte ? NBColors.tinta : NBColors.tintaSuave),
          decoration: forte ? null : TextDecoration.lineThrough,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    return Container(
      padding: const EdgeInsets.all(NBSpacing.m),
      decoration: BoxDecoration(color: NBColors.papel, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: NBText.rotulo),
          const SizedBox(height: 6),
          Row(children: [
            const Expanded(child: SizedBox()),
            SizedBox(width: 104, child: Text('AGORA', style: NBText.eyebrow, textAlign: TextAlign.right)),
            SizedBox(width: 104, child: Text('DEPOIS', style: NBText.eyebrow, textAlign: TextAlign.right)),
          ]),
          for (final l in linhas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text(l.rotulo, style: NBText.corpo.copyWith(fontSize: 14))),
                SizedBox(width: 104, child: Text(brl(l.agora), style: num0(l.agora), textAlign: TextAlign.right)),
                SizedBox(width: 104, child: Text(brl(l.depois), style: num0(l.depois, forte: true), textAlign: TextAlign.right)),
              ]),
            ),
          if (alerta != null)
            Container(
              margin: const EdgeInsets.only(top: NBSpacing.s),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: NBColors.estouroClaro, borderRadius: BorderRadius.circular(8)),
              child: Text(alerta!, style: NBText.rotulo.copyWith(fontSize: 13, color: NBColors.estouro)),
            ),
          if (parcelas case final p?) ...[
            const Divider(height: NBSpacing.xl),
            Text('Parcelamento: ${p.total}x de ${brl(p.valor)} (total ${brl(p.valor * p.total)})', style: NBText.rotulo),
            const SizedBox(height: 6),
            Wrap(spacing: 5, runSpacing: 5, children: [
              for (var k = 0; k < p.meses.length; k++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: k == 0 ? NBColors.verde : NBColors.reservaClaro,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(children: [
                    Text('${k + 1}/${p.total}', style: TextStyle(fontSize: 10, color: k == 0 ? Colors.white : NBColors.reserva)),
                    Text(p.meses[k], style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: k == 0 ? Colors.white : NBColors.reserva)),
                  ]),
                ),
            ]),
            const SizedBox(height: 6),
            Text(
              'Fatura em que cada parcela vence (dia 7). A 1ª entra no orçamento deste mês; '
              'as outras ${p.total - 1} reduzem o limite de compras dos meses seguintes.',
              style: NBText.legenda,
            ),
          ],
          if (nota != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(nota!, style: NBText.legenda)),
        ],
      ),
    );
  }
}

const _abvMes = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
String abvMes(String mes) => _abvMes[int.parse(mes.substring(5, 7)) - 1];

/// Compra: lançamento manual ou confirmação de uma captura do Nubank
/// ([captura] = documento pendente). Pergunta se foi parcelada.
class SheetCompra extends ConsumerStatefulWidget {
  const SheetCompra({super.key, this.captura, this.envelopeInicial});
  final Map<String, dynamic>? captura;
  final String? envelopeInicial;

  @override
  ConsumerState<SheetCompra> createState() => _SheetCompraState();
}

class _SheetCompraState extends ConsumerState<SheetCompra> {
  late final _valor = TextEditingController(
      text: widget.captura == null ? '' : brl((widget.captura!['valor_total'] as num).toDouble()).replaceAll(RegExp(r'[^\d,.]'), ''));
  late final _descricao = TextEditingController(text: widget.captura?['supermercado'] as String?);
  late String _forma = widget.captura?['tipo_notificacao'] == 'pix_enviado' ? 'pix' : 'credito';
  String? _envelopeId;
  int _parcelas = 1;
  bool _salvando = false;

  static const _formas = {'credito': 'Crédito', 'pix': 'Pix/Débito', 'va': 'Vale-alimentação'};

  @override
  void initState() {
    super.initState();
    _envelopeId = widget.captura?['envelope_id'] as String? ?? widget.envelopeInicial;
  }

  @override
  void dispose() {
    _valor.dispose();
    _descricao.dispose();
    super.dispose();
  }

  double get _total => parseMoeda(_valor.text);
  int get _n => _forma == 'credito' ? _parcelas : 1;
  double get _valorMes => valorParcela(_total, _n);

  Map<String, dynamic>? _envelopeVa(List<Map<String, dynamic>> envs) => envs.where(ehEnvelopeVa).firstOrNull;

  Future<void> _salvar() async {
    final envs = ref.read(envelopesViseisProvider);
    final envId = _forma == 'va' ? (_envelopeVa(envs)?['id'] as String?) : _envelopeId;
    if (_total <= 0) return avisar('Informe o valor da compra.', erro: true);
    if (envId == null) {
      return avisar(_forma == 'va' ? 'Crie o envelope "Vale Alimentação" para lançar compras no VA.' : 'Escolha o envelope da compra.',
          erro: true);
    }
    final p = perfilOuErro(ref);
    final mes = ref.read(mesAtualProvider);
    final desc = _descricao.text.trim();
    final fala = falaDaCompra(
      l: ref.read(limiteMesProvider).valueOrNull,
      envelope: envs.where((e) => e['id'] == envId).firstOrNull,
      valor: _valorMes,
      forma: _forma,
    );
    setState(() => _salvando = true);
    try {
      if (widget.captura != null) {
        await ApiService.post('/api/v1/compras/confirmar', {
          'compra_id': widget.captura!['compra_id'],
          'envelope_id': envId,
          'familia_id': p['familia_id'],
          'usuario_id': p['id'],
          'parcelas': _n,
        });
        ref.invalidate(comprasPendentesProvider);
      } else {
        await ApiService.post('/transacoes/', {
          'valor': _valorMes,
          'tipo': 'despesa',
          'envelope_id': envId,
          'usuario_id': p['id'],
          'familia_id': p['familia_id'],
          'descricao': _n > 1 ? '${desc.isEmpty ? 'Compra parcelada' : desc} · 1/$_n' : (desc.isEmpty ? null : desc),
          'forma_pagamento': _forma,
        });
        if (_n > 1) {
          await ApiService.post('/plano/cartao', compromissoDaParcelada(
            familiaId: p['familia_id'] as String,
            descricao: desc.isEmpty ? 'Compra parcelada' : desc,
            valorTotal: _total,
            parcelas: _n,
            mes: mes,
          ));
        }
      }
      if (_n > 1) ref.invalidate(compromissosCartaoProvider);
      ref.invalidate(transacoesStreamProvider);
      HapticFeedback.mediumImpact();
      avisar(_n > 1 ? 'Compra em ${_n}x lançada: ${brl(_valorMes)} neste mês.' : 'Compra de ${brl(_valorMes)} lançada.');
      falar(ref, fala);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget? _previa(LimiteMes? l, List<Map<String, dynamic>> envs) {
    if (l == null || _total <= 0) return null;
    final v = _valorMes;
    if (_forma == 'va') {
      final d = l.disponivelVa;
      return PreviaImpacto(
        titulo: 'Efeito desta compra',
        linhas: [(rotulo: 'Vale-alimentação disponível', agora: d, depois: d - v)],
        alerta: d - v < 0 ? 'O vale-alimentação não cobre esta compra: faltam ${brl(v - d)}.' : null,
      );
    }
    // Captura do Nubank já desconta como "pendente de envelope": tira ela antes.
    final jaContada = widget.captura == null ? 0.0 : (widget.captura!['valor_total'] as num).toDouble();
    final agora = l.podeGastar + jaContada;
    final env = l.envelopes.where((e) => e['id'] == _envelopeId).firstOrNull;
    final dispEnv = env == null ? null : l.disponivelDe(env);
    return PreviaImpacto(
      titulo: _n > 1 ? 'Efeito desta compra neste mês' : 'Efeito desta compra',
      linhas: [
        (rotulo: 'Pode gastar ainda no mês', agora: agora, depois: agora - v),
        if (env != null) (rotulo: 'Envelope ${env['nome_envelope']}', agora: dispEnv!, depois: dispEnv - v),
        if (_forma == 'credito') (rotulo: 'Fatura de 7/${abvMes(l.mesFatura)}', agora: l.faturaEmFormacao, depois: l.faturaEmFormacao + v),
      ],
      alerta: dispEnv != null && dispEnv - v < 0 ? '${env!['nome_envelope']} fica ${brl(v - dispEnv)} acima do orçado.' : null,
      parcelas: _n > 1 ? (total: _n, valor: v, meses: [for (var k = 1; k <= _n; k++) abvMes(somarMeses(l.mes, k))]) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final envs = ref.watch(envelopesViseisProvider).where((e) => e['is_reserva'] != true && !ehEnvelopeVa(e)).toList();
    final previa = _previa(ref.watch(limiteMesProvider).valueOrNull, envs);
    final captura = widget.captura != null;
    return CascaSheet(
      filhos: [
        TopoSheet(
          titulo: captura ? 'Confirmar compra' : 'Registrar compra',
          subtitulo: captura ? 'Capturada do Nubank. Escolha o envelope e se foi parcelada.' : null,
        ),
        const SizedBox(height: NBSpacing.l),
        CampoValor(controller: _valor, rotulo: 'VALOR TOTAL DA COMPRA', autofocus: !captura, onChanged: (_) => setState(() {})),
        const SizedBox(height: NBSpacing.m),
        TextField(
          controller: _descricao,
          readOnly: captura,
          decoration: const InputDecoration(labelText: 'DESCRIÇÃO', hintText: 'Ex.: Supermercado Tático'),
        ),
        const SizedBox(height: NBSpacing.l),
        Text('FORMA DE PAGAMENTO', style: NBText.eyebrow),
        const SizedBox(height: 6),
        Segmentado<String>(opcoes: _formas, valor: _forma, onChanged: (f) => setState(() => _forma = f)),
        if (_forma == 'credito') ...[
          const SizedBox(height: NBSpacing.l),
          Text('ESTA COMPRA FOI PARCELADA?', style: NBText.eyebrow),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            initialValue: _parcelas,
            items: [
              const DropdownMenuItem(value: 1, child: Text('À vista')),
              for (var n = 2; n <= 12; n++) DropdownMenuItem(value: n, child: Text('Parcelada em ${n}x')),
            ],
            onChanged: (n) => setState(() => _parcelas = n ?? 1),
          ),
        ],
        if (_forma != 'va') ...[
          const SizedBox(height: NBSpacing.l),
          Text('ENVELOPE', style: NBText.eyebrow),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in envs)
              ChipNB(
                rotulo: e['nome_envelope'] as String? ?? '',
                selecionado: _envelopeId == e['id'],
                onTap: () => setState(() => _envelopeId = e['id'] as String),
              ),
          ]),
        ],
        if (previa != null) ...[const SizedBox(height: NBSpacing.l), previa],
      ],
      botao: BotaoPrincipal(rotulo: captura ? 'Confirmar compra' : 'Lançar compra', carregando: _salvando, onPressed: _salvar),
    );
  }
}

/// Receita: quem recebeu e para onde vai (orçamento do mês ou reserva).
class SheetReceita extends ConsumerStatefulWidget {
  const SheetReceita({super.key});

  @override
  ConsumerState<SheetReceita> createState() => _SheetReceitaState();
}

class _SheetReceitaState extends ConsumerState<SheetReceita> {
  final _valor = TextEditingController();
  final _descricao = TextEditingController();
  String _destino = 'mes';
  bool _salvando = false;

  @override
  void dispose() {
    _valor.dispose();
    _descricao.dispose();
    super.dispose();
  }

  double get _v => parseMoeda(_valor.text);

  Future<void> _salvar() async {
    if (_v <= 0) return avisar('Informe o valor recebido.', erro: true);
    final p = perfilOuErro(ref);
    final mes = ref.read(mesAtualProvider);
    final desc = _descricao.text.trim().isEmpty ? 'Receita' : _descricao.text.trim();
    final quem = (p['nome'] as String? ?? '').split(' ').first; // quem está logado
    setState(() => _salvando = true);
    try {
      await ApiService.post('/plano/entradas', {
        'familia_id': p['familia_id'],
        'mes': mes,
        'nome': desc,
        'valor': _v,
        'tipo': 'eventual',
        'recorrente': false,
        'recebido': true,
        'quem': quem,
        'destino': _destino,
      });
      // No orçamento do mês o dinheiro entra na conta; na reserva, fica fora.
      if (_destino == 'mes') {
        await ApiService.post('/transacoes/receita', {
          'valor': _v,
          'usuario_id': p['id'],
          'familia_id': p['familia_id'],
          'descricao': '$desc · $quem',
        });
        ref.invalidate(transacoesStreamProvider);
      }
      ref.invalidate(entradasMesProvider(mes));
      HapticFeedback.mediumImpact();
      falar(ref, falaDaReceita(_v, _destino));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(limiteMesProvider).valueOrNull;

    return CascaSheet(
      filhos: [
        const TopoSheet(titulo: 'Registrar receita'),
        const SizedBox(height: NBSpacing.l),
        CampoValor(controller: _valor, rotulo: 'VALOR RECEBIDO', autofocus: true, onChanged: (_) => setState(() {})),
        const SizedBox(height: NBSpacing.m),
        TextField(
          controller: _descricao,
          decoration: const InputDecoration(labelText: 'DESCRIÇÃO', hintText: 'Ex.: Serviço de pintura, Aluguel da casa'),
        ),
        const SizedBox(height: NBSpacing.l),
        Text('DESTINO DO DINHEIRO', style: NBText.eyebrow),
        const SizedBox(height: 6),
        Segmentado<String>(
          opcoes: const {'mes': 'Orçamento do mês', 'reserva': 'Guardar na reserva'},
          valor: _destino,
          onChanged: (d) => setState(() => _destino = d),
        ),
        if (l != null && _v > 0) ...[
          const SizedBox(height: NBSpacing.l),
          _destino == 'mes'
              ? PreviaImpacto(
                  titulo: 'Efeito desta receita',
                  linhas: [
                    (
                      rotulo: 'Vai sair da reserva até o salário',
                      agora: l.vaiSairDaReserva,
                      depois: l.vaiSairDaReserva - (_v < l.faltaCaixa ? _v : l.faltaCaixa),
                    ),
                  ],
                  nota: 'Entra no caixa do mês: ajuda a pagar as contas e reduz o que sai da reserva.',
                )
              : PreviaImpacto(
                  titulo: 'Efeito desta receita',
                  linhas: [(rotulo: 'Guardado na reserva neste mês', agora: l.guardadoNaReserva, depois: l.guardadoNaReserva + _v)],
                  nota: 'Não muda o limite do mês. Ajuda a repor o que saiu da reserva.',
                ),
        ],
      ],
      botao: BotaoPrincipal(rotulo: 'Lançar receita', carregando: _salvando, onPressed: _salvar),
    );
  }
}
