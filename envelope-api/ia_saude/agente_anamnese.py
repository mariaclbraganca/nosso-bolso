"""Agente de anamnese nutricional via chat com Gemini."""
from __future__ import annotations

import json
import os
import asyncio
import httpx

GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")

_SYSTEM_PROMPT = """Você é um nutricionista clínico realizando uma anamnese inicial.
Seu objetivo é coletar informações sobre o estilo de vida, hábitos, saúde e suplementação do usuário de forma natural e empática.

Faça uma pergunta por vez. Após cada resposta, faça uma pergunta de aprofundamento se necessário antes de avançar.

Tópicos obrigatórios a cobrir (nesta ordem):
1. Condições de saúde ou medicamentos em uso
2. Rotina de trabalho (sedentário, em pé, esforço físico)
3. Horários habituais de fome ao longo do dia
4. Alimentos que não gosta ou não pode comer (aversões e alergias/intolerâncias)
5. Suplementos utilizados regularmente (whey, creatina, ômega-3, vitaminas, etc.)
6. Exames de sangue recentes (opcional — aceite "não tenho" sem insistir)

Quando todos os tópicos estiverem cobertos, finalize a conversa com exatamente este JSON (sem texto antes ou depois):
{"finalizado": true, "dados": {"historico_saude": [], "medicamentos": [], "rotina_trabalho": "", "horarios_fome": [], "aversoes": [], "alergias": [], "suplementos": [{"nome": "", "dose": "", "proteina_g_por_dose": 0}], "bioquimica": {}, "observacoes_livres": ""}}

Se ainda há tópicos a cobrir, responda com texto normal (sem JSON)."""


def _get_gemini_key() -> str:
    key = os.environ.get("GEMINI_API_KEY", "")
    if not key:
        raise RuntimeError("GEMINI_API_KEY não configurada")
    return key


async def _chamar_gemini_chat(historico: list[dict]) -> str:
    """Envia histórico de mensagens para Gemini e retorna o texto da resposta."""
    api_key = _get_gemini_key()
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"

    contents = []
    for msg in historico:
        role = "user" if msg["role"] == "user" else "model"
        contents.append({"role": role, "parts": [{"text": msg["content"]}]})

    payload = {
        "system_instruction": {"parts": [{"text": _SYSTEM_PROMPT}]},
        "contents": contents,
        "generationConfig": {"temperature": 0.3, "maxOutputTokens": 4096},
    }

    last_err: Exception | None = None
    for tentativa in range(3):
        try:
            async with httpx.AsyncClient(timeout=45.0) as client:
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

    raise RuntimeError(f"Gemini chat falhou após retries: {last_err}")


def _tentar_parsear_finalizacao(texto: str) -> dict | None:
    """Tenta extrair o JSON de finalização da resposta do agente."""
    try:
        inicio = texto.find("{")
        fim = texto.rfind("}") + 1
        if inicio < 0 or fim <= inicio:
            return None
        candidato = json.loads(texto[inicio:fim])
        if candidato.get("finalizado") is True and "dados" in candidato:
            return candidato["dados"]
    except (json.JSONDecodeError, ValueError):
        pass
    return None


async def turno_anamnese(historico_mensagens: list[dict]) -> dict:
    """
    Processa um turno do chat de anamnese.

    Args:
        historico_mensagens: lista de {role: 'user'|'assistant', content: str}

    Returns:
        {
            resposta_agente: str,
            finalizado: bool,
            dados_estruturados: dict | None  # só presente quando finalizado=True
        }
    """
    resposta_texto = await _chamar_gemini_chat(historico_mensagens)
    dados = _tentar_parsear_finalizacao(resposta_texto)

    if dados is not None:
        return {
            "resposta_agente": "Perfeito! Coletei todas as informações necessárias. Vamos calcular seu perfil metabólico.",
            "finalizado": True,
            "dados_estruturados": dados,
        }

    return {
        "resposta_agente": resposta_texto.strip(),
        "finalizado": False,
        "dados_estruturados": None,
    }
