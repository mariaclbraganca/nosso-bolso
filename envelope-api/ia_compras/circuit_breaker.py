import os
import httpx
from enum import Enum

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434/api/generate")
OLLAMA_TIMEOUT = 5.0
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")


def _get_gemini_key(familia_id: str = "") -> str:
    if familia_id:
        from routes.configuracoes import get_gemini_key
        return get_gemini_key(familia_id)
    return os.environ.get("GEMINI_API_KEY", "")


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
    api_key = _get_gemini_key(familia_id)
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY não configurada")
    prompt = _montar_prompt_extracao(html_bruto, schema)
    # tenta o modelo principal e cai para gemini-flash-latest se a quota/zona estiver fora
    modelos = [GEMINI_MODEL]
    if "gemini-flash-latest" not in modelos:
        modelos.append("gemini-flash-latest")
    last_err: Exception | None = None
    for modelo in modelos:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{modelo}:generateContent"
        for tentativa in range(3):
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
    raise RuntimeError(f"Gemini falhou após retries: {last_err}")
