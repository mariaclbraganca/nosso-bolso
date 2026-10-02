from fastapi import APIRouter, Depends, HTTPException, Query
from datetime import datetime, timezone
from bson import ObjectId
from bson.errors import InvalidId

from auth import AuthUser, get_current_user, assert_mesma_familia

from ia_financeiro.mongo_client_financeiro import get_contas_pagar_col

router_contas = APIRouter(tags=["ia-financeiro"])


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _serialize(doc: dict) -> dict:
    doc["_id"] = str(doc["_id"])
    return doc


def _oid(doc_id: str) -> ObjectId:
    try:
        return ObjectId(doc_id)
    except (InvalidId, TypeError):
        raise HTTPException(status_code=404, detail="Conta não encontrada")


CATEGORIAS_CONTA = [
    "aluguel", "energia", "agua", "internet", "telefone",
    "cartao_credito", "saude", "educacao", "transporte",
    "seguro", "streaming", "academia", "outro",
]


@router_contas.get("/contas-pagar")
def listar_contas(
    familia_id: str = Query(None),
    mes: str = Query(None),         # YYYY-MM — filtra por mês de vencimento
    incluir_pagas: bool = Query(True),
    user: AuthUser = Depends(get_current_user),
):
    familia_id = assert_mesma_familia(user, familia_id)
    col = get_contas_pagar_col()
    filtro: dict = {"familia_id": familia_id}
    if mes:
        filtro["vencimento"] = {"$regex": f"^{mes}"}
    if not incluir_pagas:
        filtro["pago"] = False

    docs = list(col.find(filtro, sort=[("vencimento", 1)]))
    return {"contas": [_serialize(d) for d in docs]}


@router_contas.post("/contas-pagar")
def criar_conta(payload: dict, user: AuthUser = Depends(get_current_user)):
    familia_id = assert_mesma_familia(user, payload.get("familia_id"))
    nome       = payload.get("nome")
    valor      = payload.get("valor")
    vencimento = payload.get("vencimento")   # YYYY-MM-DD

    if not all([familia_id, nome, valor, vencimento]):
        raise HTTPException(status_code=422, detail="familia_id, nome, valor e vencimento são obrigatórios")

    doc = {
        "familia_id":  familia_id,
        "nome":        nome,
        "valor":       float(valor),
        "vencimento":  vencimento,
        "categoria":   payload.get("categoria", "outro"),
        "recorrente":  bool(payload.get("recorrente", False)),
        "pago":        False,
        "pago_em":     None,
        "observacao":  payload.get("observacao", ""),
        "criado_em":   _now(),
        "atualizado_em": _now(),
    }

    col = get_contas_pagar_col()
    result = col.insert_one(doc)
    doc["_id"] = str(result.inserted_id)
    return doc


@router_contas.patch("/contas-pagar/{conta_id}/pagar")
def marcar_paga(conta_id: str, payload: dict = None, user: AuthUser = Depends(get_current_user)):
    if payload is None:
        payload = {}
    col  = get_contas_pagar_col()
    pago = payload.get("pago", True)
    filtro = {"_id": _oid(conta_id), "familia_id": user.familia_id}
    result = col.update_one(
        filtro,
        {"$set": {
            "pago":     pago,
            "pago_em":  _now() if pago else None,
            "atualizado_em": _now(),
        }},
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Conta não encontrada")
    return _serialize(col.find_one(filtro))


@router_contas.delete("/contas-pagar/{conta_id}")
def deletar_conta(conta_id: str, user: AuthUser = Depends(get_current_user)):
    col = get_contas_pagar_col()
    result = col.delete_one({"_id": _oid(conta_id), "familia_id": user.familia_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Conta não encontrada")
    return {"ok": True}


@router_contas.get("/contas-pagar/resumo")
def resumo_contas(
    familia_id: str = Query(None),
    mes: str = Query(...),
    user: AuthUser = Depends(get_current_user),
):
    familia_id = assert_mesma_familia(user, familia_id)
    col   = get_contas_pagar_col()
    docs  = list(col.find({"familia_id": familia_id, "vencimento": {"$regex": f"^{mes}"}}))
    total = sum(d.get("valor", 0) for d in docs)
    pagas = sum(d.get("valor", 0) for d in docs if d.get("pago"))
    pendentes = total - pagas
    vencidas  = sum(
        d.get("valor", 0) for d in docs
        if not d.get("pago") and d.get("vencimento", "") < datetime.now().strftime("%Y-%m-%d")
    )
    return {
        "total": round(total, 2),
        "pagas": round(pagas, 2),
        "pendentes": round(pendentes, 2),
        "vencidas": round(vencidas, 2),
        "count_total": len(docs),
        "count_pagas": sum(1 for d in docs if d.get("pago")),
    }
