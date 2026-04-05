from fastapi import APIRouter, HTTPException
from database import get_supabase
from datetime import date
import calendar

router = APIRouter()

@router.get("/insights")
def gerar_insights(familia_id: str, mes_atual: str):
    db = get_supabase()
    
    # 1. Obter stats do mês atual
    year, month = int(mes_atual[:4]), int(mes_atual[5:7])
    last_day = calendar.monthrange(year, month)[1]
    ini_atu = f"{mes_atual}-01"
    fim_atu = f"{mes_atual}-{last_day:02d}"
    
    # 2. Obter stats do mês anterior
    if month == 1:
        mes_ant = f"{year-1}-12"
    else:
        mes_ant = f"{year}-{month-1:02d}"
    
    y_ant, m_ant = int(mes_ant[:4]), int(mes_ant[5:7])
    last_day_ant = calendar.monthrange(y_ant, m_ant)[1]
    ini_ant = f"{mes_ant}-01"
    fim_ant = f"{mes_ant}-{last_day_ant:02d}"

    # Query transações agrupadas (simplificado: pegamos tudo e agrupamos em Python)
    txs_atu = db.table("transacoes").select("valor, envelope_id, envelopes(nome_envelope)") \
        .eq("familia_id", familia_id).eq("tipo", "despesa").is_("deleted_at", "null") \
        .gte("data", ini_atu).lte("data", fim_atu).execute().data
        
    txs_ant = db.table("transacoes").select("valor, envelope_id, envelopes(nome_envelope)") \
        .eq("familia_id", familia_id).eq("tipo", "despesa").is_("deleted_at", "null") \
        .gte("data", ini_ant).lte("data", fim_ant).execute().data

    def agrupar(txs):
        res = {}
        for t in txs:
            env = t["envelopes"]["nome_envelope"] if t["envelopes"] else "Outros"
            res[env] = res.get(env, 0) + float(t["valor"])
        return res

    res_atu = agrupar(txs_atu)
    res_ant = agrupar(txs_ant)
    
    insights = []
    
    # Lógica de IA (SPEC-17)
    for env, valor in res_atu.items():
        v_ant = res_ant.get(env, 0)
        if v_ant > 0:
            diff = ((valor - v_ant) / v_ant) * 100
            if diff > 20:
                insights.append({
                    "emoji": "⚠️", "titulo": f"Alerta em {env}",
                    "texto": f"Seus gastos aqui subiram {int(diff)}% em relação ao mês passado. Cuidado para não estourar!"
                })
            elif diff < -20:
                insights.append({
                    "emoji": "👏", "titulo": f"Economia em {env}",
                    "texto": f"Incrível! Você reduziu os gastos neste envelope em {int(abs(diff))}%."
                })

    # Insight de saldo geral
    saldo = db.table("saldo_geral").select("valor_total_disponivel").eq("familia_id", familia_id).single().execute().data
    if saldo and float(saldo["valor_total_disponivel"]) > 1000:
        insights.append({
            "emoji": "💰", "titulo": "Aporte Sugerido",
            "texto": "Seu saldo está robusto. Que tal destinar uma parte para sua Meta de Reserva?"
        })

    if not insights:
        insights.append({
            "emoji": "📅", "titulo": "Tudo sob controle",
            "texto": "Seus gastos estão estáveis. Continue acompanhando seus envelopes diariamente."
        })

    return insights
