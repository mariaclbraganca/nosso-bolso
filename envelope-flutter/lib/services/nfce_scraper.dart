import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Raspa o conteúdo de uma NFC-e a partir do celular do usuário (IP residencial
/// brasileiro). Necessário porque a SEFAZ-GO bloqueia IPs de data center
/// (AWS US-East do Render), então não dá pra fazer no backend.
class NfceScraper {
  static const _ua =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Mobile Safari/537.36';

  static const _timeout = Duration(seconds: 30);

  static Map<String, String> _baseHeaders({String? referer, String? cookies}) => {
        'User-Agent': _ua,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Cache-Control': 'max-age=0',
        if (referer != null) 'Referer': referer,
        if (cookies != null && cookies.isNotEmpty) 'Cookie': cookies,
      };

  /// Extrai os 44 dígitos da chave de acesso da URL do QR code.
  static String? extrairChave(String qrUrl) {
    final match = RegExp(r'\d{44}').firstMatch(qrUrl);
    return match?.group(0);
  }

  /// Cria um HttpClient que segue redirects e acumula cookies entre eles.
  static Future<_SessaoHttp> _criarSessao() async {
    final httpClient = HttpClient()
      ..badCertificateCallback = (_, __, ___) => true;
    return _SessaoHttp(IOClient(httpClient));
  }

  /// Fluxo completo SEFAZ-GO com sessão que segue redirects e preserva cookies.
  static Future<String> rasparSefazGo(String qrUrl) async {
    final chave = extrairChave(qrUrl);
    if (chave == null) {
      throw Exception('URL não contém chave de acesso (44 dígitos)');
    }

    final sessao = await _criarSessao();

    // Passo 1: abre a URL do QR (pode redirecionar várias vezes) para obter sessão
    final r1 = await sessao.get(qrUrl);
    debugPrint('NfceScraper GO step1: ${r1.statusCode} url=$qrUrl');

    if (r1.statusCode == 403) {
      throw Exception(
        'SEFAZ-GO bloqueou o acesso (403). Tente novamente em alguns minutos.',
      );
    }
    if (r1.statusCode != 200) {
      throw Exception('SEFAZ-GO recusou a página principal (HTTP ${r1.statusCode})');
    }

    // Passo 2: busca o iframe que carrega a DANFE
    final urlIframe =
        'https://nfeweb.sefaz.go.gov.br/nfeweb/sites/nfce/render/danfeNFCe?chNFe=$chave';
    final r2 = await sessao.get(urlIframe, referer: qrUrl);
    debugPrint('NfceScraper GO step2: ${r2.statusCode} url=$urlIframe');

    // Passo 3: busca o HTML da DANFE via endpoint AJAX
    final urlDados =
        'https://nfeweb.sefaz.go.gov.br/nfeweb/sites/nfce/render/html/danfeNFCe?chNFe=$chave';
    final r3 = await sessao.get(
      urlDados,
      referer: urlIframe,
      extraHeaders: {'X-Requested-With': 'XMLHttpRequest'},
    );
    debugPrint('NfceScraper GO step3: ${r3.statusCode} url=$urlDados body_len=${r3.body.length}');

    if (r3.statusCode != 200) {
      throw Exception('SEFAZ-GO devolveu HTTP ${r3.statusCode} ao buscar a DANFE');
    }

    final body = r3.body;
    final lower = body.toLowerCase();
    if (lower.contains('acesso negado') || lower.contains('forbidden')) {
      throw Exception('SEFAZ-GO bloqueou a consulta. Aguarde alguns minutos e tente de novo.');
    }
    if (!body.contains('<STATUS>SUCCESS</STATUS>')) {
      if (body.contains('<STATUS>FAILURE</STATUS>')) {
        throw Exception(
          'NFC-e ainda não disponível no portal da SEFAZ-GO. '
          'Notas recém-emitidas levam alguns minutos. Tente de novo mais tarde.',
        );
      }
      // Retorna o body para diagnóstico
      throw Exception('SEFAZ-GO não retornou dados válidos. Preview: ${body.length > 200 ? body.substring(0, 200) : body}');
    }
    if (!body.contains('<DANFE_NFCE_HTML>')) {
      throw Exception('Resposta da SEFAZ-GO não contém o conteúdo da nota');
    }
    return body;
  }

  /// SEFAZ-BA serve os dados diretamente na URL pública (sem iframe/AJAX).
  static Future<String> rasparSefazBa(String qrUrl) async {
    final sessao = await _criarSessao();
    final r = await sessao.get(qrUrl);
    if (r.statusCode != 200) {
      throw Exception('SEFAZ-BA recusou a URL (HTTP ${r.statusCode})');
    }
    final body = r.body;
    final lower = body.toLowerCase();
    if (lower.contains('acesso negado') || lower.contains('forbidden')) {
      throw Exception('SEFAZ-BA bloqueou a consulta (Acesso Negado).');
    }
    if (!lower.contains('qtde') && !lower.contains('valor a pagar')) {
      throw Exception('SEFAZ-BA não retornou os dados da nota.');
    }
    return body;
  }

  /// Roteador: detecta a SEFAZ pelo host e chama o scraper específico.
  static Future<String> raspar(String qrUrl) async {
    final host = Uri.tryParse(qrUrl)?.host.toLowerCase() ?? '';
    if (host.contains('sefaz.go.gov.br')) {
      return rasparSefazGo(qrUrl);
    }
    if (host.contains('sefaz.ba.gov.br')) {
      return rasparSefazBa(qrUrl);
    }
    throw Exception('SEFAZ do estado "$host" ainda não é suportada pelo app.');
  }
}

/// Sessão HTTP que acumula cookies entre requisições (simula browser).
class _SessaoHttp {
  final http.Client _client;
  final Map<String, String> _cookies = {};

  _SessaoHttp(this._client);

  void _atualizarCookies(Map<String, String> headers) {
    final setCookie = headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) return;
    for (final raw in setCookie.split(RegExp(r',(?=[^;]+=)'))) {
      final pair = raw.split(';').first.trim();
      if (pair.contains('=')) {
        final idx = pair.indexOf('=');
        final name = pair.substring(0, idx).trim();
        final value = pair.substring(idx + 1).trim();
        if (name.isNotEmpty) _cookies[name] = value;
      }
    }
  }

  String get _cookieHeader =>
      _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  Future<http.Response> get(
    String url, {
    String? referer,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = {
      'User-Agent': NfceScraper._ua,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'pt-BR,pt;q=0.9',
      'Accept-Encoding': 'gzip, deflate',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      if (referer != null) 'Referer': referer,
      if (_cookies.isNotEmpty) 'Cookie': _cookieHeader,
      ...?extraHeaders,
    };

    final resp = await _client
        .get(Uri.parse(url), headers: headers)
        .timeout(NfceScraper._timeout);

    _atualizarCookies(resp.headers);
    return resp;
  }
}
