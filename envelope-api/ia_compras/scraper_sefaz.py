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
        if "<STATUS>FAILURE</STATUS>" in txt:
            # Portal aceitou a chave mas não tem dados — geralmente NFC-e
            # recém-emitida (ainda não indexada) ou em contingência
            raise SefazIndisponivelError(
                "Esta NFC-e ainda não está disponível no portal da SEFAZ-GO. "
                "Notas recém-emitidas levam alguns minutos (até horas) pra aparecer. "
                "Tente de novo mais tarde ou confirme abrindo a URL do QR no navegador."
            )
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


def _validar_conteudo_nota(html: str) -> None:
    """Garante que o HTML é uma NFC-e real e não uma página de erro/bloqueio
    da SEFAZ. Se for inválido, lança SefazIndisponivelError com mensagem útil
    pra UI — assim o LLM nunca recebe lixo (e não inventa dados).

    Detecções (algumas inspiradas no scraper Selenium antigo):
    - HTML muito curto / vazio
    - WAF: 'Acesso Negado' / 'Access Denied' / 'Forbidden'
    - Sessão: 'Sessão Expirada'
    - Erros explícitos da SEFAZ: 'Nota Fiscal não encontrada',
      'Chave de Acesso inválida', 'prazo de consulta expirado'
    - Heurística positiva: precisa ter ao menos uma palavra-chave de NFC-e
    """
    if not html or len(html) < 500:
        raise SefazIndisponivelError(
            "Conteúdo da NFC-e está vazio ou muito pequeno. "
            "A SEFAZ provavelmente não retornou os dados — tente novamente."
        )
    snippet = html[:3000].lower()

    # Bloqueios do WAF
    if any(s in snippet for s in ("acesso negado", "access denied", "forbidden", "blocked")):
        raise SefazIndisponivelError(
            "Portal SEFAZ bloqueou a consulta (Acesso Negado). "
            "Aguarde alguns minutos e tente de novo."
        )

    # Sessão expirada (acontece quando o digest da URL pública envelheceu)
    if "sessão expirada" in snippet or "sessao expirada" in snippet:
        raise SefazIndisponivelError(
            "A consulta expirou. Escaneie o QR code da NFC-e de novo."
        )

    # Erros explícitos da SEFAZ — chave inválida ou nota não cadastrada
    erros_explicitos = {
        "nota fiscal não encontrada": "Esta NFC-e não foi encontrada no portal da SEFAZ.",
        "chave de acesso inválida": "A chave de acesso da NFC-e é inválida.",
        "prazo de consulta expirado": "O prazo para consulta desta NFC-e expirou.",
        "houve um erro na operação": (
            "A SEFAZ não conseguiu processar a consulta desta nota. "
            "Pode ser muito recente — aguarde alguns minutos."
        ),
    }
    for marcador, msg in erros_explicitos.items():
        if marcador in snippet:
            raise SefazIndisponivelError(msg)

    # Heurística positiva: NFC-e real tem palavra-chave de produto/valor
    indicadores_nota = (
        "qtde", "vl. unit", "vl. total", "valor a pagar",
        "danfe", "nfc-e", "nfce", "tab_produtos", "txttit",
    )
    if not any(k in snippet for k in indicadores_nota):
        raise SefazIndisponivelError(
            "Resposta da SEFAZ não parece ser uma NFC-e válida — "
            "tente escanear o QR de novo."
        )


def extrair_valor_total_html(html: str) -> Optional[float]:
    """Tenta extrair o valor total da nota direto do HTML, sem depender do LLM.

    Devolve None se não conseguir.

    Estratégia em ordem (do mais específico pro mais frouxo):
    1) <span class="totalNumb txtMax"> — classe COMPOSTA usada pela SEFAZ-BA
       (e provavelmente outros estados que seguem o XSLT padrão da NFC-e).
       Esse span aparece exatamente uma vez na nota, no campo 'Valor a pagar'.
    2) Texto 'Valor a pagar R$:' seguido do número — pega SEFAZ-GO e fallback.
    3) Texto 'Valor Total R$:' como último recurso.

    NÃO usar 'span.totalNumb' sem composta — esse seletor pega 4+ spans
    diferentes (qtd itens, valor pago, tributos) e o primeiro é a qtd, não
    o valor total.
    """
    if not html:
        return None
    soup = BeautifulSoup(html, "html.parser")

    # 1) Compound class match: span DEVE ter ambas as classes
    for span in soup.find_all("span"):
        classes = span.get("class") or []
        if "totalNumb" in classes and "txtMax" in classes:
            v = _parse_valor_br(span.get_text(strip=True))
            if v is not None and v > 0:
                return v

    # 2) Texto "Valor a pagar R$:" seguido do número (pode ter quebra de linha)
    texto = soup.get_text(separator="\n")
    for padrao in (
        r"valor\s+a\s+pagar\s*r?\$?\s*:?\s*([\d\.]+,\d{2})",
        r"valor\s+total\s*r?\$?\s*:?\s*([\d\.]+,\d{2})",
    ):
        m = re.search(padrao, texto, re.IGNORECASE)
        if m:
            v = _parse_valor_br(m.group(1))
            if v is not None and v > 0:
                return v
    return None


def _parse_valor_br(s: str) -> Optional[float]:
    """Converte '1.234,56' (BR) ou '1234.56' (US) para float."""
    if not s:
        return None
    s = s.strip().replace("R$", "").strip()
    # heurística: se tem vírgula, é BR (vírgula = decimal, ponto = milhar)
    if "," in s:
        s = s.replace(".", "").replace(",", ".")
    try:
        return float(s)
    except ValueError:
        return None


def processar_html_pre_raspado(html_payload: str) -> str:
    """Aceita HTML já raspado pelo cliente (IP brasileiro residencial)
    e devolve o conteúdo útil para o LLM.

    Suporta dois formatos:
    - Envelope XML da SEFAZ-GO com <DANFE_NFCE_HTML>...</DANFE_NFCE_HTML>
      (faz duplo unescape pra resolver os entities)
    - HTML cru de qualquer outra SEFAZ (devolve como veio)

    Valida o conteúdo antes de devolver — se for página de erro/bloqueio,
    lança SefazIndisponivelError em vez de passar lixo pro LLM.
    """
    if not html_payload:
        raise ValueError("html_payload vazio")
    m = re.search(r"<DANFE_NFCE_HTML>(.+?)</DANFE_NFCE_HTML>", html_payload, re.DOTALL)
    conteudo = (
        html_lib.unescape(html_lib.unescape(m.group(1))) if m else html_payload
    )
    _validar_conteudo_nota(conteudo)
    return conteudo


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
            _validar_conteudo_nota(inner)
            return inner
        logger.warning("SEFAZ-GO: fallback para scraping genérico")

    conteudo = _scrape_generico(url_normalizada, sess, html_main)
    _validar_conteudo_nota(conteudo)
    return conteudo


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
