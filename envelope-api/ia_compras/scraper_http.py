"""Helpers HTTP para o scraper SEFAZ: sessão, retry, normalização de URL."""
import logging
import re
import time
from typing import Optional
from urllib.parse import parse_qs, urlparse

import requests

logger = logging.getLogger(__name__)

_UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)
_DEFAULT_TIMEOUT = 20


class SefazIndisponivelError(RuntimeError):
    """Erro específico quando o portal SEFAZ está respondendo 5xx — usado pra
    diferenciar de outros erros (rede, LLM, etc) na UI."""


def extrair_chave_acesso(qr_code_url: str) -> Optional[str]:
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


def normalizar_url_qr(qr_code_url: str) -> str:
    """Normaliza a URL do QR code para o formato esperado pela SEFAZ.

    Algumas URLs vêm sem o prefixo ?p= — ex:
      ?CHAVE|2|1|04|368.71|digest|3|hash
    O correto para a SEFAZ-GO aceitar é:
      ?p=CHAVE|2|1|04|368.71|digest|3|hash
    """
    parsed = urlparse(qr_code_url)
    query = parsed.query
    if not query:
        return qr_code_url
    qs = parse_qs(query)
    # Já tem ?p= — URL OK
    if "p" in qs:
        return qr_code_url
    # Checa se a query começa com 44 dígitos (chave) seguidos de |
    if re.match(r"\d{44}\|", query):
        base = qr_code_url.split("?", 1)[0]
        return f"{base}?p={query}"
    return qr_code_url


def criar_sessao() -> requests.Session:
    """Cria sessão HTTP com headers padrão de navegador."""
    sess = requests.Session()
    sess.headers.update({
        "User-Agent": _UA,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.8",
    })
    return sess


def build_session(qr_code_url: str) -> tuple[requests.Session, str]:
    """Cria sessão e visita a URL inicial para obter cookies (jsessionid etc.).

    Retry comedido (2 tentativas com 10s entre elas) — o WAF da SEFAZ-GO
    bloqueia IPs que martelam, então retry agressivo PIORA: prolonga o
    bloqueio. Se cair com 4xx/5xx, lança SefazIndisponivelError com
    mensagem útil pra UI sugerir aguardar."""
    sess = criar_sessao()
    last_status: int | None = None
    last_err: Exception | None = None
    for tentativa in range(2):
        try:
            resp = sess.get(
                qr_code_url, timeout=_DEFAULT_TIMEOUT, allow_redirects=True
            )
            if resp.status_code in (403, 429, 500, 502, 503, 504):
                last_status = resp.status_code
                last_err = requests.HTTPError(
                    f"{resp.status_code} {resp.reason}", response=resp
                )
                logger.warning(
                    "SEFAZ retornou %s na tentativa %d/2", resp.status_code, tentativa + 1
                )
                if tentativa == 0:
                    time.sleep(10)
                continue
            resp.raise_for_status()
            resp.encoding = resp.encoding or "ISO-8859-1"
            return sess, resp.text
        except requests.RequestException as e:
            last_err = e
            if tentativa == 0:
                time.sleep(10)

    if last_status:
        if last_status in (403, 429):
            raise SefazIndisponivelError(
                "Portal SEFAZ está bloqueando temporariamente nossas requisições "
                "(rate limit). Aguarde 5-10 minutos e tente novamente."
            ) from last_err
        if 500 <= last_status < 600:
            raise SefazIndisponivelError(
                f"Portal SEFAZ indisponível (HTTP {last_status}). "
                f"Tente novamente em alguns minutos."
            ) from last_err
    raise last_err or RuntimeError("Falha ao acessar URL da NFC-e")
