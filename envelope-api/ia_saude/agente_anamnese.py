"""Agente de anamnese nutricional via chat com Gemini."""
from __future__ import annotations

import json

from ia_saude.gemini_client import chamar_gemini

# Prompt comprimido: remove instruções redundantes, mantém estrutura
_SYSTEM_PROMPT = """Nutricionista clínico em anamnese inicial. Uma pergunta por vez, aprofunde se necessário.

Tópicos obrigatórios (nesta ordem):
1. Condições de saúde / medicamentos
2. Rotina de trabalho (sedentário/em pé/esforço físico)
3. Horários de fome
4. Aversões e alergias/intolerâncias
5. Suplementos (nome, dose)
6. Exames de sangue recentes (opcional — aceite "não tenho")

Ao cobrir todos, retorne SOMENTE este JSON (sem texto extra):
{"finalizado":true,"dados":{"historico_saude":[],"medicamentos":[],"rotina_trabalho":"","horarios_fome":[],"aversoes":[],"alergias":[],"suplementos":[{"nome":"","dose":"","proteina_g_por_dose":0}],"bioquimica":{},"observacoes_livres":""}}

Enquanto houver tópicos pendentes, responda em texto normal."""


def _tentar_parsear_finalizacao(texto: str) -> dict | None:
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
    """Processa um turno do chat de anamnese."""
    contents = [
        {
            "role": "user" if m["role"] == "user" else "model",
            "parts": [{"text": m["content"]}],
        }
        for m in historico_mensagens
    ]
    payload = {
        "systemInstruction": {"parts": [{"text": _SYSTEM_PROMPT}]},
        "contents": contents,
        "generationConfig": {"temperature": 0.3, "maxOutputTokens": 1024},
    }

    resposta_texto = await chamar_gemini(payload)
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
