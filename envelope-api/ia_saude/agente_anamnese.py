"""Agente de anamnese nutricional via chat com Gemini."""
from __future__ import annotations

import json

from ia_saude.gemini_client import chamar_gemini

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
    """
    Processa um turno do chat de anamnese.

    Args:
        historico_mensagens: lista de {role: 'user'|'assistant', content: str}

    Returns:
        { resposta_agente, finalizado, dados_estruturados }
    """
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
        "generationConfig": {"temperature": 0.3, "maxOutputTokens": 4096},
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
