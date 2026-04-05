from fastapi import APIRouter, HTTPException
from database import get_supabase
from models import RemanejarPayload

router = APIRouter()

@router.post("/")
def remanejar_saldo(payload: RemanejarPayload):
    """Transfere saldo entre envelopes via par despesa+abastecimento"""
    db = get_supabase()

    # Verificar saldo do envelope de origem
    origem = db.table("envelopes").select("saldo_atual") \
        .eq("id", str(payload.origem_id)) \
        .eq("familia_id", str(payload.familia_id)).single().execute()

    if not origem.data:
        raise HTTPException(status_code=404, detail="Envelope de origem não encontrado")

    if origem.data["saldo_atual"] < payload.valor:
        raise HTTPException(status_code=400, detail="Saldo insuficiente no envelope de origem")

    try:
        # 1. Despesa no envelope de origem (trigger deduz saldo_atual)
        db.table("transacoes").insert({
            "envelope_id": str(payload.origem_id),
            "valor": payload.valor,
            "tipo": "despesa",
            "descricao": "Remanejado para outro envelope",
            "usuario_id": str(payload.usuario_id),
            "familia_id": str(payload.familia_id),
        }).execute()

        # 2. Abastecimento no envelope de destino (trigger adiciona saldo_atual)
        db.table("transacoes").insert({
            "envelope_id": str(payload.destino_id),
            "valor": payload.valor,
            "tipo": "abastecimento",
            "descricao": "Remanejado de outro envelope",
            "usuario_id": str(payload.usuario_id),
            "familia_id": str(payload.familia_id),
        }).execute()

        return {"status": "success", "message": "Saldo remanejado com sucesso"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
