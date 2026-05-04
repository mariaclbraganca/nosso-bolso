import html as html_lib
import logging
import re
from typing import Optional
from urllib.parse import parse_qs, urlparse

import requests
from bs4 import BeautifulSoup

logger = logging.getLogger(__name__)

_UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)
_DEFAULT_TIMEOUT = 20


def _extrair_chave_acesso(qr_code_url: str) -> Optional[str]:
    """Extrai a chave de acesso (44 dígitos) da URL do QR code da NFC-e.

    Formatos suportados:
      - ?p=<44dig>|...
      - ?chNFe=<44dig>
      - ?chave=<44dig>
      - chave embutida em qualquer parâmetro
    """
    try:
        qs = parse_qs(urlparse(qr_code_url).query)
    except Exception:
        qs = {}

    # ?p=CHAVE|...
    if "p" in qs and qs["p"]:
        primeiro = qs["p"][0].split("|")[0]
        if re.fullmatch(r"\d{44}", primeiro):
            return primeiro

    for key in ("chNFe", "chave", "chaveAcesso"):
        if key in qs and qs[key]:
            valor = qs[key][0]
            if re.fullmatch(r"\d{44}", valor):
                return valor

    m = re.search(r"\d{44}", qr_code_url)
    if m:
        return m.group(0)
    return None


def _build_session(qr_code_url: str) -> tuple[requests.Session, str]:
    """Cria sessão e visita a URL inicial para obter cookies (jsessionid etc.).

    Com retry porque os portais SEFAZ ficam intermitentes (5xx esporádicos)."""
    import time
    sess = requests.Session()
    sess.headers.update({
        "User-Agent": _UA,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.8",
    })
    last_err: Exception | None = None
    for tentativa in range(3):
        try:
            resp = sess.get(
                qr_code_url, timeout=_DEFAULT_TIMEOUT, allow_redirects=True
            )
            if resp.status_code in (500, 502, 503, 504):
                last_err = requests.HTTPError(
                    f"{resp.status_code} {resp.reason}", response=resp
                )
                time.sleep(2 ** tentativa)
                continue
            resp.raise_for_status()
            resp.encoding = resp.encoding or "ISO-8859-1"
            return sess, resp.text
        except requests.RequestException as e:
            last_err = e
            time.sleep(2 ** tentativa)
    raise last_err or RuntimeError("Falha ao acessar URL da NFC-e")


def _scrape_sefaz_go(sess: requests.Session, chave: str) -> Optional[str]:
    """SEFAZ-GO entrega o conteúdo da NFC-e numa chamada AJAX que devolve XML
    com o HTML escapado dentro de <DANFE_NFCE_HTML>...</DANFE_NFCE_HTML>.
    Esta chamada precisa do cookie de sessão e do header Referer apontando
    para a URL do iframe (/render/danfeNFCe), não a URL pública do QR."""
    base = "https://nfeweb.sefaz.go.gov.br"
    url_iframe = f"{base}/nfeweb/sites/nfce/render/danfeNFCe?chNFe={chave}"
    url_html = f"{base}/nfeweb/sites/nfce/render/html/danfeNFCe?chNFe={chave}"
    headers = {
        "Referer": url_iframe,
        "X-Requested-With": "XMLHttpRequest",
        "Accept": "application/xhtml+xml,application/xml,text/html;q=0.9,*/*;q=0.8",
    }
    resp = sess.get(url_html, headers=headers, timeout=_DEFAULT_TIMEOUT)
    resp.encoding = "ISO-8859-1"
    if resp.status_code != 200:
        logger.warning("SEFAZ-GO render/html retornou %s", resp.status_code)
        return None
    txt = resp.text
    if "<STATUS>SUCCESS</STATUS>" not in txt:
        logger.warning("SEFAZ-GO render/html retornou status != SUCCESS: %s", txt[:200])
        return None
    m = re.search(r"<DANFE_NFCE_HTML>(.+?)</DANFE_NFCE_HTML>", txt, re.DOTALL)
    if not m:
        return None
    # Duplo unescape: SEFAZ-GO embute o HTML dentro de XML, então tags vêm como
    # &lt;tag&gt; e entidades de acento como &amp;Ocirc;. Primeiro unescape
    # devolve o HTML real (com &Ocirc;); o segundo resolve os acentos para
    # caracteres unicode (Ô, ç, ã etc.).
    return html_lib.unescape(html_lib.unescape(m.group(1)))


def _scrape_generico(qr_code_url: str, sess: requests.Session, html_main: str) -> str:
    """Fallback: tenta seguir iframes/links comuns das SEFAZ.

    Estratégia: além do HTML principal, baixa o conteúdo de iframes internos
    (mesmo domínio) e concatena tudo, dando à LLM o máximo de contexto possível.
    """
    soup = BeautifulSoup(html_main, "html.parser")
    pedacos = [html_main]
    base_origin = urlparse(qr_code_url)
    base_origin_str = f"{base_origin.scheme}://{base_origin.netloc}"

    for iframe in soup.find_all("iframe"):
        src = iframe.get("src")
        if not src:
            continue
        if src.startswith("/"):
            src = base_origin_str + src
        elif src.startswith("http") is False:
            continue
        try:
            r = sess.get(
                src,
                headers={"Referer": qr_code_url},
                timeout=_DEFAULT_TIMEOUT,
            )
            r.encoding = r.encoding or "ISO-8859-1"
            pedacos.append(r.text)
        except Exception as e:
            logger.warning("Falha ao baixar iframe %s: %s", src, e)
    return "\n".join(pedacos)


def raspar_nfce(qr_code_url: str) -> str:
    """Baixa o HTML da NFC-e a partir da URL do QR code.

    Diferente da SEFAZ a SEFAZ, mas tipicamente a primeira URL retorna apenas
    a moldura/iframe — os dados reais vêm de uma segunda chamada que precisa
    dos cookies de sessão da primeira. Esta função encapsula esse fluxo.

    Retorna sempre uma string com o HTML mais completo possível (já com unescape
    quando aplicável). O parsing/limpeza é feito por extrair_texto_nota().
    """
    if not qr_code_url:
        raise ValueError("qr_code_url vazio")

    sess, html_main = _build_session(qr_code_url)
    host = urlparse(qr_code_url).netloc.lower()
    chave = _extrair_chave_acesso(qr_code_url)

    if "sefaz.go.gov.br" in host and chave:
        inner = _scrape_sefaz_go(sess, chave)
        if inner:
            return inner
        logger.warning("SEFAZ-GO: fallback para scraping genérico")

    return _scrape_generico(qr_code_url, sess, html_main)


def extrair_texto_nota(html: str) -> str:
    """Limpa scripts/estilos e devolve apenas o texto visível da NFC-e."""
    if not html:
        return ""
    soup = BeautifulSoup(html, "html.parser")
    for tag in soup(["script", "style", "noscript", "link", "meta"]):
        tag.decompose()
    texts = soup.get_text(separator="\n")
    linhas = [l.strip() for l in texts.splitlines() if l.strip()]
    return "\n".join(linhas)


def extrair_xml_nfce(html: str) -> Optional[str]:
    soup = BeautifulSoup(html, "html.parser")
    pre = soup.find("pre")
    if pre:
        return pre.get_text()
    for tag in soup.find_all(["textarea", "code"]):
        content = tag.get_text()
        if "<?xml" in content or "<nfeProc" in content:
            return content
    return None
