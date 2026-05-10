"""
Agente de progresso físico: analisa foto corporal e compara com foto anterior.
Análise qualitativa — nunca diagnóstico médico.
"""
from __future__ import annotations

import json
import os
import asyncio
import httpx

GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")

_PROMPT_PRIMEIRA_FOTO = """Você é um profissional de educação física avaliando composição corporal.
Esta é a PRIMEIRA foto de referência do usuário.

Descreva a composição corporal atual de forma qualitativa e encorajadora.
Analise: definição muscular visível, distribuição de massa, postura.

NÃO mencione peso estimado.
NÃO faça diagnósticos médicos.
SEMPRE inclua uma perspectiva encorajadora como referência inicial.

AVISO LEGAL: Estimativa visual para acompanhamento pessoal. Não substitui avaliação profissional.

Retorne APENAS JSON:
{
  "descricao_qualitativa": "descrição objetiva e respeitosa da composição atual",
  "comparacao_anterior": "primeira_foto",
  "areas_destaque": ["ombros", "abdômen"],
  "observacao_encorajadora": "frase motivacional específica ao que foi observado",
  "confianca": 0.72
}"""

_PROMPT_COMPARACAO = """Você é um profissional de educação física avaliando progresso corporal.
Compare as DUAS imagens — foto anterior (primeiro inline_data) e foto atual (segundo inline_data).

Analise: definição muscular, distribuição de gordura, proporções, mudanças visíveis entre os dois momentos.

NÃO mencione peso estimado.
NÃO faça diagnósticos médicos.
SEMPRE inclua uma perspectiva encorajadora.

AVISO LEGAL: Estimativa visual para acompanhamento pessoal. Não substitui avaliação profissional.

Retorne APENAS JSON:
{
  "descricao_qualitativa": "descrição das mudanças observadas entre as fotos",
  "comparacao_anterior": "positiva|neutra|negativa",
  "areas_destaque": ["área1", "área2"],
  "observacao_encorajadora": "frase motivacional específica ao progresso observado",
  "confianca": 0.72
}"""


def _get_gemini_key() -> str:
    key = os.environ.get("GEMINI_API_KEY", "")
    if not key:
        raise RuntimeError("GEMINI_API_KEY não configurada")
    return key


async def _chamar_gemini(parts: list[dict]) -> str:
    api_key = _get_gemini_key()
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"
    payload = {
        "contents": [{"parts": parts}],
        "generationConfig": {"temperature": 0.3, "maxOutputTokens": 1024},
    }
    last_err: Exception | None = None
    for tentativa in range(3):
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                resp = await client.post(url, params={"key": api_key}, json=payload)
                if resp.status_code in (429, 500, 502, 503, 504):
                    last_err = Exception(f"HTTP {resp.status_code}")
                    await asyncio.sleep(2 ** tentativa)
                    continue
                resp.raise_for_status()
                data = resp.json()
                return data["candidates"][0]["content"]["parts"][0]["text"]
        except (httpx.TimeoutException, httpx.ConnectError) as e:
            last_err = e
            await asyncio.sleep(2 ** tentativa)
    raise RuntimeError(f"Gemini falhou: {last_err}")


def _parse_json(texto: str) -> dict:
    try:
        return json.loads(texto)
    except json.JSONDecodeError:
        inicio = texto.find("{")
        fim = texto.rfind("}") + 1
        if inicio >= 0 and fim > inicio:
            return json.loads(texto[inicio:fim])
        raise ValueError("Não foi possível extrair JSON da resposta")


async def analisar_foto_progresso(
    imagem_base64: str,
    mime_type: str,
    foto_anterior_base64: str | None = None,
    mime_type_anterior: str | None = None,
) -> dict:
    """
    Analisa foto corporal e compara com a anterior (se disponível).
    Retorna análise qualitativa com JSON estruturado.
    """
    if foto_anterior_base64:
        parts = [
            {"inline_data": {"mime_type": mime_type_anterior or "image/jpeg", "data": foto_anterior_base64}},
            {"inline_data": {"mime_type": mime_type, "data": imagem_base64}},
            {"text": _PROMPT_COMPARACAO},
        ]
    else:
        parts = [
            {"inline_data": {"mime_type": mime_type, "data": imagem_base64}},
            {"text": _PROMPT_PRIMEIRA_FOTO},
        ]

    texto = await _chamar_gemini(parts)
    return _parse_json(texto)
