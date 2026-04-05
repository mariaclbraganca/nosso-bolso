from fastapi import APIRouter
from database import get_supabase
from models import AbastecerEnvelope

router = APIRouter()

@router.post("/")
def abastecer_envelope(payload: AbastecerEnvelope):
    db = get_supabase()
    data = {
        "valor": payload.valor,
        "tipo": "abastecimento",
        "usuario_id": str(payload.usuario_id),
        "envelope_id": str(payload.envelope_id),
        "descricao": "Abastecimento de envelope",
        "familia_id": str(payload.familia_id),
    }
    result = db.table("transacoes").insert(data).execute()
    return result.data[0]
