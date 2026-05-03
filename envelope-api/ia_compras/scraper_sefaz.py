import requests
from bs4 import BeautifulSoup
from typing import Optional


def raspar_nfce(qr_code_url: str) -> Optional[str]:
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept": "text/html,application/xhtml+xml",
    }
    resp = requests.get(qr_code_url, headers=headers, timeout=15)
    resp.raise_for_status()
    return resp.text


def extrair_texto_nota(html: str) -> str:
    soup = BeautifulSoup(html, "html.parser")
    for tag in soup(["script", "style", "noscript"]):
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
