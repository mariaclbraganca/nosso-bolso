import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class GeminiNfceService {
  static const _model = 'gemini-2.5-flash';
  static const _geminiUrl =
      'https://generativelanguage.googleapis.com/v1/models/$_model:generateContent';

  // Falha 2 corrigida: 'supermercado' em vez de 'loja' para bater com o backend
  static final _schema = {
    'supermercado': 'string (nome da loja/empresa)',
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
        'categoria':
            'enum exato: Proteínas|Carboidratos|Hortifrúti|Laticínios|Padaria|Bebidas|Lanches|Temperos e Condimentos|Limpeza|Higiene Pessoal|Congelados|Grãos e Cereais|Outros',
      }
    ],
  };

  static Future<String?> _buscarChave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final local = prefs.getString('ia_gemini_api_key') ?? '';
      if (local.isNotEmpty) return local;
    } catch (e) {
      debugPrint('GeminiNfce: erro SharedPreferences: $e');
    }
    try {
      final rows = await supabase
          .from('configuracoes_app')
          .select('valor')
          .eq('chave', 'GEMINI_API_KEY')
          .limit(1);
      if (rows.isNotEmpty) {
        final valor = rows.first['valor'] as String?;
        if (valor != null && valor.isNotEmpty) return valor;
      }
    } catch (e) {
      debugPrint('GeminiNfce: erro Supabase: $e');
    }
    return null;
  }

  /// Falha 1 + 4 corrigidas: recebe texto_limpo já processado pelo backend
  /// (BeautifulSoup com .decompose() para <script>/<style>) em vez de HTML bruto.
  static Future<Map<String, dynamic>> extrairDaNota(String textoLimpo) async {
    final apiKey = await _buscarChave();
    if (apiKey == null || apiKey.isEmpty) {
      throw GeminiNfceException(
          'Chave Gemini não configurada. Configure em Configurações de IA.');
    }

    final prompt =
        'Extrator NFC-e. Schema: ${jsonEncode(_schema)}\n'
        'Regras: data_compra=YYYY-MM-DD | valor_total=campo "Valor a pagar" | '
        'decimais com ponto | categoria=enum exato | todos os itens.\n\n'
        'NOTA:\n$textoLimpo';

    // Falha 3 corrigida: responseMimeType força JSON puro, sem markdown
    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
      },
    };

    final uri = Uri.parse('$_geminiUrl?key=$apiKey');
    final resp = await http
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 90));

    if (resp.statusCode == 400) {
      final preview = resp.body.length > 300 ? resp.body.substring(0, 300) : resp.body;
      throw GeminiNfceException('Gemini rejeitou a requisição (400): $preview');
    }
    if (resp.statusCode == 429) {
      throw GeminiNfceException('Cota da API Gemini esgotada. Tente novamente mais tarde.');
    }
    if (resp.statusCode != 200) {
      final preview = resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body;
      throw GeminiNfceException('Gemini HTTP ${resp.statusCode}: $preview');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
    return _parseJson(text);
  }

  // Falha 3 corrigida: parse direto — responseMimeType garante JSON puro
  static Map<String, dynamic> _parseJson(String text) {
    try {
      return jsonDecode(text.trim()) as Map<String, dynamic>;
    } catch (e) {
      throw GeminiNfceException('Falha no parse do JSON estruturado: $e');
    }
  }
}

class GeminiNfceException implements Exception {
  final String message;
  const GeminiNfceException(this.message);
  @override
  String toString() => message;
}
