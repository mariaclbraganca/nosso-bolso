from fastapi import APIRouter, Depends, HTTPException
from database import get_supabase
from models import AbastecerEnvelope
from auth import AuthUser, get_current_user, assert_mesma_familia, assert_mesmo_usuario

router = APIRouter()

_TOLERANCIA_CENTAVO = 0.01

@router.post("/")
def abastecer_envelope(
    payload: AbastecerEnvelope,
    user: AuthUser = Depends(get_current_user),
):
    fam = assert_mesma_familia(user, payload.familia_id)
    usr = assert_mesmo_usuario(user, payload.usuario_id)
    db = get_supabase()

    # Validação pessimista de saldo: saldo_geral é decrementado pelo trigger.
    # Garante que requisições paralelas não levem o saldo a negativo.
    saldo_row = db.table("saldo_geral").select("valor_total_disponivel") \
        .eq("familia_id", fam).single().execute()
    if not saldo_row.data:
        raise HTTPException(status_code=404, detail="Saldo da família não encontrado")

    saldo_disponivel = float(saldo_row.data["valor_total_disponivel"])
    if payload.valor > saldo_disponivel + _TOLERANCIA_CENTAVO:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Saldo insuficiente para abastecer este envelope. "
                f"Disponível: R$ {saldo_disponivel:.2f} | Solicitado: R$ {payload.valor:.2f}."
            ),
        )

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
