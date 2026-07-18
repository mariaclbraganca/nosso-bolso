import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Delega o scraping ao backend (Render não é bloqueado pela SEFAZ-GO).
/// O Gemini é chamado separadamente no celular (ver GeminiNfceService).
class NfceScraper {
  /// Chama GET /api/v1/compras/scrape no backend e retorna o HTML da nota.
  static Future<String> raspar(String qrUrl) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/v1/compras/scrape')
        .replace(queryParameters: {'qr_code_url': qrUrl});

    final resp = await http
        .get(uri, headers: ApiService.authHeaders())
        .timeout(const Duration(seconds: 40));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final texto = data['texto_limpo'] as String? ?? '';
      if (texto.isEmpty) throw Exception('Servidor retornou texto vazio');
      return texto;
    }

    String detail;
    try {
      detail = (jsonDecode(resp.body) as Map)['detail'] as String? ?? resp.body;
    } catch (_) {
      detail = resp.body;
    }

    if (resp.statusCode == 503) throw Exception(detail);
    throw Exception('Erro ao baixar nota (${resp.statusCode}): $detail');
  }
}
