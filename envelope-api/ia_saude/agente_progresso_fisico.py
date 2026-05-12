"""
Agente de progresso físico: analisa foto corporal e compara com foto anterior.
Análise qualitativa — nunca diagnóstico médico.
"""
from __future__ import annotations

import json

from ia_saude.gemini_client import chamar_gemini

_AVISO = "Estimativa visual para acompanhamento pessoal. Não substitui avaliação profissional."
_SCHEMA = '{"descricao_qualitativa":"","comparacao_anterior":"primeira_foto|positiva|neutra|negativa","areas_destaque":[],"observacao_encorajadora":"","confianca":0.0}'

_PROMPT_PRIMEIRA_FOTO = f"""Prof. de educação física avaliando composição corporal — PRIMEIRA foto de referência.
Analise: definição muscular, distribuição de massa, postura. Seja encorajador. Não mencione peso nem faça diagnósticos.
{_AVISO}
Retorne APENAS JSON: {_SCHEMA} (comparacao_anterior="primeira_foto")"""

_PROMPT_COMPARACAO = f"""Prof. de educação física comparando progresso — foto anterior (1ª imagem) vs atual (2ª imagem).
Analise mudanças em definição, gordura e proporções. Seja encorajador. Não mencione peso nem faça diagnósticos.
{_AVISO}
Retorne APENAS JSON: {_SCHEMA} (comparacao_anterior: positiva|neutra|negativa)"""


async def _chamar_gemini(parts: list[dict]) -> str:
    return await chamar_gemini({
        "contents": [{"parts": parts}],
        "generationConfig": {"temperature": 0.3, "maxOutputTokens": 512},
    })


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
