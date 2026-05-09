from fastapi import APIRouter, Depends
from database import get_supabase
from models import AbastecerEnvelope
from auth import AuthUser, get_current_user, assert_mesma_familia, assert_mesmo_usuario

router = APIRouter()

@router.post("/")
def abastecer_envelope(
    payload: AbastecerEnvelope,
    user: AuthUser = Depends(get_current_user),
):
    fam = assert_mesma_familia(user, payload.familia_id)
    usr = assert_mesmo_usuario(user, payload.usuario_id)
    db = get_supabase()
    data = {
        "valor": payload.valor,
        "tipo": "abastecimento",
        "usuario_id": usr,
        "envelope_id": str(payload.envelope_id),
        "descricao": "Abastecimento de envelope",
        "familia_id": fam,
    }
    result = db.table("transacoes").insert(data).execute()
    return result.data[0]
