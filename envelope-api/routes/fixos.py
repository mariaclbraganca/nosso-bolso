"""
Rota de GASTOS FIXOS — versão corrigida (fim da dupla contabilidade).

MUDANÇA ESTRUTURAL:
Antes, marcar um fixo como pago mexia no saldo_geral via Python puro, enquanto
transacoes mexe via trigger. Duas fontes de verdade = saldo que não bate.

Agora, pagar um fixo GERA uma transação do tipo 'despesa_fixa', e o trigger
cuida do saldo. Desmarcar = soft-delete dessa transação (trigger estorna).
Uma única fonte de verdade: o trigger.

Depende de: migration 02 (tipo despesa_fixa + coluna transacoes.fixo_id).
"""
from fastapi import APIRouter, Depends, HTTPException
from database import get_supabase
from models import GastoFixoCreate, GastoFixoUpdate
from auth import AuthUser, get_current_user, assert_mesma_familia
from datetime import datetime
from pydantic import BaseModel, Field

router = APIRouter()


@router.get("/")
def listar_fixos(
    user: AuthUser = Depends(get_current_user),
    familia_id: str = None, mes: str = None,
):
    familia_id = assert_mesma_familia(user, familia_id)
    db = get_supabase()

    query = db.table("gastos_fixos").select("*").eq("familia_id", familia_id).order("dia_vencimento")
    if mes:
        query = query.eq("mes", mes)
    fixos_atuais = query.execute().data

    # Recorrência (SPEC-04): replica fixos recorrentes do mês anterior
    if mes:
        from datetime import datetime as dt, timedelta
        d = dt.strptime(mes + "-01", "%Y-%m-%d")
        prev = (d - timedelta(days=1)).strftime("%Y-%m")

        fixos_prev = (db.table("gastos_fixos").select("*")
                      .eq("familia_id", familia_id).eq("mes", prev)
                      .eq("recorrente", True).execute().data)

        if fixos_prev:
            nomes_atuais = {f["nome"] for f in fixos_atuais}
            novos = [{
                "nome": fp["nome"], "valor": fp["valor"], "mes": mes,
                "familia_id": familia_id, "recorrente": True, "pago": False,
                "dia_vencimento": fp.get("dia_vencimento"),
            } for fp in fixos_prev if fp["nome"] not in nomes_atuais]

            if novos:
                db.table("gastos_fixos").insert(novos).execute()
                fixos_atuais = (db.table("gastos_fixos").select("*")
                                .eq("familia_id", familia_id).eq("mes", mes)
                                .order("dia_vencimento").execute().data)

    return fixos_atuais


@router.post("/")
def criar_fixo(
    payload: GastoFixoCreate,
    user: AuthUser = Depends(get_current_user),
):
    fam = assert_mesma_familia(user, payload.familia_id)
    db = get_supabase()
    data = payload.model_dump()
    data["familia_id"] = fam
    return db.table("gastos_fixos").insert(data).execute().data[0]


def _data_pagamento(fixo: dict) -> str:
    """Data da transação de pagamento: dia_vencimento do mês do fixo, ou dia 1."""
    mes = fixo["mes"]  # 'YYYY-MM'
    dia = fixo.get("dia_vencimento") or 1
    dia = min(max(int(dia), 1), 28)  # clamp seguro p/ evitar mês curto
    return f"{mes}-{dia:02d}"


@router.patch("/{fixo_id}")
def atualizar_fixo(
    fixo_id: str,
    payload: GastoFixoUpdate,
    user: AuthUser = Depends(get_current_user),
):
    """
    Atualiza um fixo. Se o status 'pago' mudar, gera/estorna uma transação
    'despesa_fixa' — o trigger cuida do saldo. Sem mexer no saldo_geral aqui.
    """
    db = get_supabase()

    fixo_res = (db.table("gastos_fixos").select("*")
                .eq("id", fixo_id).eq("familia_id", user.familia_id).execute().data)
    if not fixo_res:
        raise HTTPException(status_code=404, detail="Fixo não encontrado")

    fixo = fixo_res[0]
    update_data = {k: v for k, v in payload.model_dump().items() if v is not None}
    if not update_data:
        raise HTTPException(status_code=400, detail="Nenhum campo para atualizar")

    fixo_ja_pago = fixo.get("pago", False)
    mudou_status = "pago" in update_data and update_data["pago"] != fixo_ja_pago

    if mudou_status:
        familia_id = fixo["familia_id"]
        valor = float(update_data.get("valor", fixo["valor"]))
        ja_pago = float(fixo.get("valor_pago") or 0)

        if update_data["pago"]:
            # PAGAR: gera transação despesa_fixa só do que falta (trigger debita
            # o saldo em conta). Sem trava de saldo: a reserva cobre o que faltar.
            falta = round(valor - ja_pago, 2)
            if falta > 0:
                db.table("transacoes").insert({
                    "familia_id": familia_id,
                    "usuario_id": str(user.id),
                    "tipo": "despesa_fixa",
                    "valor": falta,
                    "data": _data_pagamento(fixo),
                    "descricao": f"{fixo['nome']} (fixo {fixo['mes']})",
                    "fixo_id": fixo_id,
                }).execute()
            if fixo.get("valor_pago") is not None:
                update_data["valor_pago"] = valor
        else:
            # DESMARCAR: soft-delete das transações despesa_fixa (trigger estorna).
            # O que foi pago fora do app (sem transação) continua pago.
            estornadas = (db.table("transacoes").update({"deleted_at": datetime.now().isoformat()})
                          .eq("fixo_id", fixo_id).eq("tipo", "despesa_fixa")
                          .is_("deleted_at", "null").execute().data)
            if fixo.get("valor_pago") is not None:
                resto = round(ja_pago - sum(float(t["valor"]) for t in estornadas), 2)
                update_data["valor_pago"] = resto if resto > 0 else None

    # Se mudou o valor de um fixo JÁ pago: estorna a antiga e gera a nova
    valor_mudou = (
        "valor" in update_data and not mudou_status and fixo_ja_pago
        and abs(float(update_data["valor"]) - float(fixo["valor"])) > 0.001
    )
    if valor_mudou:
        db.table("transacoes").update({"deleted_at": datetime.now().isoformat()}) \
            .eq("fixo_id", fixo_id).eq("tipo", "despesa_fixa") \
            .is_("deleted_at", "null").execute()
        db.table("transacoes").insert({
            "familia_id": fixo["familia_id"],
            "usuario_id": str(user.id),
            "tipo": "despesa_fixa",
            "valor": float(update_data["valor"]),
            "data": _data_pagamento(fixo),
            "descricao": f"{fixo['nome']} (fixo {fixo['mes']}, corrigido)",
            "fixo_id": fixo_id,
        }).execute()

    result = db.table("gastos_fixos").update(update_data).eq("id", fixo_id).execute()
    return result.data[0]


class PagamentoParcial(BaseModel):
    valor: float = Field(gt=0)


@router.post("/{fixo_id}/pagamento")
def pagar_parte(
    fixo_id: str,
    payload: PagamentoParcial,
    user: AuthUser = Depends(get_current_user),
):
    """Paga parte de uma conta: gera a transação despesa_fixa desse valor e soma
    em valor_pago. Quando o pago alcança o valor da conta, ela fica quitada."""
    db = get_supabase()
    fixo_res = (db.table("gastos_fixos").select("*")
                .eq("id", fixo_id).eq("familia_id", user.familia_id).execute().data)
    if not fixo_res:
        raise HTTPException(status_code=404, detail="Fixo não encontrado")
    fixo = fixo_res[0]
    valor_conta = float(fixo["valor"])
    ja_pago = float(fixo.get("valor_pago") or (valor_conta if fixo.get("pago") else 0))
    falta = round(valor_conta - ja_pago, 2)
    if falta <= 0:
        raise HTTPException(status_code=400, detail="Esta conta já está quitada")
    if payload.valor > falta + 0.005:
        raise HTTPException(status_code=400, detail=f"O valor passa do que falta pagar (R$ {falta:.2f})")

    db.table("transacoes").insert({
        "familia_id": fixo["familia_id"],
        "usuario_id": str(user.id),
        "tipo": "despesa_fixa",
        "valor": round(payload.valor, 2),
        "data": datetime.now().strftime("%Y-%m-%d"),
        "descricao": f"{fixo['nome']} (pagamento parcial {fixo['mes']})",
        "fixo_id": fixo_id,
    }).execute()

    novo_pago = round(ja_pago + payload.valor, 2)
    return db.table("gastos_fixos").update({
        "valor_pago": novo_pago,
        "pago": novo_pago >= valor_conta - 0.005,
    }).eq("id", fixo_id).execute().data[0]


@router.delete("/{fixo_id}")
def deletar_fixo(
    fixo_id: str,
    user: AuthUser = Depends(get_current_user),
    familia_id: str = None,
):
    """Deleta um fixo. Se estava pago, estorna a transação despesa_fixa antes."""
    familia_id = assert_mesma_familia(user, familia_id)
    db = get_supabase()

    db.table("transacoes").update({"deleted_at": datetime.now().isoformat()}) \
        .eq("fixo_id", fixo_id).eq("tipo", "despesa_fixa") \
        .is_("deleted_at", "null").execute()

    result = db.table("gastos_fixos").delete().eq("id", fixo_id).eq("familia_id", familia_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Fixo não encontrado")
    return {"ok": True}
