"""
Agente de monitoramento mensal: adesão, variação de peso (média móvel 7d — V24),
detecção de plateau, hidratação (V5), pausas (V14).
"""
from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from statistics import mean

from ia_saude.gemini_client import chamar_gemini


# ── Média Móvel — V24 ────────────────────────────────────────────────────────

def calcular_media_movel_peso(registros_peso: list[dict]) -> float | None:
    """
    Média dos últimos 7 registros de peso.
    NUNCA use pesagem isolada para decisões clínicas — apenas esta função.
    """
    if len(registros_peso) < 3:
        return None
    ordenados = sorted(registros_peso, key=lambda r: r.get("data_medicao", ""))
    ultimos = ordenados[-7:]
    return round(mean(r["peso_kg"] for r in ultimos), 2)


def detectar_plateau(media_atual: float | None, media_anterior: float | None) -> bool:
    """Plateau = menos de 200g de variação na média de 7 dias entre dois períodos."""
    if media_atual is None or media_anterior is None:
        return False
    return abs(media_atual - media_anterior) < 0.20


# ── Exclusão de pausas — V14 ──────────────────────────────────────────────────

def _em_periodo_pausa(data_str: str, pausas: list[dict]) -> bool:
    for pausa in pausas:
        inicio = pausa.get("inicio", "")
        fim = pausa.get("fim", "")
        if inicio and fim and inicio <= data_str <= fim:
            return True
    return False


def calcular_adesao_real(refeicoes_30_dias: list[dict], pausas: list[dict]) -> dict:
    """
    Calcula adesão excluindo dias de pausa (V14).
    Dia contabilizado = ao menos 1 refeição registrada (mesmo is_jejum=True).
    """
    dias_validos: set[str] = set()
    dias_com_registro: set[str] = set()

    for ref in refeicoes_30_dias:
        data = ref.get("data_refeicao", "")
        if not data or _em_periodo_pausa(data, pausas):
            continue
        dias_validos.add(data)
        if not ref.get("deleted_at"):
            dias_com_registro.add(data)

    total_validos = len(dias_validos)
    adesao = round(len(dias_com_registro) / total_validos * 100, 1) if total_validos else 0.0

    return {
        "dias_validos":         total_validos,
        "dias_com_registro":    len(dias_com_registro),
        "adesao_pct":           adesao,
        "dias_em_pausa":        sum(
            1 for ref in refeicoes_30_dias
            if _em_periodo_pausa(ref.get("data_refeicao", ""), pausas)
        ),
    }


# ── Gemini — análise narrativa ────────────────────────────────────────────────

async def _chamar_gemini(prompt: str) -> str:
    return await chamar_gemini({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.3, "maxOutputTokens": 1024},
    })


def _parse_json(texto: str) -> dict:
    try:
        return json.loads(texto)
    except json.JSONDecodeError:
        inicio = texto.find("{")
        fim = texto.rfind("}") + 1
        if inicio >= 0 and fim > inicio:
            return json.loads(texto[inicio:fim])
        raise ValueError("Não foi possível extrair JSON")


# ── Função principal ──────────────────────────────────────────────────────────

async def gerar_relatorio_mensal(membro_id: str) -> dict:
    """
    Gera relatório mensal de monitoramento.
    Usa média móvel de 7 dias para peso (V24).
    Exclui dias de pausa (V14).
    Inclui hidratação no diagnóstico de plateau (V5).
    """
    from ia_saude.mongo_client_saude import (
        get_perfil_metabolico_col,
        get_registro_refeicoes_col,
        get_registro_peso_col,
        get_registro_hidratacao_col,
        get_relatorio_monitoramento_col,
    )

    agora = datetime.now(timezone.utc)
    inicio_periodo = (agora - timedelta(days=30)).date().isoformat()
    fim_periodo = agora.date().isoformat()

    perfil = get_perfil_metabolico_col().find_one({"membro_id": membro_id})
    if not perfil:
        raise ValueError(f"Perfil não encontrado para membro {membro_id}")

    pausas = perfil.get("pausas", [])
    metabolico = perfil.get("metabolico", {})
    meta_kcal = metabolico.get("meta_calorica_kcal", 2000)
    tdee = metabolico.get("tdee_kcal", 2000)
    objetivo = metabolico.get("objetivo", "manutencao")

    # Refeições dos últimos 30 dias
    refeicoes = list(get_registro_refeicoes_col().find({
        "membro_id": membro_id,
        "data_refeicao": {"$gte": inicio_periodo, "$lte": fim_periodo},
    }))

    adesao_info = calcular_adesao_real(refeicoes, pausas)

    # Média calórica diária
    calorias_por_dia: dict[str, float] = {}
    for ref in refeicoes:
        if ref.get("deleted_at") or ref.get("is_jejum") or _em_periodo_pausa(ref.get("data_refeicao", ""), pausas):
            continue
        data = ref["data_refeicao"]
        calorias_por_dia[data] = calorias_por_dia.get(data, 0) + ref.get("macros_totais", {}).get("calorias_kcal", 0)

    media_calorica = round(mean(calorias_por_dia.values()), 1) if calorias_por_dia else 0.0

    # Registros de peso — média móvel V24
    pesos = list(get_registro_peso_col().find(
        {"membro_id": membro_id, "data_medicao": {"$gte": inicio_periodo}},
        sort=[("data_medicao", 1)],
    ))
    media_peso_atual = calcular_media_movel_peso(pesos[-7:])
    media_peso_inicial = calcular_media_movel_peso(pesos[:7]) if len(pesos) >= 7 else None
    variacao_peso = round(media_peso_atual - media_peso_inicial, 2) if (media_peso_atual and media_peso_inicial) else None

    # Progresso esperado
    deficit_real = tdee - media_calorica
    progresso_esperado_kg = round(deficit_real * 30 / 7700, 2) if objetivo == "perda_peso" else None

    # Plateau V24 — só detecta com dados suficientes
    plateau = False
    if len(pesos) >= 14:
        m1 = calcular_media_movel_peso(pesos[:7])
        m2 = calcular_media_movel_peso(pesos[-7:])
        plateau = detectar_plateau(m1, m2)

    # Hidratação média do período (V5)
    hidratacao_docs = list(get_registro_hidratacao_col().find({
        "membro_id": membro_id,
        "data": {"$gte": inicio_periodo, "$lte": fim_periodo},
    }))
    meta_agua = metabolico.get("meta_agua_ml", 0)
    hidratacao_media = round(mean(d["total_ml"] for d in hidratacao_docs), 0) if hidratacao_docs else 0
    hidratacao_insuficiente = meta_agua > 0 and hidratacao_media < meta_agua * 0.70

    # Monta prompt para análise narrativa do Gemini
    fatores_plateau = []
    if plateau:
        fatores_plateau.append("variação de peso < 200g entre os períodos")
    if hidratacao_insuficiente:
        fatores_plateau.append(f"hidratação insuficiente (média {hidratacao_media:.0f}ml de meta {meta_agua:.0f}ml)")

    prompt = f"""Você é um nutricionista clínico gerando um relatório mensal de acompanhamento.

DADOS DO PERÍODO ({inicio_periodo} a {fim_periodo}):
- Objetivo: {objetivo}
- Adesão ao plano: {adesao_info['adesao_pct']}% ({adesao_info['dias_com_registro']}/{adesao_info['dias_validos']} dias válidos)
- Dias em pausa (excluídos): {adesao_info['dias_em_pausa']}
- Média calórica diária: {media_calorica} kcal (meta: {meta_kcal} kcal)
- Variação de peso (média móvel 7d): {variacao_peso if variacao_peso is not None else 'dados insuficientes'} kg
- Progresso esperado: {progresso_esperado_kg if progresso_esperado_kg is not None else 'N/A'} kg
- Plateau detectado: {'sim — ' + ', '.join(fatores_plateau) if plateau else 'não'}
- Hidratação média: {hidratacao_media:.0f}ml / {meta_agua}ml meta

Gere uma análise empática e profissional. Se houve plateau, identifique possíveis causas.
Sugira ajuste de protocolo APENAS se plateau persistente ou adesão < 60%.
NÃO sugira restrição abaixo de 1.200 kcal/dia.

Retorne APENAS JSON:
{{
  "analise_narrativa": "análise completa em 3-5 frases",
  "ajuste_recomendado": {{
    "recomendar": true,
    "nova_meta_calorica_kcal": {meta_kcal},
    "nova_proteina_g": {metabolico.get('metas_macros', {{}}).get('proteina_total_g', 0)},
    "justificativa": "motivo do ajuste"
  }}
}}"""

    texto = await _chamar_gemini(prompt)
    gemini_resp = _parse_json(texto)

    resumo = {
        "periodo_inicio":         inicio_periodo,
        "periodo_fim":            fim_periodo,
        "dias_validos":           adesao_info["dias_validos"],
        "dias_com_registro":      adesao_info["dias_com_registro"],
        "dias_em_pausa":          adesao_info["dias_em_pausa"],
        "adesao_pct":             adesao_info["adesao_pct"],
        "media_calorica_kcal":    media_calorica,
        "meta_calorica_kcal":     meta_kcal,
        "variacao_peso_kg":       variacao_peso,
        "progresso_esperado_kg":  progresso_esperado_kg,
        "plateau_detectado":      plateau,
        "hidratacao_media_ml":    hidratacao_media,
        "meta_agua_ml":           meta_agua,
    }

    doc = {
        "membro_id":           membro_id,
        "familia_id":          perfil.get("familia_id"),
        "periodo_inicio":      inicio_periodo,
        "periodo_fim":         fim_periodo,
        "resumo":              resumo,
        "analise_ia":          gemini_resp.get("analise_narrativa", ""),
        "ajuste_recomendado":  gemini_resp.get("ajuste_recomendado", {}),
        "aprovado_usuario":    False,
        "criado_em":           agora,
    }

    col = get_relatorio_monitoramento_col()
    col.insert_one(doc)
    doc["_id"] = str(doc["_id"])

    return doc
