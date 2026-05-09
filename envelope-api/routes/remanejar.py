from fastapi import APIRouter, Depends, HTTPException
from database import get_supabase
from models import RemanejarPayload
from auth import AuthUser, get_current_user, assert_mesma_familia, assert_mesmo_usuario

router = APIRouter()


@router.post("/")
def remanejar_saldo(
    payload: RemanejarPayload,
    user: AuthUser = Depends(get_current_user),
):
    """Transfere saldo entre envelopes via RPC atômica.

    O par despesa+abastecimento direto na tabela transacoes não funciona
    porque o trigger de abastecimento debita saldo_geral — em remanejamento
    o caixa não-alocado não deve mudar. A RPC `remanejar_envelopes` faz
    UPDATE direto nos dois envelopes (sem passar por trigger) e registra
    a operação em remanejamentos_log para auditoria.
    """
    fam = assert_mesma_familia(user, payload.familia_id)
    usr = assert_mesmo_usuario(user, payload.usuario_id)
    db = get_supabase()
    try:
        db.rpc(
            "remanejar_envelopes",
            {
                "p_origem_id": str(payload.origem_id),
                "p_destino_id": str(payload.destino_id),
                "p_valor": float(payload.valor),
                "p_familia_id": fam,
                "p_usuario_id": usr,
            },
        ).execute()
        return {"status": "success", "message": "Saldo remanejado com sucesso"}
    except Exception as e:
        # Erros do Supabase vêm como dict-string tipo "{'message': '...', ...}".
        # Extrai só o message para o front.
        raw = str(e)
        try:
            import ast
            parsed = ast.literal_eval(raw)
            msg = parsed.get("message", raw) if isinstance(parsed, dict) else raw
        except (ValueError, SyntaxError):
            msg = raw
        # Erros de validação dentro da RPC viram 4xx, resto 500
        if any(s in msg for s in (
            "Saldo insuficiente",
            "Envelope de origem não encontrado",
            "Envelope de destino não encontrado",
            "Valor inválido",
            "devem ser diferentes",
        )):
            raise HTTPException(status_code=400, detail=msg)
        raise HTTPException(status_code=500, detail=msg)
