import os
import httpx
from enum import Enum

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434/api/generate")
OLLAMA_TIMEOUT = 5.0
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")


def _get_gemini_keys_disponiveis() -> list[str]:
    """Retorna todas as chaves Gemini configuradas no ambiente (KEY, KEY_1, KEY_2, KEY_3)."""
    chaves = []
    for sufixo in ("", "_1", "_2", "_3"):
        k = os.environ.get(f"GEMINI_API_KEY{sufixo}", "").strip()
        if k and k not in chaves:
            chaves.append(k)
    return chaves


def _get_gemini_key(familia_id: str = "") -> str:
    """Retorna a primeira chave disponível: família > env numeradas > env simples."""
    if familia_id:
        from routes.configuracoes import get_gemini_key
        chave_familia = get_gemini_key(familia_id)
        if chave_familia:
            return chave_familia
    chaves = _get_gemini_keys_disponiveis()
    return chaves[0] if chaves else ""


class LLMProvider(str, Enum):
    OLLAMA = "ollama"
    GEMINI = "gemini"


async def extrair_com_fallback(html_bruto: str, schema: dict, familia_id: str = "") -> tuple[dict, LLMProvider]:
    try:
        async with httpx.AsyncClient(timeout=OLLAMA_TIMEOUT) as client:
            resp = await client.post(OLLAMA_URL, json={
                "model": "gemma3:12b",
                "prompt": _montar_prompt_extracao(html_bruto, schema),
                "stream": False
            })
            resp.raise_for_status()
            return _parse_response(resp.json()), LLMProvider.OLLAMA
    except (httpx.TimeoutException, httpx.ConnectError, httpx.HTTPStatusError, ValueError):
        resultado = await _chamar_gemini_flash(html_bruto, schema, familia_id)
        return resultado, LLMProvider.GEMINI


def _sanitizar_texto(texto: str) -> str:
    """Remove caracteres de controle e substitui sequências que quebram JSON no Gemini."""
    # Remove caracteres de controle exceto newline/tab
    import re
    texto = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]', '', texto)
    # Garante que é UTF-8 válido
    texto = texto.encode('utf-8', errors='replace').decode('utf-8')
    return texto


def _montar_prompt_extracao(html_bruto: str, schema: dict) -> str:
    import json
    texto_limpo = _sanitizar_texto(html_bruto[:10000])
    return (
        "Extrator NFC-e. Schema:\n"
        f"{json.dumps(schema, ensure_ascii=False)}\n\n"
        "Regras: data_compra=YYYY-MM-DD | valor_total=explícito na nota (não some) | "
        "decimais com ponto | nome_padronizado=sem abreviações | "
        "categoria=enum exato | todos os itens | retorne APENAS JSON sem markdown.\n\n"
        f"FONTE:\n{texto_limpo}"
    )


def _parse_response(raw: dict) -> dict:
    import json
    text = raw.get("response", raw.get("text", "{}"))
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        start = text.find("{")
        end = text.rfind("}") + 1
        if start >= 0 and end > start:
            return json.loads(text[start:end])
        raise ValueError("Nao foi possivel extrair JSON da resposta")


async def _chamar_gemini_flash(html_bruto: str, schema: dict, familia_id: str = "") -> dict:
    import json
    import asyncio

    # Monta pool de chaves: família tem prioridade, depois as do Render
    chave_familia = ""
    if familia_id:
        from routes.configuracoes import get_gemini_key
        chave_familia = get_gemini_key(familia_id)
    chaves_env = _get_gemini_keys_disponiveis()
    # Deduplicar mantendo ordem: família primeiro
    todas_chaves: list[str] = []
    if chave_familia and chave_familia not in todas_chaves:
        todas_chaves.append(chave_familia)
    for k in chaves_env:
        if k not in todas_chaves:
            todas_chaves.append(k)

    if not todas_chaves:
        raise RuntimeError("GEMINI_API_KEY não configurada")

    prompt = _montar_prompt_extracao(html_bruto, schema)
    modelo = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{modelo}:generateContent"
    last_err: Exception | None = None

    for api_key in todas_chaves:
        for tentativa in range(2):
            try:
                async with httpx.AsyncClient(timeout=45.0) as client:
                    resp = await client.post(url, params={"key": api_key}, json={
                        "contents": [{"parts": [{"text": prompt}]}],
                    })
                    if resp.status_code in (429, 500, 502, 503, 504):
                        last_err = httpx.HTTPStatusError(
                            f"{resp.status_code}", request=resp.request, response=resp
                        )
                        await asyncio.sleep(2 ** tentativa)
                        continue
                    if resp.status_code == 400:
                        # Chave inválida — tenta a próxima sem retry
                        last_err = httpx.HTTPStatusError(
                            f"400 key={api_key[:8]}...", request=resp.request, response=resp
                        )
                        break
                    resp.raise_for_status()
                    data = resp.json()
                    text = data["candidates"][0]["content"]["parts"][0]["text"]
                    try:
                        return json.loads(text)
                    except json.JSONDecodeError:
                        start = text.find("{")
                        end = text.rfind("}") + 1
                        return json.loads(text[start:end])
            except (httpx.TimeoutException, httpx.ConnectError) as e:
                last_err = e
                await asyncio.sleep(2 ** tentativa)

    raise RuntimeError(f"Gemini falhou com todas as chaves: {last_err}")
