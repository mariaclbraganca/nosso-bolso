from fastapi import APIRouter, HTTPException, Query
from datetime import datetime, timezone
from bson import ObjectId

from ia_saude.mongo_client_saude import get_registro_exercicio_col, get_perfil_metabolico_col
from ia_saude.agente_treino import CATALOGO_EXERCICIOS, calcular_calorias

router_exercicio = APIRouter(tags=["ia-exercicio"])


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _serialize(doc: dict) -> dict:
    doc["_id"] = str(doc["_id"])
    for ex in doc.get("exercicios", []):
        if isinstance(ex.get("registrado_em"), datetime):
            ex["registrado_em"] = ex["registrado_em"].isoformat()
    return doc


# ── Catálogo ──────────────────────────────────────────────────────────────────

@router_exercicio.get("/exercicio/catalogo")
def get_catalogo():
    return {"catalogo": CATALOGO_EXERCICIOS}


# ── Registro do dia ───────────────────────────────────────────────────────────

@router_exercicio.get("/exercicio/dia")
def get_exercicio_dia(
    membro_id: str = Query(...),
    data: str = Query(...),
):
    col = get_registro_exercicio_col()
    doc = col.find_one({"membro_id": membro_id, "data": data})
    if not doc:
        return {
            "membro_id": membro_id,
            "data": data,
            "exercicios": [],
            "total_calorias_kcal": 0,
            "total_duracao_min": 0,
        }
    return _serialize(doc)


# ── Registrar exercício ────────────────────────────────────────────────────────

@router_exercicio.post("/exercicio/registrar")
def registrar_exercicio(payload: dict):
    membro_id  = payload.get("membro_id")
    familia_id = payload.get("familia_id")
    data       = payload.get("data")
    nome       = payload.get("nome")
    categoria  = payload.get("categoria", "outros")
    met        = float(payload.get("met", 4.0))
    duracao_min = int(payload.get("duracao_min", 30))
    notas      = payload.get("notas", "")

    if not all([membro_id, familia_id, data, nome]):
        raise HTTPException(
            status_code=422,
            detail="membro_id, familia_id, data e nome são obrigatórios",
        )

    perfil_col = get_perfil_metabolico_col()
    perfil = perfil_col.find_one({"membro_id": membro_id}) or {}
    peso_kg = float(perfil.get("antropometria", {}).get("peso_kg", 70))

    calorias = calcular_calorias(met, peso_kg, duracao_min)

    exercicio_item = {
        "id": str(ObjectId()),
        "nome": nome,
        "categoria": categoria,
        "met": met,
        "duracao_min": duracao_min,
        "calorias_kcal": calorias,
        "notas": notas,
        "registrado_em": _now(),
    }

    col = get_registro_exercicio_col()
    result = col.find_one_and_update(
        {"membro_id": membro_id, "data": data},
        {
            "$push": {"exercicios": exercicio_item},
            "$inc": {
                "total_calorias_kcal": calorias,
                "total_duracao_min": duracao_min,
            },
            "$setOnInsert": {
                "membro_id": membro_id,
                "familia_id": familia_id,
                "data": data,
                "criado_em": _now(),
            },
            "$set": {"atualizado_em": _now()},
        },
        upsert=True,
        return_document=True,
    )

    return _serialize(result)


# ── Deletar exercício ─────────────────────────────────────────────────────────

@router_exercicio.delete("/exercicio/{exercicio_item_id}")
def deletar_exercicio(
    exercicio_item_id: str,
    membro_id: str = Query(...),
    data: str = Query(...),
):
    col = get_registro_exercicio_col()
    doc = col.find_one({"membro_id": membro_id, "data": data})
    if not doc:
        raise HTTPException(status_code=404, detail="Registro não encontrado")

    item = next(
        (e for e in doc.get("exercicios", []) if e["id"] == exercicio_item_id),
        None,
    )
    if not item:
        raise HTTPException(status_code=404, detail="Exercício não encontrado")

    calorias   = item.get("calorias_kcal", 0)
    duracao    = item.get("duracao_min", 0)

    col.update_one(
        {"membro_id": membro_id, "data": data},
        {
            "$pull": {"exercicios": {"id": exercicio_item_id}},
            "$inc": {
                "total_calorias_kcal": -calorias,
                "total_duracao_min": -duracao,
            },
            "$set": {"atualizado_em": _now()},
        },
    )
    return {"ok": True}


# ── Histórico ─────────────────────────────────────────────────────────────────

@router_exercicio.get("/exercicio/historico")
def get_historico_exercicio(
    membro_id: str = Query(...),
    dias: int = Query(30),
):
    col = get_registro_exercicio_col()
    docs = list(
        col.find({"membro_id": membro_id}, sort=[("data", -1)], limit=max(1, dias))
    )
    return {"historico": [_serialize(d) for d in docs]}
