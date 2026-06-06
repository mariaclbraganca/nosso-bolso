import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Raspa o conteúdo de uma NFC-e usando o WebView real do Android (Chromium).
///
/// Por que WebView e não http.Client:
///   A SEFAZ-GO usa WAF com TLS fingerprinting (JA3) — detecta que o
///   Dart HttpClient não é um browser real e retorna 403. O WebView do
///   sistema usa o mesmo engine do Chrome, passando pelo WAF sem bloqueio.
class NfceScraper {
  static const _ua =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  static const _timeout = Duration(seconds: 40);

  static String? extrairChave(String qrUrl) {
    final match = RegExp(r'\d{44}').firstMatch(qrUrl);
    return match?.group(0);
  }

  /// Raspa a SEFAZ-GO via HeadlessInAppWebView (TLS real do Chrome).
  static Future<String> rasparSefazGo(String qrUrl) async {
    final chave = extrairChave(qrUrl);
    if (chave == null) {
      throw Exception('URL não contém chave de acesso (44 dígitos)');
    }

    final completer = Completer<String>();

    late HeadlessInAppWebView webView;

    void disposeAndError(Object e) {
      if (!completer.isCompleted) {
        try { webView.dispose(); } catch (_) {}
        completer.completeError(e);
      }
    }

    void disposeAndComplete(String value) {
      if (!completer.isCompleted) {
        try { webView.dispose(); } catch (_) {}
        completer.complete(value);
      }
    }

    webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(qrUrl)),
      initialSettings: InAppWebViewSettings(
        userAgent: _ua,
        javaScriptEnabled: true,
        clearCache: false,
        clearSessionCache: false,
        thirdPartyCookiesEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
      ),
      onLoadStop: (controller, url) async {
        if (completer.isCompleted) return;
        try {
          debugPrint('NfceScraper GO: onLoadStop url=$url');

          // Após a página principal carregar com cookies de sessão,
          // faz XHR para o endpoint AJAX da DANFE (mesmo domínio = sem CORS)
          final result = await controller.evaluateJavascript(source: '''
            (function() {
              return new Promise(function(resolve, reject) {
                var urlDados = 'https://nfeweb.sefaz.go.gov.br/nfeweb/sites/nfce/render/html/danfeNFCe?chNFe=$chave';
                var urlIframe = 'https://nfeweb.sefaz.go.gov.br/nfeweb/sites/nfce/render/danfeNFCe?chNFe=$chave';
                var xhr = new XMLHttpRequest();
                xhr.open('GET', urlDados, true);
                xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
                xhr.onload = function() {
                  if (xhr.status === 200) { resolve(xhr.responseText); }
                  else { reject('HTTP ' + xhr.status); }
                };
                xhr.onerror = function() { reject('network error'); };
                xhr.timeout = 25000;
                xhr.ontimeout = function() { reject('timeout'); };
                xhr.send();
              });
            })()
          ''');

          final xml = result?.toString() ?? '';
          debugPrint('NfceScraper GO: xml len=${xml.length}');

          if (xml.isEmpty) {
            disposeAndError(Exception('SEFAZ-GO não retornou dados'));
          } else if (xml.toLowerCase().contains('acesso negado') ||
              xml.toLowerCase().contains('forbidden')) {
            disposeAndError(Exception('SEFAZ-GO bloqueou a consulta. Tente novamente.'));
          } else if (xml.contains('<STATUS>FAILURE</STATUS>')) {
            disposeAndError(Exception(
              'NFC-e ainda não disponível na SEFAZ-GO. '
              'Notas recém-emitidas levam alguns minutos. Tente mais tarde.',
            ));
          } else if (!xml.contains('<STATUS>SUCCESS</STATUS>')) {
            disposeAndError(Exception(
              'SEFAZ-GO retornou resposta inesperada: '
              '${xml.length > 200 ? xml.substring(0, 200) : xml}',
            ));
          } else if (!xml.contains('<DANFE_NFCE_HTML>')) {
            disposeAndError(Exception('Resposta da SEFAZ-GO não contém o conteúdo da nota'));
          } else {
            disposeAndComplete(xml);
          }
        } catch (e) {
          disposeAndError(Exception('Erro ao extrair dados: $e'));
        }
      },
      onReceivedHttpError: (controller, request, response) {
        if (completer.isCompleted || request.isForMainFrame != true) return;
        final status = response.statusCode ?? 0;
        debugPrint('NfceScraper GO: HTTP error $status');
        if (status == 403) {
          disposeAndError(Exception(
            'SEFAZ-GO bloqueou o acesso (403). '
            'Aguarde 10 minutos após a emissão da nota e tente novamente.',
          ));
        }
      },
      onReceivedError: (controller, request, error) {
        if (completer.isCompleted || request.isForMainFrame != true) return;
        debugPrint('NfceScraper GO: error ${error.description}');
        disposeAndError(Exception('Erro ao carregar SEFAZ-GO: ${error.description}'));
      },
    );

    await webView.run();

    return completer.future.timeout(
      _timeout,
      onTimeout: () {
        try { webView.dispose(); } catch (_) {}
        throw Exception(
          'Timeout ao acessar SEFAZ-GO (${_timeout.inSeconds}s). '
          'Verifique sua conexão e tente novamente.',
        );
      },
    );
  }

  /// SEFAZ-BA — página HTML direta, também via WebView para consistência.
  static Future<String> rasparSefazBa(String qrUrl) async {
    final completer = Completer<String>();
    late HeadlessInAppWebView webView;

    void disposeAndError(Object e) {
      if (!completer.isCompleted) {
        try { webView.dispose(); } catch (_) {}
        completer.completeError(e);
      }
    }

    webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(qrUrl)),
      initialSettings: InAppWebViewSettings(
        userAgent: _ua,
        javaScriptEnabled: true,
      ),
      onLoadStop: (controller, url) async {
        if (completer.isCompleted) return;
        try {
          final html = await controller.evaluateJavascript(
            source: 'document.documentElement.outerHTML',
          ) as String?;
          final body = html ?? '';
          final lower = body.toLowerCase();
          if (lower.contains('acesso negado') || lower.contains('forbidden')) {
            disposeAndError(Exception('SEFAZ-BA bloqueou a consulta.'));
          } else if (!lower.contains('qtde') && !lower.contains('valor a pagar')) {
            disposeAndError(Exception('SEFAZ-BA não retornou os dados da nota.'));
          } else {
            try { webView.dispose(); } catch (_) {}
            completer.complete(body);
          }
        } catch (e) {
          disposeAndError(e);
        }
      },
      onReceivedError: (controller, request, error) {
        if (completer.isCompleted || request.isForMainFrame != true) return;
        disposeAndError(Exception('Erro SEFAZ-BA: ${error.description}'));
      },
    );

    await webView.run();

    return completer.future.timeout(
      _timeout,
      onTimeout: () {
        try { webView.dispose(); } catch (_) {}
        throw Exception('Timeout ao acessar SEFAZ-BA.');
      },
    );
  }

  /// Roteador: detecta a SEFAZ pelo host da URL do QR.
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
