"""
Rota de PARCELAS — compras parceladas com contagem regressiva.

Conceito central (resolve o cansaço de recriar parcela todo mês):
- O usuário registra a compra parcelada UMA vez.
- O sistema gera N transações de despesa, uma por mês, já datadas.
- Cada parcela aparece no mês certo e o trigger de saldo cuida do resto.
- A parcela "some" sozinha quando a última é paga (ativa=false).
- Rastreável: "faltam 3 de 6".

Isso substitui a gambiarra de lançar parcela como gasto fixo recorrente.
"""
from fastapi import APIRouter, Depends, HTTPException
from database import get_supabase
from models import ParcelaCreate
from auth import AuthUser, get_current_user, assert_mesma_familia, assert_mesmo_usuario
from datetime import date
from dateutil.relativedelta import relativedelta

router = APIRouter()


def _add_months(d: date, months: int) -> date:
    """Soma meses a uma data preservando o dia quando possível."""
    return d + relativedelta(months=months)


@router.post("/")
def criar_parcela(
    payload: ParcelaCreate,
    user: AuthUser = Depends(get_current_user),
):
    """
    Cria uma compra parcelada e gera as N transações automaticamente.
    Cada transação é uma despesa normal, no mês correto, vinculada à parcela.
    """
    fam = assert_mesma_familia(user, payload.familia_id)
    usr = assert_mesmo_usuario(user, payload.usuario_id)
    db = get_supabase()

    # valor da parcela = total / num (arredondado); última parcela ajusta a diferença
    valor_parcela = round(payload.valor_total / payload.num_parcelas, 2)

    # 1. Criar a parcela-mãe (o "contrato")
    parcela_data = {
        "familia_id": fam,
        "usuario_id": usr,
        "envelope_id": str(payload.envelope_id) if payload.envelope_id else None,
        "descricao": payload.descricao,
        "cartao": payload.cartao,
        "valor_total": payload.valor_total,
        "num_parcelas": payload.num_parcelas,
        "valor_parcela": valor_parcela,
        "data_primeira": str(payload.data_primeira),
        "parcelas_pagas": 0,
        "ativa": True,
    }
    parcela = db.table("parcelas").insert(parcela_data).execute().data[0]
    parcela_id = parcela["id"]

    # 2. Gerar as N transações (uma por mês)
    transacoes = []
    soma_acumulada = 0.0
    for n in range(1, payload.num_parcelas + 1):
        data_parcela = _add_months(payload.data_primeira, n - 1)
        # Última parcela: ajusta centavos para fechar exatamente o total
        if n == payload.num_parcelas:
            valor_n = round(payload.valor_total - soma_acumulada, 2)
        else:
            valor_n = valor_parcela
            soma_acumulada += valor_parcela

        transacoes.append({
            "familia_id": fam,
            "usuario_id": usr,
            "envelope_id": str(payload.envelope_id) if payload.envelope_id else None,
            "tipo": "despesa",
            "valor": valor_n,
            "data": str(data_parcela),
            "descricao": f"{payload.descricao} ({n}/{payload.num_parcelas})",
            "parcela_id": parcela_id,
            "parcela_num": n,
        })

    db.table("transacoes").insert(transacoes).execute()

    return {
        "parcela": parcela,
        "transacoes_geradas": len(transacoes),
        "valor_parcela": valor_parcela,
        "primeira": str(payload.data_primeira),
        "ultima": str(_add_months(payload.data_primeira, payload.num_parcelas - 1)),
    }


@router.get("/")
def listar_parcelas(
    user: AuthUser = Depends(get_current_user),
    familia_id: str = None,
    apenas_ativas: bool = True,
):
    """Lista as parcelas da família, com o quanto já foi pago (contagem regressiva)."""
    familia_id = assert_mesma_familia(user, familia_id)
    db = get_supabase()

    query = (db.table("parcelas").select("*")
             .eq("familia_id", familia_id)
             .is_("deleted_at", "null")
             .order("created_at", desc=True))
    if apenas_ativas:
        query = query.eq("ativa", True)

    parcelas = query.execute().data

    # Para cada parcela, contar quantas transações já passaram (data <= hoje)
    hoje = date.today().isoformat()
    for p in parcelas:
        pagas = (db.table("transacoes")
                 .select("id", count="exact")
                 .eq("parcela_id", p["id"])
                 .is_("deleted_at", "null")
                 .lte("data", hoje)
                 .execute())
        p["parcelas_pagas"] = pagas.count or 0
        p["parcelas_restantes"] = p["num_parcelas"] - (pagas.count or 0)

    return parcelas


@router.delete("/{parcela_id}")
def cancelar_parcela(
    parcela_id: str,
    user: AuthUser = Depends(get_current_user),
    familia_id: str = None,
    apenas_futuras: bool = True,
):
    """
    Cancela uma parcela. Por padrão (apenas_futuras=True), remove só as parcelas
    que ainda não venceram — as já pagas continuam no histórico.
    O trigger estorna o saldo das transações soft-deletadas automaticamente.
    """
    familia_id = assert_mesma_familia(user, familia_id)
    db = get_supabase()
    from datetime import datetime

    # Verificar posse
    parcela = (db.table("parcelas").select("*")
               .eq("id", parcela_id).eq("familia_id", familia_id).execute().data)
    if not parcela:
        raise HTTPException(status_code=404, detail="Parcela não encontrada")

    # Soft-delete das transações (futuras ou todas)
    hoje = date.today().isoformat()
    tx_query = (db.table("transacoes")
                .update({"deleted_at": datetime.now().isoformat()})
                .eq("parcela_id", parcela_id)
                .eq("familia_id", familia_id)
                .is_("deleted_at", "null"))
    if apenas_futuras:
        tx_query = tx_query.gt("data", hoje)
    tx_query.execute()

    # Marcar a parcela como inativa e soft-deletada
    db.table("parcelas").update({
        "ativa": False,
        "deleted_at": datetime.now().isoformat(),
    }).eq("id", parcela_id).eq("familia_id", familia_id).execute()

    return {"status": "success", "message": "Parcela cancelada"}
