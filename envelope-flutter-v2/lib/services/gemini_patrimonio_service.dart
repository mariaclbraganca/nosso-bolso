import 'dart:convert';
import 'package:http/http.dart' as http;
import 'bcb_service.dart';
import 'gemini_key_service.dart';

class GeminiPatrimonioService {
  /// Analisa o portfólio e retorna análise estruturada com insights e sugestões.
  static Future<PatrimonioAnalise> analisar(
    List<Map<String, dynamic>> contas,
  ) async {
    if (contas.isEmpty) {
      throw GeminiPatrimonioException(
          'Nenhuma conta registrada para analisar.');
    }

    final totalPatrimonio = contas.fold<double>(
      0.0,
      (sum, c) => sum + ((c['saldo_atual'] as num?)?.toDouble() ?? 0.0),
    );

    final contasDescricao = contas.map((c) {
      final nome = c['nome'] ?? '';
      final banco = c['banco'] ?? '';
      final tipo = c['tipo'] ?? 'conta_corrente';
      final saldo = (c['saldo_atual'] as num?)?.toDouble() ?? 0.0;
      final rend = c['rendimento_mensal'];
      final meta = c['meta_saldo'];
      final pct = totalPatrimonio > 0 ? (saldo / totalPatrimonio * 100) : 0.0;

      var desc = '- $nome ($banco, $tipo): R\$ ${saldo.toStringAsFixed(2)}'
          ' = ${pct.toStringAsFixed(1)}% do portfólio';
      if (rend != null) desc += ', rende ${rend}% a.m.';
      if (meta != null) {
        final metaD = (meta as num).toDouble();
        final prog = metaD > 0 ? (saldo / metaD * 100).clamp(0.0, 100.0) : 0.0;
        desc += ', meta R\$ ${metaD.toStringAsFixed(2)} (${prog.toStringAsFixed(0)}% atingido)';
      }
      return desc;
    }).join('\n');

    final taxas = await BcbService.buscar();
    final selicAnual = taxas.selicAnual.toStringAsFixed(2);
    final selicMensal = taxas.selicMensal.toStringAsFixed(2);
    final cdiMensal = taxas.cdiMensal.toStringAsFixed(2);
    final ipcaAnual = taxas.ipcaAnual.toStringAsFixed(2);
    final ipcaMensal = taxas.ipcaMensal.toStringAsFixed(2);
    final poupMensal = taxas.poupancaMensal.toStringAsFixed(2);

    final prompt = '''
Você é o Astrix, assessor financeiro digital do app Nosso Bolso. Analise o portfólio abaixo e gere uma análise completa em JSON estruturado.

PORTFÓLIO:
Total: R\$ ${totalPatrimonio.toStringAsFixed(2)}
$contasDescricao

CONTEXTO BRASIL (${taxas.dataReferencia} — dados oficiais do Banco Central):
- Selic: $selicAnual% a.a. (≈$selicMensal% a.m.)
- CDI: ≈$cdiMensal% a.m. (próximo à Selic)
- Poupança: 70% da Selic = ≈$poupMensal% a.m. — frequentemente abaixo da inflação real
- Inflação (IPCA acumulado 12m): $ipcaAnual% a.a. (≈$ipcaMensal% a.m.)
- CDB Liquidez Diária 100% CDI: disponível em fintechs como Nubank, Inter, C6
- Tesouro Selic: ≈${(taxas.selicAnual - 0.1).toStringAsFixed(1)}% a.a. com liquidez D+1, risco zero
- LCI/LCA 90% CDI: isentas de IR para pessoa física
- Fundos de Renda Fixa conservadores: ≈${(taxas.selicAnual * 0.75).toStringAsFixed(1)}% a.a. após taxa de adm.

INSTRUÇÕES:
1. Identifique contas com rendimento abaixo da inflação (menos de 0,45% a.m.)
2. Avalie a diversificação — muita concentração em conta corrente é capital parado
3. Aponte progresso de metas de forma motivadora
4. Sugira alternativas REAIS e práticas (ex: "migre a poupança para CDB 100% CDI no mesmo banco")
5. Seja específico com nomes, valores e percentuais

Responda APENAS com este JSON (sem markdown, sem código, só o objeto):
{
  "nota_geral": number 0-10,
  "resumo": "string curta e direta (2 linhas máx)",
  "pontos_positivos": ["string", "string"],
  "alertas": ["string", "string"],
  "sugestoes": [
    {
      "titulo": "string curta",
      "descricao": "string detalhada com valores e bancos específicos",
      "impacto": "alto|medio|baixo",
      "urgencia": "agora|proximo_mes|sem_pressa"
    }
  ],
  "distribuicao_ideal": "string descrevendo como o portfólio deveria ser distribuído"
}
''';

    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {'temperature': 0.2},
    };

    final http.Response resp;
    try {
      resp = await GeminiKeyService.post(body, timeout: const Duration(seconds: 60));
    } on GeminiSemChaveException catch (e) {
      throw GeminiPatrimonioException(e.toString());
    } on GeminiCotaEsgotadaException catch (e) {
      throw GeminiPatrimonioException(e.toString());
    }

    if (resp.statusCode != 200) {
      final preview = resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body;
      throw GeminiPatrimonioException('Gemini HTTP ${resp.statusCode}: $preview');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;

    try {
      final json = jsonDecode(geminiExtrairJson(text)) as Map<String, dynamic>;
      return PatrimonioAnalise.fromJson(json);
    } catch (e) {
      throw GeminiPatrimonioException('Falha ao processar resposta da IA: $e');
    }
  }
}

class PatrimonioAnalise {
  final double notaGeral;
  final String resumo;
  final List<String> pontosPositivos;
  final List<String> alertas;
  final List<Sugestao> sugestoes;
  final String distribuicaoIdeal;

  const PatrimonioAnalise({
    required this.notaGeral,
    required this.resumo,
    required this.pontosPositivos,
    required this.alertas,
    required this.sugestoes,
    required this.distribuicaoIdeal,
  });

  factory PatrimonioAnalise.fromJson(Map<String, dynamic> j) {
    return PatrimonioAnalise(
      notaGeral: (j['nota_geral'] as num?)?.toDouble() ?? 5.0,
      resumo: j['resumo'] as String? ?? '',
      pontosPositivos: List<String>.from(j['pontos_positivos'] as List? ?? []),
      alertas: List<String>.from(j['alertas'] as List? ?? []),
      sugestoes: (j['sugestoes'] as List? ?? [])
          .map((s) => Sugestao.fromJson(s as Map<String, dynamic>))
          .toList(),
      distribuicaoIdeal: j['distribuicao_ideal'] as String? ?? '',
    );
  }
}

class Sugestao {
  final String titulo;
  final String descricao;
  final String impacto; // alto | medio | baixo
  final String urgencia; // agora | proximo_mes | sem_pressa

  const Sugestao({
    required this.titulo,
    required this.descricao,
    required this.impacto,
    required this.urgencia,
  });

  factory Sugestao.fromJson(Map<String, dynamic> j) {
    return Sugestao(
      titulo: j['titulo'] as String? ?? '',
      descricao: j['descricao'] as String? ?? '',
      impacto: j['impacto'] as String? ?? 'medio',
      urgencia: j['urgencia'] as String? ?? 'sem_pressa',
    );
  }
}

class GeminiPatrimonioException implements Exception {
  final String message;
  const GeminiPatrimonioException(this.message);
  @override
  String toString() => message;
}
