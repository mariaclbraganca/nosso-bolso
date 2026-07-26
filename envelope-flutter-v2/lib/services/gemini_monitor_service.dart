import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'bcb_service.dart';
import 'gemini_key_service.dart';

class MonitorAnalise {
  final String status;        // 'ok' | 'atencao' | 'alerta'
  final String titulo;
  final String resumo;        // 1-2 linhas para o card fechado
  final List<MonitorInsight> insights;
  final String? projecaoMes;  // ex: "no ritmo atual, vão ultrapassar R$ 800 até o fim do mês"
  final String? padraoDetectado; // padrão de consumo identificado
  final List<String> acoesRecomendadas;
  final DateTime geradoEm;

  const MonitorAnalise({
    required this.status,
    required this.titulo,
    required this.resumo,
    required this.insights,
    this.projecaoMes,
    this.padraoDetectado,
    required this.acoesRecomendadas,
    required this.geradoEm,
  });

  factory MonitorAnalise.fromJson(Map<String, dynamic> j, DateTime geradoEm) {
    return MonitorAnalise(
      status: j['status'] as String? ?? 'ok',
      titulo: j['titulo'] as String? ?? 'Análise financeira',
      resumo: j['resumo'] as String? ?? '',
      insights: (j['insights'] as List? ?? [])
          .map((i) => MonitorInsight.fromJson(i as Map<String, dynamic>))
          .toList(),
      projecaoMes: j['projecao_mes'] as String?,
      padraoDetectado: j['padrao_detectado'] as String?,
      acoesRecomendadas: List<String>.from(j['acoes_recomendadas'] as List? ?? []),
      geradoEm: geradoEm,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'titulo': titulo,
    'resumo': resumo,
    'insights': insights.map((i) => i.toJson()).toList(),
    'projecao_mes': projecaoMes,
    'padrao_detectado': padraoDetectado,
    'acoes_recomendadas': acoesRecomendadas,
    'gerado_em': geradoEm.toIso8601String(),
  };
}

class MonitorInsight {
  final String categoria;   // ex: "Alimentação", "Transporte"
  final String tipo;        // 'positivo' | 'negativo' | 'neutro'
  final String mensagem;
  final double? valorReferencia;
  final double? variacaoPercent;

  const MonitorInsight({
    required this.categoria,
    required this.tipo,
    required this.mensagem,
    this.valorReferencia,
    this.variacaoPercent,
  });

  factory MonitorInsight.fromJson(Map<String, dynamic> j) => MonitorInsight(
    categoria: j['categoria'] as String? ?? '',
    tipo: j['tipo'] as String? ?? 'neutro',
    mensagem: j['mensagem'] as String? ?? '',
    valorReferencia: (j['valor_referencia'] as num?)?.toDouble(),
    variacaoPercent: (j['variacao_percent'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'categoria': categoria,
    'tipo': tipo,
    'mensagem': mensagem,
    'valor_referencia': valorReferencia,
    'variacao_percent': variacaoPercent,
  };
}

// ── Chave de cache ────────────────────────────────────────────────────────────

const _cacheKey = 'monitor_ia_cache';
const _cacheTimeKey = 'monitor_ia_cache_time';
const _cacheDuration = Duration(hours: 24);

class GeminiMonitorService {
  // ── Cache ──────────────────────────────────────────────────────────────────

  static Future<MonitorAnalise?> carregarCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeStr = prefs.getString(_cacheTimeKey);
      if (timeStr == null) return null;
      final cacheTime = DateTime.parse(timeStr);
      if (DateTime.now().difference(cacheTime) > _cacheDuration) return null;
      final json = prefs.getString(_cacheKey);
      if (json == null) return null;
      final data = jsonDecode(json) as Map<String, dynamic>;
      return MonitorAnalise.fromJson(data, cacheTime);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _salvarCache(MonitorAnalise analise) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(analise.toJson()));
      await prefs.setString(_cacheTimeKey, analise.geradoEm.toIso8601String());
    } catch (e) {
      debugPrint('MonitorIA: erro ao salvar cache: $e');
    }
  }

  static Future<void> limparCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimeKey);
  }

  // ── Coleta de dados ───────────────────────────────────────────────────────

  static Future<MonitorAnalise> analisar({
    required String familiaId,
    required List<Map<String, dynamic>> envelopes,
    required List<Map<String, dynamic>> fixosMesAtual,
    List<({String mes, double total})> evolucaoPatrimonio = const [],
    bool forcarAtualizacao = false,
  }) async {
    // Tenta cache primeiro
    if (!forcarAtualizacao) {
      final cached = await carregarCache();
      if (cached != null) return cached;
    }

    // Busca transações dos últimos 3 meses
    final agora = DateTime.now();
    final tresAtras = DateTime(agora.year, agora.month - 3, 1);
    final dataInicio = '${tresAtras.year}-${tresAtras.month.toString().padLeft(2, '0')}-01';
    final mesAtras3 = '${tresAtras.year}-${tresAtras.month.toString().padLeft(2, '0')}';

    List<Map<String, dynamic>> transacoes = [];
    try {
      final rows = await supabase
          .from('transacoes')
          .select('tipo, valor, data, envelope_id, descricao')
          .eq('familia_id', familiaId)
          .isFilter('deleted_at', null)
          .gte('data', dataInicio)
          .order('data', ascending: false)
          .limit(500);
      transacoes = List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('MonitorIA: erro ao buscar transações: $e');
    }

    // Busca gastos fixos dos últimos 3 meses para complementar o histórico
    List<Map<String, dynamic>> fixosHistorico = [];
    try {
      final rows = await supabase
          .from('gastos_fixos')
          .select('nome, valor, mes, pago')
          .eq('familia_id', familiaId)
          .isFilter('deleted_at', null)
          .gte('mes', mesAtras3)
          .order('mes', ascending: false);
      fixosHistorico = List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('MonitorIA: erro ao buscar fixos histórico: $e');
    }

    // Taxas do BCB para contexto
    final taxas = await BcbService.buscar();

    // Monta contexto agregado por mês e envelope
    final contexto = _montarContexto(
      transacoes: transacoes,
      envelopes: envelopes,
      fixos: fixosMesAtual,
      fixosHistorico: fixosHistorico,
      taxas: taxas,
      agora: agora,
    );

    final prompt = _montarPrompt(contexto, agora, taxas, evolucaoPatrimonio);

    final body = {
      'contents': [
        {'parts': [{'text': prompt}]}
      ],
      'generationConfig': {'temperature': 0.2},
    };

    final http.Response resp;
    try {
      resp = await GeminiKeyService.post(body, timeout: const Duration(seconds: 60));
    } on GeminiSemChaveException catch (e) {
      throw Exception(e.toString());
    } on GeminiCotaEsgotadaException catch (e) {
      throw Exception(e.toString());
    }

    if (resp.statusCode != 200) {
      final preview = resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body;
      throw Exception('Gemini HTTP ${resp.statusCode}: $preview');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
    final json = jsonDecode(geminiExtrairJson(text)) as Map<String, dynamic>;
    final analise = MonitorAnalise.fromJson(json, DateTime.now());

    await _salvarCache(analise);
    await _salvarNoSupabase(familiaId, analise); // cópia no servidor (histórico)
    return analise;
  }

  /// Salva o relatório no Supabase (além do cache local) — permite consultar o
  /// último relatório fora do dispositivo. Best-effort: não derruba o fluxo.
  static Future<void> _salvarNoSupabase(
      String familiaId, MonitorAnalise analise) async {
    try {
      await supabase.from('monitor_ia_relatorios').insert({
        'familia_id': familiaId,
        'status': analise.status,
        'titulo': analise.titulo,
        'relatorio': analise.toJson(),
        'gerado_em': analise.geradoEm.toIso8601String(),
      });
    } catch (e) {
      debugPrint('MonitorIA: erro ao salvar no Supabase: $e');
    }
  }

  // ── Montagem do contexto ──────────────────────────────────────────────────

  static Map<String, dynamic> _montarContexto({
    required List<Map<String, dynamic>> transacoes,
    required List<Map<String, dynamic>> envelopes,
    required List<Map<String, dynamic>> fixos,
    required List<Map<String, dynamic>> fixosHistorico,
    required TaxasBrasil taxas,
    required DateTime agora,
  }) {
    // Agrupa por mês
    final porMes = <String, Map<String, double>>{};
    final porEnvelopeMes = <String, Map<String, double>>{};

    for (final t in transacoes) {
      final data = t['data']?.toString() ?? '';
      if (data.length < 7) continue;
      final mes = data.substring(0, 7);
      final valor = (t['valor'] as num?)?.toDouble() ?? 0;
      final tipo = t['tipo'] as String? ?? '';
      final envId = t['envelope_id'] as String? ?? 'sem_envelope';

      porMes[mes] ??= {'receita': 0, 'despesa': 0, 'abastecimento': 0};
      if (tipo == 'receita') porMes[mes]!['receita'] = (porMes[mes]!['receita'] ?? 0) + valor;
      if (tipo == 'despesa') porMes[mes]!['despesa'] = (porMes[mes]!['despesa'] ?? 0) + valor;
      if (tipo == 'abastecimento') porMes[mes]!['abastecimento'] = (porMes[mes]!['abastecimento'] ?? 0) + valor;

      final chave = '$mes:$envId';
      porEnvelopeMes[chave] ??= {'total': 0};
      if (tipo == 'despesa') {
        porEnvelopeMes[chave]!['total'] = (porEnvelopeMes[chave]!['total'] ?? 0) + valor;
      }
    }

    // Envelopes com nome para cruzar
    final envNomes = <String, String>{
      for (final e in envelopes)
        (e['id'] as String? ?? ''): (e['nome_envelope'] as String? ?? 'Sem nome'),
    };
    final envMetas = <String, double>{
      for (final e in envelopes)
        (e['id'] as String? ?? ''): (e['valor_planejado'] as num?)?.toDouble() ??
                                    (e['valor_objetivo'] as num?)?.toDouble() ?? 0,
    };

    // Resumo de dias decorridos no mês atual
    final diasNoMes = DateTime(agora.year, agora.month + 1, 0).day;
    final diasDecorridos = agora.day;
    final diasRestantes = diasNoMes - diasDecorridos;
    final fracaoMes = diasDecorridos / diasNoMes;

    // Gasto atual no mês corrente
    final mesAtual = '${agora.year}-${agora.month.toString().padLeft(2, '0')}';
    final gastosAtual = porMes[mesAtual]?['despesa'] ?? 0;
    final receitaAtual = porMes[mesAtual]?['receita'] ?? 0;
    final totalFixos = fixos.fold<double>(0, (s, f) => s + ((f['valor'] as num?)?.toDouble() ?? 0));
    final fixosPagos = fixos.where((f) => f['pago'] == true).fold<double>(0, (s, f) => s + ((f['valor'] as num?)?.toDouble() ?? 0));

    // Agrega fixos históricos por mês para dar contexto real à IA
    final fixosPorMes = <String, double>{};
    for (final f in fixosHistorico) {
      final mes = f['mes'] as String? ?? '';
      final valor = (f['valor'] as num?)?.toDouble() ?? 0;
      fixosPorMes[mes] = (fixosPorMes[mes] ?? 0) + valor;
    }

    // Garante que meses com apenas fixos (sem transações) apareçam no histórico
    for (final entry in fixosPorMes.entries) {
      porMes[entry.key] ??= {'receita': 0, 'despesa': 0, 'abastecimento': 0};
    }

    return {
      'mes_atual': mesAtual,
      'dias_decorridos': diasDecorridos,
      'dias_restantes': diasRestantes,
      'fracao_mes': fracaoMes,
      'por_mes': porMes,
      'por_envelope_mes': porEnvelopeMes,
      'env_nomes': envNomes,
      'env_metas': envMetas,
      'gasto_atual_mes': gastosAtual,
      'receita_atual_mes': receitaAtual,
      'fixos_total': totalFixos,
      'fixos_pagos': fixosPagos,
      'fixos_pendentes': totalFixos - fixosPagos,
      'fixos_por_mes': fixosPorMes,
    };
  }

  // ── Montagem do prompt ────────────────────────────────────────────────────

  static String _montarPrompt(
    Map<String, dynamic> ctx,
    DateTime agora,
    TaxasBrasil taxas,
    List<({String mes, double total})> evolucao,
  ) {
    final meses = ['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'];
    final mesLabel = '${meses[agora.month - 1]}/${agora.year}';

    final porMes = ctx['por_mes'] as Map<String, Map<String, double>>;
    final porEnvMes = ctx['por_envelope_mes'] as Map<String, Map<String, double>>;
    final envNomes = ctx['env_nomes'] as Map<String, String>;
    final envMetas = ctx['env_metas'] as Map<String, double>;

    final fixosPorMes = ctx['fixos_por_mes'] as Map<String, double>? ?? {};

    // Histórico mensal em texto — inclui fixos históricos para análise real
    final historico = porMes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final historicoTexto = historico.map((e) {
      final rec = e.value['receita']?.toStringAsFixed(2) ?? '0';
      final desp = e.value['despesa']?.toStringAsFixed(2) ?? '0';
      final fixos = fixosPorMes[e.key]?.toStringAsFixed(2) ?? '0';
      final totalReal = ((e.value['despesa'] ?? 0) + (fixosPorMes[e.key] ?? 0)).toStringAsFixed(2);
      final saldo = ((e.value['receita'] ?? 0) - (e.value['despesa'] ?? 0) - (fixosPorMes[e.key] ?? 0)).toStringAsFixed(2);
      return '  ${e.key}: receita R\$$rec | despesas variáveis R\$$desp | fixos R\$$fixos | total gasto R\$$totalReal | saldo R\$$saldo';
    }).join('\n');

    final mesAtual = ctx['mes_atual'] as String;

    // Gastos por envelope no mês atual
    final envAtual = porEnvMes.entries
        .where((e) => e.key.startsWith('$mesAtual:'))
        .map((e) {
      final envId = e.key.split(':')[1];
      final nome = envNomes[envId] ?? 'Sem nome';
      final gasto = e.value['total'] ?? 0;
      final meta = envMetas[envId] ?? 0;
      final pct = meta > 0 ? (gasto / meta * 100).toStringAsFixed(0) : '?';
      return '  $nome: R\$${gasto.toStringAsFixed(2)} de R\$${meta.toStringAsFixed(2)} (${pct}% da meta)';
    }).join('\n');

    // Histórico por envelope nos meses anteriores (para detectar padrões)
    // Agrupa: envNome -> {mes -> gasto}
    final histEnv = <String, Map<String, double>>{};
    for (final entry in porEnvMes.entries) {
      final parts = entry.key.split(':');
      if (parts.length < 2) continue;
      final mes = parts[0];
      final envId = parts[1];
      if (mes == mesAtual) continue; // mês atual já aparece acima
      final nome = envNomes[envId] ?? 'Sem nome';
      histEnv[nome] ??= {};
      histEnv[nome]![mes] = (histEnv[nome]![mes] ?? 0) + (entry.value['total'] ?? 0);
    }
    // Só mostra envelopes que tiveram algum gasto histórico
    final mesesHistorico = porMes.keys.where((m) => m != mesAtual).toList()..sort();
    final envHistoricoTexto = histEnv.entries
        .where((e) => e.value.values.any((v) => v > 0))
        .map((e) {
      final meta = envMetas.entries
          .firstWhere((m) => envNomes[m.key] == e.key, orElse: () => MapEntry('', 0))
          .value;
      final cols = mesesHistorico.map((m) => 'R\$${(e.value[m] ?? 0).toStringAsFixed(0)}').join(' | ');
      return '  ${e.key} (meta R\$${meta.toStringAsFixed(0)}): $cols';
    }).join('\n');
    final headerMeses = mesesHistorico.join(' | ');

    // Gasto total do mês atual = despesas variáveis + fixos já lançados
    final gastosVarAtual = (ctx['gasto_atual_mes'] as double);
    final fixosTotal = (ctx['fixos_total'] as double);
    final fixosPendentes = (ctx['fixos_pendentes'] as double);
    final fixosPagosAtual = fixosTotal - fixosPendentes;
    // Gasto real inclui fixos pagos (abastecimento não é gasto)
    final gastosTotalAtual = gastosVarAtual + fixosPagosAtual;
    final fracaoMes = (ctx['fracao_mes'] as double);
    // Projeção considera variáveis + todos os fixos do mês
    final projetadoVar = fracaoMes > 0 ? gastosVarAtual / fracaoMes : gastosVarAtual;
    final projetadoTotal = projetadoVar + fixosTotal;
    final receitaAtual = (ctx['receita_atual_mes'] as double);
    final saldoAtual = receitaAtual - gastosTotalAtual;

    return '''
Você é o Astrix, monitor financeiro inteligente do app Nosso Bolso. Analise os dados abaixo e gere um relatório em JSON.

DATA ATUAL: ${agora.day}/$mesLabel — ${ctx['dias_decorridos']} dias decorridos de ${ctx['dias_decorridos'] + (ctx['dias_restantes'] as int)} dias no mês (${(fracaoMes * 100).toStringAsFixed(0)}% do mês).

HISTÓRICO (últimos 3 meses):
$historicoTexto

MÊS ATUAL ($mesLabel):
- Receita registrada: R\$${receitaAtual.toStringAsFixed(2)}
- Despesas variáveis até hoje: R\$${gastosVarAtual.toStringAsFixed(2)}
- Fixos do mês: R\$${fixosTotal.toStringAsFixed(2)} (R\$${fixosPendentes.toStringAsFixed(2)} ainda pendentes)
- Total gasto até hoje (variáveis + fixos pagos): R\$${gastosTotalAtual.toStringAsFixed(2)}
- Projeção de gasto total ao fim do mês: R\$${projetadoTotal.toStringAsFixed(2)}
- Saldo atual do mês: R\$${saldoAtual.toStringAsFixed(2)}

GASTOS POR ENVELOPE ($mesLabel):
$envAtual

${envHistoricoTexto.isNotEmpty ? '''HISTÓRICO DE GASTOS POR ENVELOPE (meses anteriores):
Formato: envelope (meta mensal): $headerMeses
$envHistoricoTexto

''' : ''}${evolucao.length >= 2 ? '''EVOLUÇÃO DO PATRIMÔNIO (snapshots mensais):
${evolucao.map((e) => '  ${e.mes}: R\$${e.total.toStringAsFixed(2)}').join('\n')}
- Variação total: ${((evolucao.last.total - evolucao.first.total) >= 0 ? '+' : '')}R\$${(evolucao.last.total - evolucao.first.total).toStringAsFixed(2)} (${evolucao.first.total > 0 ? ((evolucao.last.total - evolucao.first.total) / evolucao.first.total * 100).toStringAsFixed(1) : '?'}%)

''' : ''}CONTEXTO ECONÔMICO (Banco Central — ${taxas.dataReferencia}):
- Inflação IPCA 12m: ${taxas.ipcaAnual.toStringAsFixed(2)}% a.a.
- Selic: ${taxas.selicMensal.toStringAsFixed(2)}% a.m.

INSTRUÇÕES:
1. Analise se cada envelope está sendo usado de forma proporcional aos dias decorridos (${(fracaoMes * 100).toStringAsFixed(0)}% do mês). Envelopes acima de ${(fracaoMes * 120).toStringAsFixed(0)}% são preocupantes.
2. Compare os gastos de cada envelope com o histórico dos meses anteriores. Aponte quais envelopes cresceram e quais diminuíram. Use os números reais.
3. Identifique padrões: por exemplo, se "Alimentação" sempre ultrapassa a meta, ou se "Combustível" caiu nos últimos meses.
4. Calcule o gasto total projetado (variáveis extrapoladas + todos os fixos) e compare com a receita registrada.
5. Sugira ações concretas com valores específicos para os 2-3 envelopes mais críticos.
6. Status: "ok" se saldo projetado é positivo e sem padrões preocupantes, "atencao" se há risco moderado em algum envelope ou projeção próxima da renda, "alerta" se projeção ultrapassa a renda ou algum envelope já ultrapassou 100% da meta.

Responda SOMENTE com este JSON (sem markdown):
{
  "status": "ok|atencao|alerta",
  "titulo": "string curta e direta (ex: 'Gastos 23% acima do esperado')",
  "resumo": "string de 1-2 linhas para o card fechado",
  "insights": [
    {
      "categoria": "string (nome do envelope ou tema como 'Receita', 'Projeção')",
      "tipo": "positivo|negativo|neutro",
      "mensagem": "string clara com valores reais",
      "valor_referencia": number_ou_null,
      "variacao_percent": number_ou_null
    }
  ],
  "projecao_mes": "string descrevendo a projeção para fim do mês",
  "padrao_detectado": "string descrevendo padrão de consumo identificado ou null",
  "acoes_recomendadas": ["string com ação concreta", "string"]
}
''';
  }
}
