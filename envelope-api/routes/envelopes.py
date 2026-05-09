from fastapi import APIRouter, Depends, HTTPException
from database import get_supabase
from models import EnvelopeCreate, EnvelopeUpdate
from auth import AuthUser, get_current_user, assert_mesma_familia
from datetime import datetime

router = APIRouter()

@router.get("/")
def listar_envelopes(
    user: AuthUser = Depends(get_current_user),
    familia_id: str = None,
):
    familia_id = assert_mesma_familia(user, familia_id)
    db = get_supabase()
    return db.table("envelopes").select("*") \
        .eq("familia_id", familia_id) \
        .is_("deleted_at", "null") \
        .order("nome_envelope").execute().data

@router.post("/")
def criar_envelope(
    payload: EnvelopeCreate,
    user: AuthUser = Depends(get_current_user),
):
    """Cria envelope forçando saldo_atual em 0"""
    fam = assert_mesma_familia(user, payload.familia_id)
    db = get_supabase()
    data = {
        "nome_envelope": payload.nome_envelope,
        "valor_planejado": payload.valor_planejado,
        "emoji": payload.emoji,
        "cor": payload.cor,
        "familia_id": fam,
        "is_reserva": payload.is_reserva,
        "valor_objetivo": payload.valor_objetivo,
        "saldo_atual": 0  # Regra de Ouro: Sempre inicia em 0
    }
    result = db.table("envelopes").insert(data).execute()
    return result.data[0]

@router.put("/{envelope_id}")
def editar_envelope(
    envelope_id: str,
    payload: EnvelopeUpdate,
    user: AuthUser = Depends(get_current_user),
    familia_id: str = None,
):
    familia_id = assert_mesma_familia(user, familia_id)
    db = get_supabase()
    update_data = {k: v for k, v in payload.model_dump().items() if v is not None}
    if not update_data:
        raise HTTPException(status_code=400, detail="Nenhum campo para atualizar")

    result = db.table("envelopes").update(update_data) \
        .eq("id", envelope_id) \
        .eq("familia_id", familia_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Envelope não encontrado ou acesso negado")
    return result.data[0]

@router.delete("/{envelope_id}")
def excluir_envelope(
    envelope_id: str,
    user: AuthUser = Depends(get_current_user),
    familia_id: str = None,
):
    familia_id = assert_mesma_familia(user, familia_id)
    db = get_supabase()
    # Soft delete (SPEC-11)
    result = db.table("envelopes").update({"deleted_at": datetime.now().isoformat()}) \
        .eq("id", envelope_id) \
        .eq("familia_id", familia_id).execute()

    if not result.data:
        raise HTTPException(status_code=404, detail="Envelope não encontrado")
    return {"status": "success", "message": "Envelope arquivado com sucesso"}
