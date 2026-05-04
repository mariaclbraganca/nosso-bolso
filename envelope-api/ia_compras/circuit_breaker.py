import os
import httpx
from enum import Enum

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434/api/generate")
OLLAMA_TIMEOUT = 5.0
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")


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
    except (httpx.TimeoutException, httpx.ConnectError, httpx.HTTPStatusError, ValueError):
        resultado = await _chamar_gemini_flash(html_bruto, schema)
        return resultado, LLMProvider.GEMINI


def _montar_prompt_extracao(html_bruto: str, schema: dict) -> str:
    import json
    return (
        "Você é um extrator de dados de notas fiscais brasileiras (NFC-e).\n"
        "Extraia os dados do texto/HTML abaixo seguindo ESTRITAMENTE este schema JSON:\n"
        f"{json.dumps(schema, ensure_ascii=False, indent=2)}\n\n"
        "Regras IMPORTANTES:\n"
        "- 'data_compra' deve estar no formato YYYY-MM-DD (procure por 'Emissão' ou 'Data').\n"
        "- 'valor_total' é o valor a pagar TOTAL da nota (não soma manualmente; use o explícito).\n"
        "- Use vírgula como separador decimal no source mas converta para PONTO no JSON (10,99 → 10.99).\n"
        "- 'nome_padronizado' deve expandir abreviações comuns (ex: 'Mac Inst Nissin Mioj' → 'Macarrão Instantâneo Nissin Miojo').\n"
        "- 'categoria' deve ser EXATAMENTE um dos valores do enum (case-sensitive, com acentos).\n"
        "- Inclua TODOS os itens da nota, mesmo repetidos.\n"
        "- Retorne APENAS o JSON, sem markdown, sem ```json, sem explicações.\n\n"
        f"FONTE:\n{html_bruto[:15000]}"
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
    import asyncio
    if not GEMINI_API_KEY:
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
                    resp = await client.post(url, params={"key": GEMINI_API_KEY}, json={
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
