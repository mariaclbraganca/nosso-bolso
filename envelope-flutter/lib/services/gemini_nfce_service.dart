import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'api_service.dart';

/// Chama o Gemini diretamente do celular (IP residencial BR, sem bloqueio geo).
/// Usa a chave configurada na tabela `configuracoes_app` do Supabase.
class GeminiNfceService {
  static const _model = 'gemini-2.5-flash';
  static const _geminiUrl =
      'https://generativelanguage.googleapis.com/v1/models/$_model:generateContent';

  static final _schema = {
    'loja': 'string (nome da loja/empresa)',
    'data_compra': 'string YYYY-MM-DD',
    'valor_total': 'number (valor total da nota, NÃO some os itens)',
    'itens': [
      {
        'nome_original': 'string (nome como aparece na nota)',
        'nome_padronizado': 'string sem abreviações',
        'quantidade': 'number',
        'unidade': 'string (un, kg, L, pct, cx)',
        'valor_unitario': 'number',
        'valor_total_item': 'number',
        'categoria': 'enum exato: Proteínas|Carboidratos|Hortifrúti|Laticínios|Padaria|Bebidas|Lanches|Temperos e Condimentos|Limpeza|Higiene Pessoal|Congelados|Grãos e Cereais|Outros',
      }
    ],
  };

  /// Busca a chave Gemini: primeiro tenta SharedPreferences (salva pela tela de config),
  /// depois consulta o backend como fallback.
  static Future<String?> _buscarChave() async {
    // 1) SharedPreferences — a tela de Configurações de IA salva localmente
    try {
      final prefs = await SharedPreferences.getInstance();
      final local = prefs.getString('ia_gemini_api_key') ?? '';
      if (local.isNotEmpty) {
        debugPrint('GeminiNfce: chave encontrada no SharedPreferences');
        return local;
      }
    } catch (e) {
      debugPrint('GeminiNfce: erro SharedPreferences: $e');
    }

    // 2) Backend: GET /api/v1/configurar retorna gemini_api_key_configurada
    //    mas não expõe a chave. Tenta Supabase direto como último recurso.
    try {
      final rows = await supabase
          .from('configuracoes_app')
          .select('valor')
          .eq('chave', 'GEMINI_API_KEY')
          .limit(1);
      if (rows.isNotEmpty) {
        final valor = rows.first['valor'] as String?;
        if (valor != null && valor.isNotEmpty) {
          debugPrint('GeminiNfce: chave encontrada no Supabase');
          return valor;
        }
      }
    } catch (e) {
      debugPrint('GeminiNfce: erro Supabase: $e');
    }

    return null;
  }

  /// Extrai dados da NFC-e do HTML raspado, retornando JSON estruturado.
  /// Lança [GeminiNfceException] em caso de falha.
  static Future<Map<String, dynamic>> extrairDaNota(String htmlBruto) async {
    final apiKey = await _buscarChave();
    if (apiKey == null || apiKey.isEmpty) {
      throw GeminiNfceException('Chave Gemini não configurada. Configure em Configurações de IA.');
    }

    final textoLimpo = _sanitizar(htmlBruto.length > 12000
        ? htmlBruto.substring(0, 12000)
        : htmlBruto);

    final prompt =
        'Extrator NFC-e. Schema esperado:\n'
        '${jsonEncode(_schema)}\n\n'
        'Regras: data_compra=YYYY-MM-DD | valor_total=explícito na nota (NÃO some itens) | '
        'decimais com ponto | nome_padronizado=sem abreviações | '
        'categoria=enum exato | todos os itens | retorne APENAS JSON sem markdown.\n\n'
        'FONTE:\n$textoLimpo';

    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ]
    };

    final uri = Uri.parse('$_geminiUrl?key=$apiKey');
    final resp = await http
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 60));

    if (resp.statusCode == 400) {
      final body = resp.body.length > 300 ? resp.body.substring(0, 300) : resp.body;
      throw GeminiNfceException('Gemini rejeitou a requisição (400): $body');
    }
    if (resp.statusCode == 429) {
      throw GeminiNfceException('Cota da API Gemini esgotada. Tente novamente mais tarde.');
    }
    if (resp.statusCode != 200) {
      throw GeminiNfceException('Gemini HTTP ${resp.statusCode}: ${resp.body.substring(0, 200)}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
    return _parseJson(text);
  }

  static Map<String, dynamic> _parseJson(String text) {
    final s = text.trim();
    // Remove cerca markdown se presente
    String clean = s;
    if (clean.startsWith('```')) {
      final parts = clean.split('```');
      if (parts.length >= 3) {
        clean = parts[1];
        if (clean.startsWith('json')) clean = clean.substring(4).trimLeft();
      }
    }
    try {
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (_) {
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}') + 1;
      if (start >= 0 && end > start) {
        return jsonDecode(clean.substring(start, end)) as Map<String, dynamic>;
      }
      throw GeminiNfceException('Não foi possível parsear JSON da resposta Gemini: ${text.substring(0, 200)}');
    }
  }

  static String _sanitizar(String texto) {
    // Remove caracteres de controle que quebram o Gemini (exceto \n e \t)
    return texto.replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'), '');
  }
}

class GeminiNfceException implements Exception {
  final String message;
  const GeminiNfceException(this.message);
  @override
  String toString() => message;
}
