from fastapi import APIRouter, HTTPException, Query
from datetime import datetime, timezone
from bson import ObjectId

from ia_financeiro.mongo_client_financeiro import get_metas_economia_col

router_metas = APIRouter(tags=["ia-financeiro"])


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _serialize(doc: dict) -> dict:
    doc["_id"] = str(doc["_id"])
    return doc


@router_metas.get("/metas-economia")
def listar_metas(familia_id: str = Query(...)):
    col  = get_metas_economia_col()
    docs = list(col.find({"familia_id": familia_id}, sort=[("criado_em", -1)]))
    return {"metas": [_serialize(d) for d in docs]}


@router_metas.post("/metas-economia")
def criar_meta(payload: dict):
    familia_id  = payload.get("familia_id")
    nome        = payload.get("nome")
    valor_meta  = payload.get("valor_meta")

    if not all([familia_id, nome, valor_meta]):
        raise HTTPException(status_code=422, detail="familia_id, nome e valor_meta são obrigatórios")

    doc = {
        "familia_id":   familia_id,
        "nome":         nome,
        "emoji":        payload.get("emoji", "🎯"),
        "valor_meta":   float(valor_meta),
        "valor_atual":  float(payload.get("valor_atual", 0)),
        "prazo":        payload.get("prazo"),          # YYYY-MM-DD opcional
        "cor":          payload.get("cor", "#60A5FA"), # hex
        "concluida":    False,
        "criado_em":    _now(),
        "atualizado_em": _now(),
        "historico_contribuicoes": [],
    }

    col = get_metas_economia_col()
    result = col.insert_one(doc)
    doc["_id"] = str(result.inserted_id)
    return doc


@router_metas.patch("/metas-economia/{meta_id}/contribuir")
def contribuir_meta(meta_id: str, payload: dict):
    valor = float(payload.get("valor", 0))
    if valor <= 0:
        raise HTTPException(status_code=422, detail="valor deve ser positivo")

    col = get_metas_economia_col()
    doc = col.find_one({"_id": ObjectId(meta_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Meta não encontrada")

    novo_valor = doc.get("valor_atual", 0) + valor
    concluida  = novo_valor >= doc.get("valor_meta", 1)

    contribuicao = {
        "valor":     valor,
        "data":      datetime.now().strftime("%Y-%m-%d"),
        "descricao": payload.get("descricao", ""),
    }

    col.update_one(
        {"_id": ObjectId(meta_id)},
        {
            "$set": {
                "valor_atual":    round(novo_valor, 2),
                "concluida":      concluida,
                "atualizado_em":  _now(),
            },
            "$push": {"historico_contribuicoes": contribuicao},
        },
    )
    doc = col.find_one({"_id": ObjectId(meta_id)})
    return _serialize(doc)


@router_metas.delete("/metas-economia/{meta_id}")
def deletar_meta(meta_id: str):
    col = get_metas_economia_col()
    result = col.delete_one({"_id": ObjectId(meta_id)})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Meta não encontrada")
    return {"ok": True}
