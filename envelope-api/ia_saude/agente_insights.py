"""Astrix Insights: relatório semanal com IA correlacionando finanças, nutrição e exercício."""
from __future__ import annotations

import json
from datetime import datetime, timedelta

from ia_saude.gemini_client import chamar_gemini

_PROMPT = """Você é o Astrix, mascote e coach de bem-estar financeiro e de saúde do app Nosso Bolso.
Analise os dados da semana e gere um relatório em JSON com insights acionáveis, celebrações e alertas.

Dados da semana:
{dados}

Retorne APENAS JSON (sem markdown) com esta estrutura:
{{
  "saudacao": "mensagem curta e animada do Astrix (max 30 palavras, tom amigável)",
  "score_geral": <0-100 baseado nos 3 módulos>,
  "destaques": [
    {{"emoji": "🏆", "titulo": "titulo curto", "texto": "max 25 palavras"}}
  ],
  "alertas": [
    {{"emoji": "⚠️", "titulo": "titulo curto", "texto": "max 25 palavras"}}
  ],
  "dica_semana": "dica prática e específica baseada nos dados (max 40 palavras)",
  "financeiro_score": <0-100>,
  "nutricao_score": <0-100>,
  "exercicio_score": <0-100>
}}

Regras:
- destaques: 1-3 itens, apenas se houver algo positivo genuíno
- alertas: 0-2 itens, apenas se houver problema real
- Seja específico com números dos dados (ex: "você treinou 4x" não "você treinou bastante")
- Tom: animado, encorajador, sem ser piegas
- Se dados faltarem para um módulo, score=50 e ignore esse módulo nos insights
"""


async def gerar_insights_semanais(dados: dict) -> dict:
    dados_str = json.dumps(dados, ensure_ascii=False, indent=2)
    prompt    = _PROMPT.format(dados=dados_str)

    raw = await chamar_gemini({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.3,
            "maxOutputTokens": 1500,
            "thinkingConfig": {"thinkingBudget": 0},
        },
    })

    raw = raw.strip()

    # Remove markdown fences em qualquer formato (```json, ```, etc.)
    if "```" in raw:
        for part in raw.split("```"):
            part = part.strip()
            if part.startswith("json"):
                part = part[4:].strip()
            if part.startswith("{"):
                raw = part
                break

    # Extrai o primeiro objeto JSON da string, caso haja texto antes/depois
    start = raw.find("{")
    end   = raw.rfind("}")
    if start != -1 and end != -1 and end > start:
        raw = raw[start : end + 1]

    try:
        return json.loads(raw)
    except Exception:
        return {
            "saudacao": "Tô aqui analisando sua semana! 🦄",
            "score_geral": 70,
            "destaques": [],
            "alertas": [],
            "dica_semana": "Continue registrando seus dados para insights mais precisos!",
            "financeiro_score": 70,
            "nutricao_score": 70,
            "exercicio_score": 70,
        }


def resumir_semana_financeira(familia_id: str) -> dict:
    """Busca resumo financeiro dos últimos 7 dias via Supabase (PostgreSQL)."""
    try:
        from database import get_supabase
        inicio = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")
        sb = get_supabase()
        res = (
            sb.table("transacoes")
            .select("valor, tipo")
            .eq("familia_id", familia_id)
            .gte("data", inicio)
            .is_("deleted_at", "null")
            .limit(50)
            .execute()
        )
        transacoes = res.data or []
        total_gastos  = sum(t.get("valor", 0) for t in transacoes if t.get("tipo") == "gasto")
        total_receita = sum(t.get("valor", 0) for t in transacoes if t.get("tipo") == "receita")
        return {
            "total_gastos_7d":  round(total_gastos, 2),
            "total_receita_7d": round(total_receita, 2),
            "num_transacoes":   len(transacoes),
        }
    except Exception:
        return {}


def resumir_semana_nutricional(membro_id: str) -> dict:
    """Busca registros de refeição dos últimos 7 dias."""
    try:
        from ia_saude.mongo_client_saude import get_registro_refeicoes_col, get_perfil_metabolico_col
        from datetime import datetime, timedelta

        hoje  = datetime.now()
        datas = [(hoje - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(7)]

        col      = get_registro_refeicoes_col()
        refeicoes = list(col.find(
            {"membro_id": membro_id, "data_refeicao": {"$in": datas}, "deleted_at": None},
            {"calorias_kcal": 1, "data_refeicao": 1},
        ))

        perfil_col = get_perfil_metabolico_col()
        perfil     = perfil_col.find_one({"membro_id": membro_id}) or {}
        meta       = perfil.get("metabolico", {}).get("meta_calorica_kcal", 2000)

        dias_com_registro = len({r["data_refeicao"] for r in refeicoes})
        media_kcal        = (
            sum(r.get("calorias_kcal", 0) for r in refeicoes) / max(dias_com_registro, 1)
        )

        return {
            "dias_com_registro": dias_com_registro,
            "media_kcal_dia":    round(media_kcal),
            "meta_kcal":         round(meta),
            "pct_meta":          round(media_kcal / max(meta, 1) * 100),
        }
    except Exception:
        return {}


def resumir_semana_exercicio(membro_id: str) -> dict:
    """Busca registros de exercício dos últimos 7 dias."""
    try:
        from ia_saude.mongo_client_saude import get_registro_exercicio_col
        from datetime import datetime, timedelta

        hoje  = datetime.now()
        datas = [(hoje - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(7)]

        col  = get_registro_exercicio_col()
        docs = list(col.find({"membro_id": membro_id, "data": {"$in": datas}}))

        dias_com_treino = len(docs)
        total_kcal      = sum(d.get("total_calorias_kcal", 0) for d in docs)
        total_min       = sum(d.get("total_duracao_min", 0) for d in docs)

        return {
            "dias_com_treino": dias_com_treino,
            "total_kcal":      total_kcal,
            "total_min":       total_min,
        }
    except Exception:
        return {}
