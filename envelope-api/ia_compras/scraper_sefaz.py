"""Scraper SEFAZ: raspagem de NFC-e a partir de URL ou HTML pré-raspado."""
import html as html_lib
import logging
import re
from typing import Optional
from urllib.parse import urlparse

from bs4 import BeautifulSoup

from ia_compras.scraper_http import (
    SefazIndisponivelError,
    build_session,
    criar_sessao,
    extrair_chave_acesso as _extrair_chave_acesso,
    normalizar_url_qr as _normalizar_url_qr,
    _DEFAULT_TIMEOUT,
)

logger = logging.getLogger(__name__)

# Re-export para quem importa de scraper_sefaz
SefazIndisponivelError = SefazIndisponivelError


def _scrape_sefaz_go(sess, chave: str) -> Optional[str]:
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


def _scrape_generico(qr_code_url: str, sess, html_main: str) -> str:
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


def processar_html_pre_raspado(html_payload: str) -> str:
    """Aceita HTML já raspado pelo cliente (IP brasileiro residencial)
    e devolve o conteúdo útil para o LLM.

    Suporta dois formatos:
    - Envelope XML da SEFAZ-GO com <DANFE_NFCE_HTML>...</DANFE_NFCE_HTML>
      (faz duplo unescape pra resolver os entities)
    - HTML cru de qualquer outra SEFAZ (devolve como veio)
    """
    if not html_payload:
        raise ValueError("html_payload vazio")
    m = re.search(r"<DANFE_NFCE_HTML>(.+?)</DANFE_NFCE_HTML>", html_payload, re.DOTALL)
    if m:
        return html_lib.unescape(html_lib.unescape(m.group(1)))
    return html_payload


def _tentar_sefaz_go_direto(chave: str) -> Optional[str]:
    """Fallback: tenta acessar SEFAZ-GO diretamente via render/danfeNFCe
    sem depender da URL pública (que pode dar 500 com digest inválido).

    Cria sessão limpa, visita o render/ para cookies e chama o AJAX."""
    sess = criar_sessao()
    try:
        inner = _scrape_sefaz_go(sess, chave)
        if inner:
            return inner
    except Exception as e:
        logger.warning("Fallback direto SEFAZ-GO falhou: %s", e)
    return None


def raspar_nfce(qr_code_url: str) -> str:
    """Baixa o HTML da NFC-e a partir da URL do QR code.

    Retorna sempre uma string com o HTML mais completo possível (já com unescape
    quando aplicável). O parsing/limpeza é feito por extrair_texto_nota().

    Em produção (Render AWS US-East) a SEFAZ-GO bloqueia IPs de data center,
    então o caminho real é o app raspar do celular e enviar via
    processar_html_pre_raspado(). Esta função fica como fallback.
    """
    if not qr_code_url:
        raise ValueError("qr_code_url vazio")

    chave = _extrair_chave_acesso(qr_code_url)
    host = urlparse(qr_code_url).netloc.lower()
    url_normalizada = _normalizar_url_qr(qr_code_url)

    try:
        sess, html_main = build_session(url_normalizada)
    except SefazIndisponivelError:
        # URL pública falhou — tentar via chave direto na SEFAZ-GO
        if "sefaz.go.gov.br" in host and chave:
            logger.info("URL pública falhou, tentando SEFAZ-GO direto via chave")
            inner = _tentar_sefaz_go_direto(chave)
            if inner:
                return inner
        raise

    if "sefaz.go.gov.br" in host and chave:
        inner = _scrape_sefaz_go(sess, chave)
        if inner:
            return inner
        logger.warning("SEFAZ-GO: fallback para scraping genérico")

    return _scrape_generico(url_normalizada, sess, html_main)


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
