import os
import httpx
from enum import Enum

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434/api/generate")
OLLAMA_TIMEOUT = 5.0
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
GEMINI_MODEL = "gemini-2.0-flash"


class LLMProvider(str, Enum):
    OLLAMA = "ollama"
    GEMINI = "gemini"


async def extrair_com_fallback(html_bruto: str, schema: dict) -> tuple[dict, LLMProvider]:
    try:
        async with httpx.AsyncClient(timeout=OLLAMA_TIMEOUT) as client:
            resp = await client.post(OLLAMA_URL, json={
                "model": "gemma3:12b",
                "prompt": _montar_prompt_extracao(html_bruto, schema),
                "stream": False
            })
            resp.raise_for_status()
            return _parse_response(resp.json()), LLMProvider.OLLAMA
    except (httpx.TimeoutException, httpx.ConnectError, httpx.HTTPStatusError):
        resultado = await _chamar_gemini_flash(html_bruto, schema)
        return resultado, LLMProvider.GEMINI


def _montar_prompt_extracao(html_bruto: str, schema: dict) -> str:
    return (
        f"Extraia os dados da nota fiscal no HTML abaixo seguindo este schema JSON: {schema}\n\n"
        f"Retorne APENAS JSON valido, sem markdown ou explicacoes.\n\n"
        f"HTML: {html_bruto[:8000]}"
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


async def _chamar_gemini_flash(html_bruto: str, schema: dict) -> dict:
    import json
    prompt = _montar_prompt_extracao(html_bruto, schema)
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(url, params={"key": GEMINI_API_KEY}, json={
            "contents": [{"parts": [{"text": prompt}]}],
        })
        resp.raise_for_status()
        data = resp.json()
        text = data["candidates"][0]["content"]["parts"][0]["text"]
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            start = text.find("{")
            end = text.rfind("}") + 1
            return json.loads(text[start:end])
