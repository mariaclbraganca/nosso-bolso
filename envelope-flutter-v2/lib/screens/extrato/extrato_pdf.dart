import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../constants.dart';
import '../../providers/usuarios_provider.dart';
import '../../providers/mes_provider.dart';
import '../../services/gemini_key_service.dart';
import '../../utils/extrato_calculos.dart';

// ─── Modelo da análise IA ──────────────────────────────────────────────────────

class AnaliseIA {
  final String status;
  final String titulo;
  final List<InsightIA> insights;
  final String? projecaoMes;
  final List<String> acoesRecomendadas;

  const AnaliseIA({
    required this.status,
    required this.titulo,
    required this.insights,
    this.projecaoMes,
    required this.acoesRecomendadas,
  });

  factory AnaliseIA.fromJson(Map<String, dynamic> j) => AnaliseIA(
    status: j['status'] as String? ?? 'ok',
    titulo: j['titulo'] as String? ?? '',
    insights: (j['insights'] as List? ?? [])
        .map((i) => InsightIA.fromJson(i as Map<String, dynamic>))
        .toList(),
    projecaoMes: j['projecao_mes'] as String?,
    acoesRecomendadas: List<String>.from(j['acoes_recomendadas'] as List? ?? []),
  );
}

class InsightIA {
  final String categoria;
  final String tipo;
  final String mensagem;
  const InsightIA({required this.categoria, required this.tipo, required this.mensagem});
  factory InsightIA.fromJson(Map<String, dynamic> j) => InsightIA(
    categoria: j['categoria'] as String? ?? '',
    tipo: j['tipo'] as String? ?? 'neutro',
    mensagem: j['mensagem'] as String? ?? '',
  );
}

// ─── Funções públicas de exportação ───────────────────────────────────────────

Future<List<Map<String, dynamic>>> buscarTransacoesExtrato(
  WidgetRef ref,
  String mes,
) async {
  final familiaId = ref.read(perfilUsuarioLogadoProvider).value?['familia_id'];
  if (familiaId == null) throw 'Família não encontrada.';

  final dataInicio = '$mes-01';
  final parts = mes.split('-');
  final ano = int.parse(parts[0]);
  final mNum = int.parse(parts[1]);
  final ultimoDia = DateTime(ano, mNum + 1, 0).day;
  final dataFim = '$mes-${ultimoDia.toString().padLeft(2, '0')}';

  final rows = await supabase
      .from('transacoes')
      .select('data, tipo, descricao, valor, envelopes(nome_envelope), usuarios(nome)')
      .eq('familia_id', familiaId)
      .gte('data', dataInicio)
      .lte('data', dataFim)
      .isFilter('deleted_at', null)
      .order('data', ascending: true);

  return List<Map<String, dynamic>>.from(rows as List);
}

Future<void> exportarPdf(
  BuildContext context,
  WidgetRef ref,
  String mes,
) async {
  final messenger = ScaffoldMessenger.of(context);
  _snack(context, 'Buscando transacoes...');
  try {
    final rows = await buscarTransacoesExtrato(ref, mes);
    final fmt  = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final agora = DateTime.now();
    final mesLabel = mesLabelLongo(mes);

    final totais       = ExtratoCalculos.calcular(rows);
    final totalReceita = totais.totalReceita;
    final totalDespesa = totais.totalDespesa;
    final totalAbast   = totais.totalAbast;
    final porEnvelope  = totais.porEnvelope;
    final saldo        = totais.saldo;
    final pctDespesa   = ExtratoCalculos.pctComprometido(totalReceita, totalDespesa);
    final top5env      = ExtratoCalculos.topEnvelopes(porEnvelope);

    final rowsReceita = rows.where((t) => t['tipo'] == 'receita').toList();
    final rowsDespesa = rows.where((t) => t['tipo'] == 'despesa').toList();
    final rowsAbast   = rows.where((t) => t['tipo'] == 'abastecimento').toList();

    if (context.mounted) _snack(context, 'Analisando com IA...');
    AnaliseIA? analise;
    try {
      analise = await _analisarComGemini(
        mes: mes, mesLabel: mesLabel, rows: rows,
        totalReceita: totalReceita, totalDespesa: totalDespesa,
        totalAbast: totalAbast, saldo: saldo,
        porEnvelope: porEnvelope, fmt: fmt,
      );
    } catch (e) {
      debugPrint('PDF IA falhou: $e');
    }

    if (context.mounted) _snack(context, 'Montando PDF...');
    final doc = pw.Document();

    // ── Página 1: Capa ──────────────────────────────────────────────────────
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (ctx) => pw.Column(children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.fromLTRB(40, 40, 40, 32),
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1B2A0F)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('NOSSO BOLSO', style: pw.TextStyle(
              fontSize: 10, fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF9ED465), letterSpacing: 2,
            )),
            pw.SizedBox(height: 8),
            pw.Text('Relatorio Financeiro', style: pw.TextStyle(
              fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.white,
            )),
            pw.Text(mesLabel, style: pw.TextStyle(
              fontSize: 16, color: PdfColor.fromInt(0xFFBBD99A),
            )),
            pw.SizedBox(height: 16),
            pw.Text(
              'Gerado em ${DateFormat("dd/MM/yyyy 'as' HH:mm").format(agora)}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey400),
            ),
          ]),
        ),
        pw.Expanded(child: pw.Padding(
          padding: const pw.EdgeInsets.all(40),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(children: [
              _kpi('Receita Total', fmt.format(totalReceita), PdfColor.fromInt(0xFF2E7D32), icon: '+'),
              pw.SizedBox(width: 12),
              _kpi('Despesas', fmt.format(totalDespesa), PdfColor.fromInt(0xFFC62828), icon: '-'),
              pw.SizedBox(width: 12),
              _kpi('Saldo do Mes', fmt.format(saldo),
                  saldo >= 0 ? PdfColor.fromInt(0xFF1565C0) : PdfColor.fromInt(0xFFC62828),
                  icon: saldo >= 0 ? '=' : '!'),
            ]),
            pw.SizedBox(height: 20),
            pw.Text('Comprometimento da receita', style: pw.TextStyle(
              fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700,
            )),
            pw.SizedBox(height: 6),
            pw.Stack(children: [
              pw.Container(height: 14, decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
              )),
              pw.Container(
                height: 14,
                width: (PdfPageFormat.a4.width - 80) * (pctDespesa / 100).clamp(0.0, 1.0),
                decoration: pw.BoxDecoration(
                  color: pctDespesa > 90 ? PdfColor.fromInt(0xFFC62828)
                       : pctDespesa > 70 ? PdfColor.fromInt(0xFFE65100)
                       : PdfColor.fromInt(0xFF2E7D32),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
                ),
              ),
            ]),
            pw.SizedBox(height: 4),
            pw.Text('${pctDespesa.toStringAsFixed(1)}% da receita comprometida com despesas',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 24),
            pw.Text('Gastos por Categoria', style: pw.TextStyle(
              fontSize: 11, fontWeight: pw.FontWeight.bold,
            )),
            pw.SizedBox(height: 10),
            if (top5env.isNotEmpty) ...[
              ...top5env.map((e) {
                final pct = totalDespesa > 0 ? e.value / totalDespesa : 0.0;
                final barW = (PdfPageFormat.a4.width - 80 - 120) * pct;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(children: [
                    pw.SizedBox(width: 120, child: pw.Text(e.key,
                        style: const pw.TextStyle(fontSize: 9), maxLines: 1)),
                    pw.Expanded(child: pw.Stack(children: [
                      pw.Container(height: 10, decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                      )),
                      pw.Container(height: 10, width: barW.clamp(2, double.infinity),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFF4CAF50),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                        ),
                      ),
                    ])),
                    pw.SizedBox(width: 8),
                    pw.SizedBox(width: 80, child: pw.Text(fmt.format(e.value),
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.right)),
                    pw.SizedBox(width: 36, child: pw.Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        textAlign: pw.TextAlign.right)),
                  ]),
                );
              }),
            ],
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey200),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('${rows.length} transacoes registradas',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              pw.Text('Nosso Bolso - Relatorio de $mesLabel',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ]),
          ]),
        )),
      ]),
    ));

    // ── Página 2: Análise IA ────────────────────────────────────────────────
    if (analise != null) {
      final a = analise;
      final statusColor = a.status == 'alerta' ? PdfColor.fromInt(0xFFC62828)
          : a.status == 'atencao'              ? PdfColor.fromInt(0xFFE65100)
          :                                      PdfColor.fromInt(0xFF2E7D32);
      final statusLabel = a.status == 'alerta' ? 'ALERTA'
          : a.status == 'atencao'              ? 'ATENCAO'
          :                                      'SAUDAVEL';

      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Analise Inteligente', style: pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold,
              )),
              pw.Text('Gerada por Gemini AI com base nas transacoes de $mesLabel',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ])),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                color: statusColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(statusLabel, style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white,
              )),
            ),
          ]),
          pw.SizedBox(height: 6),
          pw.Text(a.titulo, style: pw.TextStyle(
            fontSize: 13, fontWeight: pw.FontWeight.bold, color: statusColor,
          )),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.SizedBox(height: 12),
          if (a.insights.isNotEmpty) ...[
            pw.Text('Pontos de Atencao', style: pw.TextStyle(
              fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800,
            )),
            pw.SizedBox(height: 8),
            ...a.insights.map((ins) {
              final cor = ins.tipo == 'positivo' ? PdfColor.fromInt(0xFF2E7D32)
                  : ins.tipo == 'negativo'       ? PdfColor.fromInt(0xFFC62828)
                  :                                PdfColor.fromInt(0xFF1565C0);
              final bullet = ins.tipo == 'positivo' ? 'OK'
                  : ins.tipo == 'negativo'           ? '!'
                  :                                    'i';
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Container(
                    width: 20, height: 20,
                    decoration: pw.BoxDecoration(color: cor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10))),
                    alignment: pw.Alignment.center,
                    child: pw.Text(bullet, style: pw.TextStyle(
                      fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white,
                    )),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(ins.categoria, style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold,
                    )),
                    pw.Text(ins.mensagem, style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700,
                    )),
                  ])),
                ]),
              );
            }),
            pw.SizedBox(height: 16),
          ],
          if (a.projecaoMes != null) ...[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Projecao para o fim do mes', style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold,
                )),
                pw.SizedBox(height: 4),
                pw.Text(a.projecaoMes!, style: const pw.TextStyle(fontSize: 9)),
              ]),
            ),
            pw.SizedBox(height: 12),
          ],
          if (a.acoesRecomendadas.isNotEmpty) ...[
            pw.Text('Recomendacoes para o proximo mes', style: pw.TextStyle(
              fontSize: 10, fontWeight: pw.FontWeight.bold,
            )),
            pw.SizedBox(height: 8),
            ...a.acoesRecomendadas.asMap().entries.map((e) =>
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('${e.key + 1}.  ', style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF4CAF50),
                  )),
                  pw.Expanded(child: pw.Text(e.value,
                      style: const pw.TextStyle(fontSize: 9))),
                ]),
              ),
            ),
          ],
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey200),
          pw.Text(
            'Analise gerada automaticamente em ${DateFormat("dd/MM/yyyy HH:mm").format(agora)} - Nosso Bolso',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
          ),
        ]),
      ));
    }

    // ── Páginas: Tabelas por tipo ───────────────────────────────────────────
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 32),
      build: (ctx) => [
        pw.Text('Detalhamento das Transacoes', style: pw.TextStyle(
          fontSize: 14, fontWeight: pw.FontWeight.bold,
        )),
        pw.Text(mesLabel, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 20),
        if (rowsReceita.isNotEmpty) ...[
          _secHeader('Receitas', fmt.format(totalReceita), PdfColor.fromInt(0xFF2E7D32)),
          pw.SizedBox(height: 6),
          _tabela(rowsReceita, fmt, mostrarEnvelope: false),
          pw.SizedBox(height: 20),
        ],
        if (rowsAbast.isNotEmpty) ...[
          _secHeader('Aportes em Envelopes', fmt.format(totalAbast), PdfColor.fromInt(0xFF1565C0)),
          pw.SizedBox(height: 6),
          _tabela(rowsAbast, fmt, mostrarEnvelope: true),
          pw.SizedBox(height: 20),
        ],
        if (rowsDespesa.isNotEmpty) ...[
          _secHeader('Despesas', fmt.format(totalDespesa), PdfColor.fromInt(0xFFC62828)),
          pw.SizedBox(height: 6),
          _tabela(rowsDespesa, fmt, mostrarEnvelope: true),
          pw.SizedBox(height: 8),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Text('Total despesas: ${fmt.format(totalDespesa)}',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ]),
        ],
      ],
    ));

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'extrato_$mes.pdf',
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text('Erro ao gerar PDF: $e'),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ));
  }
}

// ─── Helpers internos ──────────────────────────────────────────────────────────

void _snack(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    duration: const Duration(seconds: 2),
  ));
}

pw.Widget _kpi(String label, String valor, PdfColor cor, {String icon = ''}) =>
    pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: cor.shade(0.3)),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          color: cor.shade(0.05),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 6),
          pw.Text(valor, style: pw.TextStyle(
            fontSize: 11, fontWeight: pw.FontWeight.bold, color: cor,
          )),
        ]),
      ),
    );

pw.Widget _secHeader(String titulo, String total, PdfColor cor) =>
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: cor.shade(0.08),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border(left: pw.BorderSide(color: cor, width: 3)),
      ),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(titulo, style: pw.TextStyle(
          fontSize: 11, fontWeight: pw.FontWeight.bold, color: cor,
        )),
        pw.Text(total, style: pw.TextStyle(
          fontSize: 11, fontWeight: pw.FontWeight.bold, color: cor,
        )),
      ]),
    );

pw.Widget _tabela(
  List<Map<String, dynamic>> rows,
  NumberFormat fmt, {
  required bool mostrarEnvelope,
}) {
  final headers = mostrarEnvelope
      ? ['Data', 'Descricao', 'Categoria', 'Valor']
      : ['Data', 'Descricao', 'Valor'];
  final widths = mostrarEnvelope
      ? {0: const pw.FixedColumnWidth(64), 1: const pw.FlexColumnWidth(3),
         2: const pw.FlexColumnWidth(2), 3: const pw.FixedColumnWidth(80)}
      : {0: const pw.FixedColumnWidth(64), 1: const pw.FlexColumnWidth(4),
         2: const pw.FixedColumnWidth(80)};

  return pw.TableHelper.fromTextArray(
    headers: headers,
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    cellStyle: const pw.TextStyle(fontSize: 8),
    cellAlignment: pw.Alignment.centerLeft,
    columnWidths: widths,
    oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
    data: rows.map((t) {
      final dataStr = t['data']?.toString() ?? '';
      String dataFmt = dataStr;
      try { dataFmt = DateFormat('dd/MM/yy').format(DateTime.parse(dataStr)); } catch (_) {}
      final valorFmt = fmt.format((t['valor'] as num?)?.toDouble() ?? 0);
      final env = ((t['envelopes'] as Map?)?['nome_envelope'] as String?) ?? '';
      if (mostrarEnvelope) return [dataFmt, (t['descricao'] ?? '').toString(), env, valorFmt];
      return [dataFmt, (t['descricao'] ?? '').toString(), valorFmt];
    }).toList(),
  );
}

Future<AnaliseIA> _analisarComGemini({
  required String mes,
  required String mesLabel,
  required List<Map<String, dynamic>> rows,
  required double totalReceita,
  required double totalDespesa,
  required double totalAbast,
  required double saldo,
  required Map<String, double> porEnvelope,
  required NumberFormat fmt,
}) async {
  final envOrdenados = porEnvelope.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final envLinhas = envOrdenados.map((e) => '  - ${e.key}: ${fmt.format(e.value)}').join('\n');

  final despesas = rows.where((t) => t['tipo'] == 'despesa').toList()
    ..sort((a, b) => ((b['valor'] as num?) ?? 0).compareTo((a['valor'] as num?) ?? 0));
  final top5 = despesas.take(5).map((t) =>
      '  - ${t['descricao']}: ${fmt.format((t['valor'] as num?)?.toDouble() ?? 0)}'
      ' (${(t['envelopes'] as Map?)?['nome_envelope'] ?? 'sem envelope'})').join('\n');

  final pctDespesa = totalReceita > 0 ? (totalDespesa / totalReceita * 100) : 0.0;

  final prompt = '''
Voce e o Astrix, assistente financeiro do app Nosso Bolso. Analise os dados abaixo e retorne SOMENTE um JSON valido (sem markdown).

DADOS DO MES ($mesLabel):
- Receita: ${fmt.format(totalReceita)}
- Despesas variaveis: ${fmt.format(totalDespesa)} (${pctDespesa.toStringAsFixed(1)}% da receita)
- Aportes em envelopes: ${fmt.format(totalAbast)}
- Saldo: ${fmt.format(saldo)} (${saldo >= 0 ? 'positivo' : 'NEGATIVO'})
- Transacoes: ${rows.length}

GASTOS POR CATEGORIA:
$envLinhas

TOP 5 MAIORES DESPESAS:
$top5

Retorne este JSON exato:
{
  "status": "ok|atencao|alerta",
  "titulo": "frase curta e direta (ex: Gastos 23% acima do esperado)",
  "insights": [
    {"categoria": "nome", "tipo": "positivo|negativo|neutro", "mensagem": "frase com valor real"}
  ],
  "projecao_mes": "frase sobre o que esperar ate o fim do mes",
  "acoes_recomendadas": ["acao 1 com valor especifico", "acao 2", "acao 3"]
}

Regras: status alerta se saldo negativo ou alguma categoria passou de 100% do planejado. status atencao se saldo < 20% da receita. Use no maximo 4 insights. Sem markdown, sem acentos no JSON.
''';

  final body = {
    'contents': [{'parts': [{'text': prompt}]}],
    'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 800},
  };

  final resp = await GeminiKeyService.post(body, timeout: const Duration(seconds: 45));
  if (resp.statusCode != 200) throw Exception('Gemini ${resp.statusCode}');

  final data = jsonDecode(resp.body) as Map<String, dynamic>;
  final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
  final json = jsonDecode(geminiExtrairJson(text)) as Map<String, dynamic>;
  return AnaliseIA.fromJson(json);
}
