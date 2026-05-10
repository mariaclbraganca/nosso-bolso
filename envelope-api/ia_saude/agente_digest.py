"""
Agente de Morning Digest (V25): consolida dados de todos os módulos em um único
resumo matinal — 1 push notification às 08:00 em vez de micro-alertas dispersos.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone


async def gerar_morning_digest(membro_id: str, familia_id: str) -> dict:
    """
    Consolida: saldo financeiro, meta calórica, estoque crítico,
    hidratação de ontem, sugestão de jantar pré-carregada.
    """
    import asyncio
    from ia_saude.mongo_client_saude import (
        get_perfil_metabolico_col,
        get_registro_refeicoes_col,
        get_registro_hidratacao_col,
    )
    from ia_compras.agente_estoque import analisar_estoque

    agora = datetime.now(timezone.utc)
    hoje = agora.date().isoformat()
    ontem = (agora.date() - timedelta(days=1)).isoformat()

    perfil = get_perfil_metabolico_col().find_one({"membro_id": membro_id})
    if not perfil:
        raise ValueError(f"Perfil não encontrado: {membro_id}")

    metabolico = perfil.get("metabolico", {})
    meta_kcal  = metabolico.get("meta_calorica_kcal", 2000)
    meta_agua  = metabolico.get("meta_agua_ml", 0)
    metas_macros = metabolico.get("metas_macros", {})
    nome_curto = perfil.get("anamnese", {}).get("nome_curto", membro_id)

    # Carrega dados em paralelo
    ref_ontem_fut = asyncio.get_event_loop().run_in_executor(
        None,
        lambda: list(get_registro_refeicoes_col().find(
            {"membro_id": membro_id, "data_refeicao": ontem, "deleted_at": None}
        )),
    )
    hidra_ontem_fut = asyncio.get_event_loop().run_in_executor(
        None,
        lambda: get_registro_hidratacao_col().find_one({"membro_id": membro_id, "data": ontem}),
    )
    estoque_fut = asyncio.get_event_loop().run_in_executor(
        None,
        lambda: analisar_estoque(familia_id),
    )

    refeicoes_ontem, hidra_ontem, estoque = await asyncio.gather(
        ref_ontem_fut, hidra_ontem_fut, estoque_fut
    )

    # Calorias consumidas ontem
    kcal_ontem = sum(
        r.get("macros_totais", {}).get("calorias_kcal", 0)
        for r in refeicoes_ontem
        if not r.get("is_jejum")
    )

    # Hidratação ontem
    hidra_total = hidra_ontem["total_ml"] if hidra_ontem else 0
    hidra_alerta = meta_agua > 0 and hidra_total < meta_agua * 0.80

    # Itens críticos (vencem em ≤ 2 dias)
    criticos = [
        item for item in estoque.values()
        if 0 < item["dias_restantes"] <= 2 and item["quantidade"] > 0 and not item["consumido"]
    ]
    criticos_nomes = [i["nome"] for i in criticos[:3]]

    # Resumo curto para o push notification
    partes_resumo = []
    if criticos_nomes:
        partes_resumo.append(f"{' e '.join(criticos_nomes[:2])} {'vence' if len(criticos_nomes)==1 else 'vencem'} amanhã.")
    if hidra_alerta:
        partes_resumo.append(f"Ontem: {hidra_total:.0f}ml de {meta_agua:.0f}ml de água.")
    partes_resumo.append(f"{meta_kcal:.0f} kcal te esperando hoje.")
    resumo_curto = " ".join(partes_resumo)

    return {
        "membro_id":    membro_id,
        "familia_id":   familia_id,
        "data":         hoje,
        "titulo":       f"Bom dia, {nome_curto}!",
        "resumo_curto": resumo_curto,
        "itens": {
            "meta_calorica_kcal":          meta_kcal,
            "proteina_via_comida_g":       metas_macros.get("proteina_via_comida_g", 0),
            "kcal_consumidas_ontem":       round(kcal_ontem, 1),
            "hidratacao_ontem_ml":         hidra_total,
            "meta_agua_ml":                meta_agua,
            "hidratacao_alerta":           hidra_alerta,
            "estoque_critico":             criticos_nomes,
        },
        "gerado_em": agora.isoformat(),
    }
