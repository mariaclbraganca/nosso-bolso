from fastapi import APIRouter, HTTPException
from database import get_supabase
from datetime import date
import calendar

router = APIRouter()

@router.get("/stats")
def stats_mes(familia_id: str, mes: str = None):
    db = get_supabase()

    if mes:
        year, month = int(mes[:4]), int(mes[5:7])
        last_day = calendar.monthrange(year, month)[1]
        inicio = f"{mes}-01"
        fim = f"{mes}-{last_day:02d}"
    else:
        hoje = date.today()
        inicio = f"{hoje.year}-{hoje.month:02d}-01"
        last_day = calendar.monthrange(hoje.year, hoje.month)[1]
        fim = f"{hoje.year}-{hoje.month:02d}-{last_day:02d}"

    txs = db.table("transacoes").select(
        "valor, tipo, usuarios(nome)"
    ).eq("familia_id", familia_id).gte("data", inicio).lte("data", fim).execute().data

    gastos_u, receitas_u = {}, {}
    total_gastos = total_receitas = 0
    for t in txs:
        nome = t["usuarios"]["nome"]
        if t["tipo"] == "despesa":
            gastos_u[nome] = gastos_u.get(nome, 0) + t["valor"]
            total_gastos += t["valor"]
        elif t["tipo"] == "receita":
            receitas_u[nome] = receitas_u.get(nome, 0) + t["valor"]
            total_receitas += t["valor"]

    saldo_row = db.table("saldo_geral").select("valor_total_disponivel") \
        .eq("familia_id", familia_id).single().execute()
    if not saldo_row.data:
        raise HTTPException(status_code=404, detail="Família não encontrada")

    envelopes = db.table("envelopes").select("*").eq("familia_id", familia_id).execute()
    fixos = db.table("gastos_fixos").select("*").eq("familia_id", familia_id) \
        .eq("mes", inicio[:7]).execute()

    return {
        "saldo_disponivel": saldo_row.data["valor_total_disponivel"],
        "total_receitas_mes": total_receitas,
        "total_gastos_mes": total_gastos,
        "gastos_por_usuario": gastos_u,
        "receitas_por_usuario": receitas_u,
        "envelopes": envelopes.data,
        "fixos": fixos.data,
    }
