import 'package:http/http.dart' as http;

/// Raspa o conteúdo de uma NFC-e a partir do celular do usuário (IP residencial
/// brasileiro). Necessário porque a SEFAZ-GO bloqueia IPs de data center
/// (AWS US-East do Render), então não dá pra fazer no backend.
///
/// Devolve o XML/HTML pronto pro backend extrair com a LLM.
class NfceScraper {
  static const _ua =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Mobile Safari/537.36';
  static const _timeout = Duration(seconds: 20);

  /// Extrai os 44 dígitos da chave de acesso da URL do QR code.
  static String? extrairChave(String qrUrl) {
    final match = RegExp(r'\d{44}').firstMatch(qrUrl);
    return match?.group(0);
  }

  /// Faz o fluxo completo de scrape pra SEFAZ-GO:
  ///   1) GET na URL principal (pega cookies de sessão)
  ///   2) GET no endpoint /render/html/danfeNFCe com Referer (devolve XML
  ///      com o HTML da nota dentro de <DANFE_NFCE_HTML>)
  /// Devolve o XML cru — o backend faz o unescape e parse.
  static Future<String> rasparSefazGo(String qrUrl) async {
    final chave = extrairChave(qrUrl);
    if (chave == null) {
      throw Exception('URL não contém chave de acesso (44 dígitos)');
    }

    // Sessão simples: o Flutter http.Client mantém cookies por host quando
    // usado com IOClient + CookieJar, mas pra simplicidade vou capturar o
    // Set-Cookie e enviar de volta no segundo request.
    final principal = await http
        .get(Uri.parse(qrUrl), headers: {'User-Agent': _ua})
        .timeout(_timeout);
    if (principal.statusCode != 200) {
      throw Exception(
        'SEFAZ-GO recusou a página principal (HTTP ${principal.statusCode})',
      );
    }
    final cookies = _extrairCookies(principal.headers['set-cookie']);

    final urlIframe =
        'https://nfeweb.sefaz.go.gov.br/nfeweb/sites/nfce/render/danfeNFCe?chNFe=$chave';
    final urlDados =
        'https://nfeweb.sefaz.go.gov.br/nfeweb/sites/nfce/render/html/danfeNFCe?chNFe=$chave';

    final resp = await http.get(
      Uri.parse(urlDados),
      headers: {
        'User-Agent': _ua,
        'Referer': urlIframe,
        'X-Requested-With': 'XMLHttpRequest',
        if (cookies.isNotEmpty) 'Cookie': cookies,
      },
    ).timeout(_timeout);

    if (resp.statusCode != 200) {
      throw Exception(
        'SEFAZ-GO devolveu HTTP ${resp.statusCode} — tente novamente',
      );
    }
    final body = resp.body;
    final lower = body.toLowerCase();
    if (lower.contains('acesso negado') ||
        lower.contains('access denied') ||
        lower.contains('forbidden')) {
      throw Exception(
        'SEFAZ-GO bloqueou a consulta (Acesso Negado). '
        'Aguarde alguns minutos e tente de novo.',
      );
    }
    if (!body.contains('<STATUS>SUCCESS</STATUS>')) {
      if (body.contains('<STATUS>FAILURE</STATUS>')) {
        throw Exception(
          'NFC-e ainda não disponível no portal da SEFAZ-GO. '
          'Notas recém-emitidas levam alguns minutos (até horas) pra aparecer. '
          'Tente de novo mais tarde.',
        );
      }
      throw Exception('SEFAZ-GO não retornou os dados (status != SUCCESS)');
    }
    if (!body.contains('<DANFE_NFCE_HTML>')) {
      throw Exception('Resposta da SEFAZ-GO não contém o conteúdo da nota');
    }
    return body;
  }

  /// Roteador: detecta a SEFAZ pelo host e chama o scraper específico.
  static Future<String> raspar(String qrUrl) async {
    final host = Uri.tryParse(qrUrl)?.host.toLowerCase() ?? '';
    if (host.contains('sefaz.go.gov.br')) {
      return rasparSefazGo(qrUrl);
    }
    // Outras SEFAZ ainda não implementadas — backend tenta como fallback
    throw Exception(
      'SEFAZ não suportada ainda no scraper local: $host. '
      'O backend vai tentar baixar (pode falhar se IP estiver bloqueado).',
    );
  }

  static String _extrairCookies(String? setCookieHeader) {
    if (setCookieHeader == null || setCookieHeader.isEmpty) return '';
    // O header set-cookie pode ter várias entradas separadas por vírgula —
    // pegamos só o nome=valor (até o primeiro `;`) de cada cookie.
    final partes = <String>[];
    for (final raw in setCookieHeader.split(RegExp(r',(?=[^;]+=)'))) {
      final pair = raw.split(';').first.trim();
      if (pair.isNotEmpty && pair.contains('=')) {
        partes.add(pair);
      }
    }
    return partes.join('; ');
  }
}
