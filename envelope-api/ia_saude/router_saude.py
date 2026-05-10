from fastapi import APIRouter, HTTPException, BackgroundTasks, Query
from datetime import datetime, timezone
from bson import ObjectId

from ia_saude.mongo_client_saude import (
    get_perfil_metabolico_col,
    get_registro_refeicoes_col,
    get_registro_hidratacao_col,
    get_registro_peso_col,
    get_fotos_progresso_col,
    get_relatorio_monitoramento_col,
    get_preparo_lote_col,
)
from ia_saude.agente_anamnese import turno_anamnese
from ia_saude.agente_metabolico import calcular_perfil_completo
from ia_saude.agente_nutricional import analisar_refeicao
from ia_saude.agente_planificador import sugerir_jantar as _agente_sugerir_jantar
from ia_saude.agente_progresso_fisico import analisar_foto_progresso
from ia_saude.agente_monitoramento import gerar_relatorio_mensal, calcular_media_movel_peso

router = APIRouter(tags=["ia-saude"])

_501 = HTTPException(status_code=501, detail="Not implemented yet")

CALORIA_MINIMA_SUGESTAO = 1200


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _serialize(doc: dict) -> dict:
    doc["_id"] = str(doc["_id"])
    return doc


def _serialize_list(docs: list) -> list:
    return [_serialize(d) for d in docs]


# ── Anamnese e Perfil Metabólico ─────────────────────────────────────────────

@router.post("/anamnese/chat")
async def anamnese_chat(payload: dict):
    historico = payload.get("historico_mensagens", [])
    if not historico:
        historico = [{"role": "user", "content": "Pode começar a anamnese."}]
    try:
        resultado = await turno_anamnese(historico)
        return resultado
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Erro no agente de anamnese: {exc}")


@router.post("/anamnese/pausar")
async def pausar_monitoramento(payload: dict):
    membro_id = payload.get("membro_id")
    if not membro_id:
        raise HTTPException(status_code=422, detail="membro_id obrigatório")
    pausa = {
        "inicio": payload.get("inicio"),
        "fim": payload.get("fim"),
        "motivo": payload.get("motivo", "outro"),
        "descricao": payload.get("descricao", ""),
    }
    col = get_perfil_metabolico_col()
    col.update_one(
        {"membro_id": membro_id},
        {"$push": {"pausas": pausa}, "$set": {"atualizado_em": _now()}},
    )
    return {"status": "pausa_registrada", "pausa": pausa}


@router.get("/perfil-metabolico/{membro_id}")
async def get_perfil_metabolico(membro_id: str):
    col = get_perfil_metabolico_col()
    doc = col.find_one({"membro_id": membro_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Perfil não encontrado")
    return _serialize(doc)


@router.post("/perfil-metabolico")
async def criar_perfil_metabolico(payload: dict):
    membro_id = payload.get("membro_id")
    familia_id = payload.get("familia_id")
    if not membro_id or not familia_id:
        raise HTTPException(status_code=422, detail="membro_id e familia_id obrigatórios")

    col = get_perfil_metabolico_col()
    if col.find_one({"membro_id": membro_id}):
        raise HTTPException(status_code=409, detail="Perfil já existe — use PATCH para atualizar")

    agora = _now()
    doc = {
        "membro_id":     membro_id,
        "familia_id":    familia_id,
        "anamnese":      payload.get("anamnese", {}),
        "antropometria": payload.get("antropometria", {}),
        "bioquimica":    payload.get("bioquimica", {}),
        "metabolico":    payload.get("metabolico", {}),
        "pausas":        [],
        "criado_em":     agora,
        "atualizado_em": agora,
    }
    doc["metabolico"].update(calcular_perfil_completo(doc))
    result = col.insert_one(doc)
    doc["_id"] = str(result.inserted_id)
    return doc


@router.patch("/perfil-metabolico/{membro_id}")
async def atualizar_perfil_metabolico(membro_id: str, payload: dict):
    col = get_perfil_metabolico_col()
    perfil = col.find_one({"membro_id": membro_id})
    if not perfil:
        raise HTTPException(status_code=404, detail="Perfil não encontrado")

    updates: dict = {"atualizado_em": _now()}
    for secao in ("anamnese", "antropometria", "bioquimica", "metabolico"):
        if secao in payload:
            updates[secao] = {**perfil.get(secao, {}), **payload[secao]}

    perfil_atualizado = {**perfil, **updates}
    perfil_atualizado["metabolico"].update(calcular_perfil_completo(perfil_atualizado))
    updates["metabolico"] = perfil_atualizado["metabolico"]

    col.update_one({"membro_id": membro_id}, {"$set": updates})
    return {"status": "atualizado", "metabolico": updates["metabolico"]}


@router.post("/perfil-metabolico/{membro_id}/calcular")
async def recalcular_metabolico(membro_id: str):
    col = get_perfil_metabolico_col()
    perfil = col.find_one({"membro_id": membro_id})
    if not perfil:
        raise HTTPException(status_code=404, detail="Perfil não encontrado")

    calculado = calcular_perfil_completo(perfil)
    col.update_one(
        {"membro_id": membro_id},
        {"$set": {"metabolico": {**perfil.get("metabolico", {}), **calculado}, "atualizado_em": _now()}},
    )
    return {"status": "recalculado", "metabolico": calculado}


# ── Registro de Refeições ─────────────────────────────────────────────────────

async def _debitar_estoque_background(familia_id: str, itens: list) -> None:
    """BackgroundTask: debita peso_cru_g de cada item no estoque (V2)."""
    try:
        from ia_compras.agente_estoque import debitar_itens
        for item in itens:
            if item.get("tipo") == "gordura_preparo":
                continue  # gordura de preparo não é um ingrediente do estoque
            unidade = item.get("unidade_medida", "g")
            if unidade == "g":
                qtd = item.get("peso_cru_g", 0)
            else:
                qtd = item.get("quantidade", 0)
            if qtd > 0:
                debitar_itens(familia_id, item["nome"], float(qtd))
    except Exception:
        pass  # falha silenciosa — não derruba o registro


def _montar_doc_refeicao(
    payload: dict,
    resultado_ia: dict,
    membro_id: str,
    agora: datetime,
) -> dict:
    data_refeicao = payload.get("offline_timestamp", agora.date().isoformat())
    if hasattr(data_refeicao, "isoformat"):
        data_refeicao = data_refeicao.isoformat()[:10]
    elif isinstance(data_refeicao, datetime):
        data_refeicao = data_refeicao.date().isoformat()

    return {
        "familia_id":           payload.get("familia_id"),
        "membro_id":            membro_id,
        "tipo_refeicao":        payload.get("tipo_refeicao", "outro"),
        "descricao":            resultado_ia.get("descricao", ""),
        "modalidade_entrada":   payload.get("modalidade", "texto"),
        "itens_identificados":  resultado_ia.get("itens_identificados", []),
        "macros_totais":        resultado_ia.get("macros_totais", {}),
        "confianca_ia":         resultado_ia.get("confianca", 0.0),
        "confirmado_usuario":   True,
        "is_cheat_meal":        payload.get("is_cheat_meal", False),
        "is_jejum":             False,
        "replicado_de":         None,
        "imagem_url":           None,
        "data_refeicao":        data_refeicao,
        "registrado_em":        agora,
        "deleted_at":           None,
    }


@router.post("/refeicao/registrar")
async def registrar_refeicao(payload: dict, background_tasks: BackgroundTasks):
    """
    Processa foto/áudio/texto → macros → salva.
    Suporta: fator de cocção (V1), replicar_para (V3), cheat meal (V6),
    offline timestamp (V9), gordura de preparo (V21), etanol (V26).
    Pós-confirmação: debita estoque via BackgroundTask (V2).
    """
    modalidade = payload.get("modalidade", "texto")
    familia_id = payload.get("familia_id")
    membro_id  = payload.get("membro_id")

    if not familia_id or not membro_id:
        raise HTTPException(status_code=422, detail="familia_id e membro_id obrigatórios")

    # ── Chamada ao agente de IA ──────────────────────────────────────────────
    dados_entrada = payload.get("dados_entrada", {})
    resultado = await analisar_refeicao(modalidade, dados_entrada)

    # Retorna estado de clarificação sem salvar
    if resultado.get("status") == "aguardando_clarificacao":
        return resultado

    if resultado.get("status") != "calculado":
        raise HTTPException(status_code=422, detail="Resposta da IA inválida")

    # Modo preview: retorna análise sem salvar (V15 — evita duplo registro)
    if payload.get("apenas_analisar"):
        return resultado

    # ── Salva documento(s) ───────────────────────────────────────────────────
    agora = _now()
    col = get_registro_refeicoes_col()

    doc_principal = _montar_doc_refeicao(payload, resultado, membro_id, agora)
    result = col.insert_one(doc_principal)
    doc_principal["_id"] = str(result.inserted_id)

    # Refeição compartilhada — cria cópia por membro sem chamar IA novamente (V3)
    replicar_para = payload.get("replicar_para", [])
    for outro_membro in replicar_para:
        if outro_membro == membro_id:
            continue
        copia = {**doc_principal}
        copia.pop("_id", None)
        copia["membro_id"] = outro_membro
        copia["replicado_de"] = str(result.inserted_id)
        col.insert_one(copia)

    # BackgroundTask: debita estoque após resposta enviada (V2)
    background_tasks.add_task(
        _debitar_estoque_background,
        familia_id,
        resultado.get("itens_identificados", []),
    )

    return {"id": doc_principal["_id"], "status": "confirmado", "resultado": resultado}


@router.get("/refeicao")
async def listar_refeicoes(
    membro_id: str = Query(...),
    data: str = Query(..., description="yyyy-MM-dd"),
):
    col = get_registro_refeicoes_col()
    docs = list(col.find(
        {"membro_id": membro_id, "data_refeicao": data, "deleted_at": None},
        sort=[("registrado_em", 1)],
    ))
    return _serialize_list(docs)


@router.patch("/refeicao/{refeicao_id}")
async def editar_refeicao(refeicao_id: str, payload: dict):
    col = get_registro_refeicoes_col()
    try:
        oid = ObjectId(refeicao_id)
    except Exception:
        raise HTTPException(status_code=422, detail="refeicao_id inválido")

    doc = col.find_one({"_id": oid, "deleted_at": None})
    if not doc:
        raise HTTPException(status_code=404, detail="Refeição não encontrada")

    campos_editaveis = {
        k: v for k, v in payload.items()
        if k in ("itens_identificados", "macros_totais", "tipo_refeicao",
                  "descricao", "is_cheat_meal", "confianca_ia")
    }
    campos_editaveis["atualizado_em"] = _now()

    col.update_one({"_id": oid}, {"$set": campos_editaveis})
    return {"status": "atualizado", "refeicao_id": refeicao_id}


@router.delete("/refeicao/{refeicao_id}")
async def deletar_refeicao(refeicao_id: str):
    col = get_registro_refeicoes_col()
    try:
        oid = ObjectId(refeicao_id)
    except Exception:
        raise HTTPException(status_code=422, detail="refeicao_id inválido")

    doc = col.find_one({"_id": oid, "deleted_at": None})
    if not doc:
        raise HTTPException(status_code=404, detail="Refeição não encontrada")

    col.update_one({"_id": oid}, {"$set": {"deleted_at": _now()}})
    return {"status": "deletado", "refeicao_id": refeicao_id}


# ── Extrato e Sugestões ───────────────────────────────────────────────────────

def _somar_macros_refeicoes(docs: list) -> dict:
    totais = {
        "calorias_kcal":  0.0,
        "proteina_g":     0.0,
        "carboidrato_g":  0.0,
        "gordura_g":      0.0,
        "fibra_g":        0.0,
        "etanol_kcal":    0.0,
    }
    for doc in docs:
        if doc.get("is_jejum"):
            continue
        macros = doc.get("macros_totais", {})
        totais["calorias_kcal"]  += macros.get("calorias_kcal", 0)
        totais["proteina_g"]     += macros.get("proteina_g", 0)
        totais["carboidrato_g"]  += macros.get("carboidrato_g", 0)
        totais["gordura_g"]      += macros.get("gordura_g", 0)
        totais["fibra_g"]        += macros.get("fibra_g", 0)

        # Etanol separado (V26) — acumula a partir dos itens individuais
        for item in doc.get("itens_identificados", []):
            if item.get("tipo") == "etanol":
                totais["etanol_kcal"] += item.get("calorias_kcal", 0)

    return {k: round(v, 1) for k, v in totais.items()}


@router.get("/extrato")
async def extrato_diario(
    membro_id: str = Query(...),
    data: str = Query(..., description="yyyy-MM-dd"),
):
    """
    Saldo de macros do dia: meta - consumido.
    Etanol separado (V26). Calorias de exercício stub zerado (V10).
    """
    perfil_col = get_perfil_metabolico_col()
    perfil = perfil_col.find_one({"membro_id": membro_id})
    if not perfil:
        raise HTTPException(status_code=404, detail="Perfil metabólico não encontrado")

    refeicoes_col = get_registro_refeicoes_col()
    refeicoes = list(refeicoes_col.find(
        {"membro_id": membro_id, "data_refeicao": data, "deleted_at": None}
    ))

    consumido = _somar_macros_refeicoes(refeicoes)

    metabolico = perfil.get("metabolico", {})
    metas = metabolico.get("metas_macros", {})
    meta_kcal = metabolico.get("meta_calorica_kcal", 2000)

    # Stub de calorias de exercício (V10) — módulo de exercício popula quando existir
    calorias_exercicio = 0

    saldo_kcal = max(
        CALORIA_MINIMA_SUGESTAO,
        meta_kcal + calorias_exercicio - consumido["calorias_kcal"],
    )

    return {
        "data": data,
        "membro_id": membro_id,
        "meta_calorica_kcal": meta_kcal,
        "calorias_exercicio_kcal": calorias_exercicio,
        "consumido": consumido,
        "saldo": {
            "calorias_kcal":  round(saldo_kcal, 1),
            "proteina_g":     round(metas.get("proteina_via_comida_g", 0) - consumido["proteina_g"], 1),
            "carboidrato_g":  round(metas.get("carboidrato_g", 0) - consumido["carboidrato_g"], 1),
            "gordura_g":      round(metas.get("gordura_g", 0) - consumido["gordura_g"], 1),
        },
        "etanol_kcal_dia": consumido["etanol_kcal"],
        "refeicoes_count": len(refeicoes),
    }


@router.get("/sugerir-jantar")
async def sugerir_jantar_endpoint(
    familia_id: str = Query(...),
    membro_ids: str = Query(..., description="UUID(s) separados por vírgula — suporte familiar (V18)"),
    itens_ausentes: str = Query("", description="Nomes separados por vírgula de itens que o usuário confirmou ausentes (V28)"),
):
    """
    Sugestão de jantar: saldo macros + Cesta de Foco (V13) +
    coerência gastronômica (V16) + refeição modular por perfil familiar (V18) +
    micro-inventário preditivo (V28).
    """
    ids = [m.strip() for m in membro_ids.split(",") if m.strip()]
    ausentes = [n.strip() for n in itens_ausentes.split(",") if n.strip()]
    try:
        return await _agente_sugerir_jantar(ids, familia_id, ausentes or None)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/historico")
async def historico(
    membro_id: str = Query(...),
    periodo: str = Query("mensal", description="semanal | mensal"),
):
    """Dados agregados para gráficos de evolução calórica e de peso (fl_chart ready)."""
    from datetime import timedelta

    agora = _now()
    dias = 7 if periodo == "semanal" else 30
    inicio = (agora.date() - timedelta(days=dias - 1)).isoformat()

    ref_col  = get_registro_refeicoes_col()
    peso_col = get_registro_peso_col()

    refeicoes = list(ref_col.find({
        "membro_id":    membro_id,
        "data_refeicao": {"$gte": inicio},
        "deleted_at":   None,
    }))

    kcal_dia:    dict[str, float] = {}
    proteina_dia: dict[str, float] = {}
    for ref in refeicoes:
        if ref.get("is_jejum"):
            continue
        d = ref["data_refeicao"]
        m = ref.get("macros_totais", {})
        kcal_dia[d]     = kcal_dia.get(d, 0)     + m.get("calorias_kcal", 0)
        proteina_dia[d] = proteina_dia.get(d, 0) + m.get("proteina_g", 0)

    pesos = list(peso_col.find(
        {"membro_id": membro_id, "data_medicao": {"$gte": inicio}},
        sort=[("data_medicao", 1)],
    ))

    perfil   = get_perfil_metabolico_col().find_one({"membro_id": membro_id})
    meta_kcal = perfil.get("metabolico", {}).get("meta_calorica_kcal", 0) if perfil else 0

    series_kcal:    list[dict] = []
    series_proteina: list[dict] = []
    for i in range(dias):
        d = (agora.date() - timedelta(days=dias - 1 - i)).isoformat()
        series_kcal.append({"data": d, "valor": round(kcal_dia.get(d, 0), 1)})
        series_proteina.append({"data": d, "valor": round(proteina_dia.get(d, 0), 1)})

    media_movel = calcular_media_movel_peso(pesos)

    return {
        "membro_id":         membro_id,
        "periodo":           periodo,
        "inicio":            inicio,
        "fim":               agora.date().isoformat(),
        "meta_calorica_kcal": meta_kcal,
        "media_movel_peso_kg": media_movel,
        "series": {
            "calorias":  series_kcal,
            "proteina":  series_proteina,
            "peso": [{"data": p["data_medicao"], "valor": p["peso_kg"]} for p in pesos],
        },
    }


@router.get("/digest")
async def morning_digest(
    membro_id: str = Query(...),
    familia_id: str = Query(...),
):
    """Morning Digest consolidado (V25) — chamado pelo app no launch."""
    from ia_saude.agente_digest import gerar_morning_digest
    try:
        return await gerar_morning_digest(membro_id, familia_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


# ── Produto por Código de Barras ──────────────────────────────────────────────

@router.get("/produto/{barcode}")
async def buscar_produto_barcode(
    barcode: str,
    familia_id: str = Query(...),
):
    """
    Busca macros por código de barras.
    Prioridade: SEFAZ local → OpenFoodFacts.
    Auditoria cruzada de peso/shrinkflation (V27).
    """
    import httpx
    from ia_compras.mongo_client import get_dicionario_collection

    col = get_dicionario_collection()

    # 1. Busca no histórico SEFAZ (dicionario_produtos) pelo barcode
    produto_local = col.find_one({"familia_id": familia_id, "barcode": barcode})

    # 2. Fallback: OpenFoodFacts
    of_data: dict | None = None
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                f"https://world.openfoodfacts.org/api/v0/product/{barcode}.json"
            )
            if resp.status_code == 200:
                body = resp.json()
                if body.get("status") == 1:
                    prod = body["product"]
                    n = prod.get("nutriments", {})
                    of_data = {
                        "fonte": "openfoodfacts",
                        "nome": prod.get("product_name", ""),
                        "peso_embalagem_g": _parse_quantity(prod.get("quantity", "")),
                        "macros_por_100g": {
                            "calorias_kcal":  n.get("energy-kcal_100g", 0),
                            "proteina_g":     n.get("proteins_100g", 0),
                            "carboidrato_g":  n.get("carbohydrates_100g", 0),
                            "gordura_g":      n.get("fat_100g", 0),
                            "fibra_g":        n.get("fiber_100g", 0),
                        },
                    }
    except Exception:
        pass

    if not produto_local and not of_data:
        raise HTTPException(status_code=404, detail="Produto não encontrado")

    # 3. Auditoria cruzada de shrinkflation (V27)
    alerta_reducao = None
    if produto_local and of_data:
        peso_sefaz = produto_local.get("quantidade_g")
        peso_api = of_data.get("peso_embalagem_g")
        if peso_sefaz and peso_api and peso_api > 0:
            discrepancia = abs(peso_api - peso_sefaz) / peso_api * 100
            if discrepancia > 5:
                alerta_reducao = {
                    "peso_api_g":   peso_api,
                    "peso_sefaz_g": peso_sefaz,
                    "mensagem":     f"Redução de {peso_api}g para {peso_sefaz}g detectada. Macros recalculados.",
                }

    resultado = of_data or {}
    if produto_local:
        resultado = {
            "fonte": "sefaz_local",
            "nome": produto_local.get("nome_canonico", ""),
            "peso_embalagem_g": produto_local.get("quantidade_g"),
            "macros_por_100g": produto_local.get("macros", {}),
            **(of_data or {}),
        }
        resultado["fonte"] = "sefaz_local"

    if alerta_reducao:
        resultado["alerta_reducao"] = alerta_reducao
        resultado["peso_embalagem_g"] = alerta_reducao["peso_sefaz_g"]

    return resultado


def _parse_quantity(quantity_str: str) -> float | None:
    """Extrai valor numérico de strings como '140g', '1L', '500 ml'."""
    import re
    m = re.search(r"(\d+(?:\.\d+)?)", quantity_str.replace(",", "."))
    if m:
        val = float(m.group(1))
        if "l" in quantity_str.lower() and val < 100:
            val *= 1000  # converte L para ml
        return val
    return None


# ── Hidratação ────────────────────────────────────────────────────────────────

@router.post("/hidratacao")
async def registrar_hidratacao(payload: dict):
    """Registra volume ingerido (copo padrão 250ml ou valor customizado) (V5)."""
    membro_id = payload.get("membro_id")
    familia_id = payload.get("familia_id")
    if not membro_id or not familia_id:
        raise HTTPException(status_code=422, detail="membro_id e familia_id obrigatórios")

    volume_ml = payload.get("volume_ml", 250)
    data = payload.get("data", _now().date().isoformat())
    hora = payload.get("hora", _now().strftime("%H:%M"))

    # Busca meta do perfil
    perfil = get_perfil_metabolico_col().find_one({"membro_id": membro_id})
    meta_ml = 0
    if perfil:
        meta_ml = perfil.get("metabolico", {}).get("meta_agua_ml", 0)

    col = get_registro_hidratacao_col()
    col.update_one(
        {"membro_id": membro_id, "data": data},
        {
            "$push": {"registros": {"hora": hora, "volume_ml": volume_ml}},
            "$inc":  {"total_ml": volume_ml},
            "$setOnInsert": {
                "familia_id": familia_id,
                "meta_ml":    meta_ml,
                "data":       data,
                "membro_id":  membro_id,
            },
            "$set": {"atualizado_em": _now()},
        },
        upsert=True,
    )

    doc = col.find_one({"membro_id": membro_id, "data": data})
    return {
        "status": "registrado",
        "total_ml": doc["total_ml"],
        "meta_ml":  doc["meta_ml"],
        "pct":      round(doc["total_ml"] / doc["meta_ml"] * 100, 1) if doc["meta_ml"] else 0,
    }


@router.get("/hidratacao")
async def get_hidratacao(
    membro_id: str = Query(...),
    data: str = Query(..., description="yyyy-MM-dd"),
):
    """Total de água ingerida no dia vs meta."""
    col = get_registro_hidratacao_col()
    doc = col.find_one({"membro_id": membro_id, "data": data})
    if not doc:
        # Busca meta no perfil para retornar um extrato zerado
        perfil = get_perfil_metabolico_col().find_one({"membro_id": membro_id})
        meta_ml = perfil.get("metabolico", {}).get("meta_agua_ml", 0) if perfil else 0
        return {"membro_id": membro_id, "data": data, "total_ml": 0, "meta_ml": meta_ml, "registros": [], "pct": 0}
    return {
        "membro_id": membro_id,
        "data":      data,
        "total_ml":  doc["total_ml"],
        "meta_ml":   doc["meta_ml"],
        "registros": doc.get("registros", []),
        "pct":       round(doc["total_ml"] / doc["meta_ml"] * 100, 1) if doc.get("meta_ml") else 0,
    }


# ── Análise de Cardápio (Restaurante) — V20 ──────────────────────────────────

@router.post("/analisar-cardapio")
async def analisar_cardapio(payload: dict):
    """OCR do cardápio + ranking por adequação ao perfil (V20)."""
    membro_id  = payload.get("membro_id")
    familia_id = payload.get("familia_id")
    if not membro_id or not familia_id:
        raise HTTPException(status_code=422, detail="membro_id e familia_id obrigatórios")

    imagem_b64 = payload.get("cardapio_base64") or payload.get("imagem_base64")
    mime_type  = payload.get("mime_type", "image/jpeg")
    if not imagem_b64:
        raise HTTPException(status_code=422, detail="cardapio_base64 obrigatório")

    perfil = get_perfil_metabolico_col().find_one({"membro_id": membro_id})
    objetivo = perfil.get("metabolico", {}).get("objetivo", "manutencao") if perfil else "manutencao"

    # Busca saldo do dia para ranquear
    hoje = _now().date().isoformat()
    refeicoes = list(get_registro_refeicoes_col().find(
        {"membro_id": membro_id, "data_refeicao": hoje, "deleted_at": None}
    ))
    kcal_consumidas = sum(
        r.get("macros_totais", {}).get("calorias_kcal", 0)
        for r in refeicoes if not r.get("is_jejum")
    )
    meta_kcal  = perfil.get("metabolico", {}).get("meta_calorica_kcal", 2000) if perfil else 2000
    saldo_kcal = max(0, meta_kcal - kcal_consumidas)

    from ia_saude.agente_nutricional import _chamar_gemini, _parse_json_resposta

    prompt_cardapio = f"""Você é um nutricionista em um restaurante. Analise o cardápio nesta imagem.

CONTEXTO DO USUÁRIO:
- Objetivo: {objetivo}
- Saldo calórico disponível para esta refeição: {saldo_kcal:.0f} kcal

Para cada prato identificado, estime os macros típicos.
Use estimativas conservadoras — restaurante usa mais gordura que cozinha doméstica (+20% gordura).

Classifique cada prato como:
- "adequado": calorias dentro do saldo e bom perfil de macros para o objetivo
- "moderado": calorias um pouco acima ou macros não ideais
- "evitar": estoura o saldo calórico do dia

Retorne APENAS JSON:
{{
  "pratos": [
    {{
      "nome": "Salmão Grelhado com Legumes",
      "preco": 38.00,
      "porcao_estimada_g": 350,
      "calorias_kcal": 520,
      "proteina_g": 48,
      "carboidrato_g": 22,
      "gordura_g": 24,
      "classificacao": "adequado",
      "observacao": "Ótima escolha para seu objetivo!",
      "confianca": 0.75
    }}
  ]
}}"""

    import httpx as _httpx
    import os as _os
    api_key = _os.environ.get("GEMINI_API_KEY", "")
    model   = _os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
    url     = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    body    = {
        "contents": [{"parts": [
            {"inline_data": {"mime_type": mime_type, "data": imagem_b64}},
            {"text": prompt_cardapio},
        ]}],
        "generationConfig": {"temperature": 0.2, "maxOutputTokens": 2048},
    }
    async with _httpx.AsyncClient(timeout=60.0) as client:
        resp = await client.post(url, params={"key": api_key}, json=body)
        resp.raise_for_status()
        texto = resp.json()["candidates"][0]["content"]["parts"][0]["text"]

    resultado = _parse_json_resposta(texto)
    return {"saldo_disponivel_kcal": saldo_kcal, **resultado}


# ── Progresso Físico ──────────────────────────────────────────────────────────

@router.post("/progresso-fisico")
async def registrar_progresso_fisico(payload: dict):
    """Upload de foto corporal + análise qualitativa pela IA."""
    membro_id  = payload.get("membro_id")
    familia_id = payload.get("familia_id")
    if not membro_id or not familia_id:
        raise HTTPException(status_code=422, detail="membro_id e familia_id obrigatórios")

    angulo         = payload.get("angulo", "frente")
    mes_referencia = payload.get("mes_referencia", _now().strftime("%Y-%m"))
    imagem_b64     = payload.get("imagem_base64")
    mime_type      = payload.get("mime_type", "image/jpeg")
    if not imagem_b64:
        raise HTTPException(status_code=422, detail="imagem_base64 obrigatório")

    col = get_fotos_progresso_col()

    # Busca foto anterior do mesmo ângulo para comparação
    foto_anterior = col.find_one(
        {"membro_id": membro_id, "angulo": angulo},
        sort=[("registrado_em", -1)],
    )
    foto_ant_b64  = foto_anterior.get("imagem_base64") if foto_anterior else None
    mime_ant      = foto_anterior.get("mime_type", "image/jpeg") if foto_anterior else None

    analise = await analisar_foto_progresso(imagem_b64, mime_type, foto_ant_b64, mime_ant)

    doc = {
        "membro_id":      membro_id,
        "familia_id":     familia_id,
        "angulo":         angulo,
        "mes_referencia": mes_referencia,
        "imagem_base64":  imagem_b64,
        "mime_type":      mime_type,
        "analise_ia":     analise,
        "registrado_em":  _now(),
    }
    result = col.insert_one(doc)
    return {"id": str(result.inserted_id), "analise_ia": analise}


@router.get("/progresso-fisico/{membro_id}")
async def listar_progresso_fisico(membro_id: str):
    """Lista histórico de fotos de progresso do membro."""
    col  = get_fotos_progresso_col()
    docs = list(col.find(
        {"membro_id": membro_id},
        sort=[("registrado_em", -1)],
        projection={"imagem_base64": 0},  # não retorna base64 na listagem
    ))
    return _serialize_list(docs)


@router.delete("/progresso-fisico/{foto_id}")
async def deletar_foto_progresso(foto_id: str):
    """Remove foto de progresso."""
    col = get_fotos_progresso_col()
    try:
        oid = ObjectId(foto_id)
    except Exception:
        raise HTTPException(status_code=422, detail="foto_id inválido")
    result = col.delete_one({"_id": oid})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Foto não encontrada")
    return {"status": "deletado", "foto_id": foto_id}


# ── Peso ──────────────────────────────────────────────────────────────────────

@router.post("/peso")
async def registrar_peso(payload: dict):
    """Registra pesagem. Média móvel de 7 dias usada para decisões clínicas (V24)."""
    membro_id  = payload.get("membro_id")
    familia_id = payload.get("familia_id")
    if not membro_id or not familia_id:
        raise HTTPException(status_code=422, detail="membro_id e familia_id obrigatórios")

    peso_kg = payload.get("peso_kg")
    if not peso_kg:
        raise HTTPException(status_code=422, detail="peso_kg obrigatório")

    doc = {
        "membro_id":           membro_id,
        "familia_id":          familia_id,
        "peso_kg":             float(peso_kg),
        "percentual_gordura":  payload.get("percentual_gordura"),
        "data_medicao":        payload.get("data_medicao", _now().date().isoformat()),
        "registrado_em":       _now(),
    }
    col = get_registro_peso_col()
    result = col.insert_one(doc)
    return {"id": str(result.inserted_id), "status": "registrado", "peso_kg": doc["peso_kg"]}


@router.get("/peso/{membro_id}")
async def historico_peso(membro_id: str):
    """
    Histórico de peso com média móvel de 7 dias (V24).
    Nunca retorna pesagem isolada para decisões clínicas.
    """
    col  = get_registro_peso_col()
    docs = list(col.find(
        {"membro_id": membro_id},
        sort=[("data_medicao", -1)],
        limit=90,
    ))
    media_movel = calcular_media_movel_peso(docs)
    return {
        "membro_id":       membro_id,
        "registros":       _serialize_list(docs),
        "media_movel_7d":  media_movel,
        "total_registros": len(docs),
    }


# ── Monitoramento Mensal ──────────────────────────────────────────────────────

@router.get("/monitoramento/{membro_id}")
async def relatorio_monitoramento(membro_id: str):
    """Relatório mensal gerado pela IA com adesão, variação de peso e diagnóstico."""
    try:
        doc = await gerar_relatorio_mensal(membro_id)
        return doc
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.patch("/monitoramento/{membro_id}/aprovar-ajuste")
async def aprovar_ajuste_protocolo(membro_id: str, payload: dict):
    """Aplica ajuste de protocolo sugerido pelo agente de monitoramento."""
    relatorio_id = payload.get("relatorio_id")
    if not relatorio_id:
        raise HTTPException(status_code=422, detail="relatorio_id obrigatório")

    col = get_relatorio_monitoramento_col()
    try:
        oid = ObjectId(relatorio_id)
    except Exception:
        raise HTTPException(status_code=422, detail="relatorio_id inválido")

    relatorio = col.find_one({"_id": oid, "membro_id": membro_id})
    if not relatorio:
        raise HTTPException(status_code=404, detail="Relatório não encontrado")

    ajuste = relatorio.get("ajuste_recomendado", {})
    if not ajuste.get("recomendar"):
        raise HTTPException(status_code=422, detail="Nenhum ajuste recomendado neste relatório")

    # Aplica ajuste no perfil metabólico
    perfil_col = get_perfil_metabolico_col()
    updates: dict = {"atualizado_em": _now()}
    if nova_meta := ajuste.get("nova_meta_calorica_kcal"):
        updates["metabolico.meta_calorica_kcal"] = nova_meta
    if nova_prot := ajuste.get("nova_proteina_g"):
        updates["metabolico.metas_macros.proteina_total_g"] = nova_prot

    perfil_col.update_one({"membro_id": membro_id}, {"$set": updates})
    col.update_one({"_id": oid}, {"$set": {"aprovado_usuario": True, "aprovado_em": _now()}})

    return {"status": "ajuste_aplicado", "ajuste": ajuste}


# ── Preparo em Lote (Batch Cooking) — V11/V22 ────────────────────────────────

@router.post("/preparo-lote")
async def criar_preparo_lote(payload: dict, background_tasks: BackgroundTasks):
    """
    Cozinhei para a semana: debita estoque cru imediatamente,
    cria item temporário com TTL culinário (V11/V22).
    """
    familia_id = payload.get("familia_id")
    membro_id  = payload.get("membro_id")
    if not familia_id or not membro_id:
        raise HTTPException(status_code=422, detail="familia_id e membro_id obrigatórios")

    nome           = payload.get("nome")
    porcoes        = payload.get("porcoes_totais", 1)
    ingredientes   = payload.get("ingredientes_usados", [])
    macros_porcao  = payload.get("macros_por_porcao", {})
    if not nome or not ingredientes:
        raise HTTPException(status_code=422, detail="nome e ingredientes_usados obrigatórios")

    # TTL culinário — V22: cocção reseta a validade
    from datetime import timedelta
    _TTL_PADRAO = timedelta(days=4)
    validade = (_now() + _TTL_PADRAO).isoformat()

    doc = {
        "familia_id":          familia_id,
        "membro_id":           membro_id,
        "nome":                nome,
        "porcoes_totais":      porcoes,
        "porcoes_restantes":   porcoes,
        "macros_por_porcao":   macros_porcao,
        "ingredientes_usados": ingredientes,
        "validade_estimada":   validade,
        "criado_em":           _now(),
    }
    col = get_preparo_lote_col()
    result = col.insert_one(doc)

    # Debita estoque dos ingredientes crus imediatamente (V11)
    background_tasks.add_task(
        _debitar_estoque_background,
        familia_id,
        ingredientes,
    )

    return {"id": str(result.inserted_id), "status": "criado", "validade_estimada": validade}


@router.get("/preparo-lote")
async def listar_preparos_lote(familia_id: str = Query(...)):
    """Lista marmitas/preparos ativos com porções restantes."""
    col  = get_preparo_lote_col()
    docs = list(col.find(
        {"familia_id": familia_id, "porcoes_restantes": {"$gt": 0}},
        sort=[("validade_estimada", 1)],
    ))
    return _serialize_list(docs)


# ── Lista de Compras Contextual ───────────────────────────────────────────────

@router.get("/lista-compras-contextual")
async def lista_compras_contextual(
    membro_id: str = Query(...),
    familia_id: str = Query(...),
):
    """
    Sugere lista de compras com contexto financeiro:
    verifica saldo do envelope, sugere remanejamento se necessário (V19).
    ROI proteico por faixa de orçamento (V23).
    """
    from ia_compras.agente_orcamento import (
        consultar_saldo_envelope,
        encontrar_envelopes_com_folga,
        calcular_pressao_orcamentaria,
    )
    from ia_compras.agente_estoque import analisar_estoque
    from datetime import datetime as _dt

    saldo = consultar_saldo_envelope(familia_id)
    dia_do_mes = _dt.now().day
    sob_pressao = calcular_pressao_orcamentaria(saldo, dia_do_mes)

    estoque = analisar_estoque(familia_id)
    itens_criticos = [
        {"nome": v["nome"], "categoria": v["categoria"], "quantidade": v["quantidade"]}
        for v in estoque.values()
        if v.get("consumido") or v.get("quantidade", 0) <= 0
    ][:10]

    sugestao_remanejamento = None
    if saldo < 50 and itens_criticos:
        valor_sugerido = round(min(80.0, max(30.0, len(itens_criticos) * 8.0)), 2)
        envelopes_folga = encontrar_envelopes_com_folga(familia_id, valor_sugerido)
        if envelopes_folga:
            melhor = envelopes_folga[0]
            sugestao_remanejamento = {
                "envelope_origem":  melhor["nome_envelope"],
                "envelope_id":      melhor["envelope_id"],
                "valor_sugerido":   valor_sugerido,
                "justificativa":    f"Repor itens essenciais zerados no estoque ({len(itens_criticos)} itens)",
            }

    return {
        "membro_id":             membro_id,
        "familia_id":            familia_id,
        "saldo_supermercado":    round(saldo, 2),
        "dia_do_mes":            dia_do_mes,
        "sob_pressao_financeira": sob_pressao,
        "itens_necessarios":     itens_criticos,
        "sugestao_remanejamento": sugestao_remanejamento,
        "observacao":            "Proteínas premium bloqueadas" if sob_pressao else "Orçamento confortável",
    }


# ── Biofeedback / IoT (stub reservado — V29) ─────────────────────────────────

@router.post("/biofeedback/telemetria")
async def receber_telemetria(payload: dict):
    return {"status": "recebido", "processado": False, "msg": "IoT endpoint reservado — integração pendente"}
