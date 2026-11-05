"""
Rota de FECHAMENTO MENSAL e VISÕES (mês / ano).

Resolve a falta das três visões que o app não tinha:
- Fechar o mês: tira o snapshot de cada envelope e (para consumo) zera o saldo.
- Visão do mês: o retrato limpo — quanto foi planejado, gasto, o que sobrou.
- Visão do ano: empilha os meses para revelar padrões que o dia a dia esconde.

Depende de: migration 03 (fn_fechar_mes + historico_envelopes + natureza).
"""
from fastapi import APIRouter, Depends, HTTPException
from database import get_supabase
from models import FecharMesPayload
from fechamento_calculo import apurar, ciclo_fatura, intervalo_mes, somar_meses
from auth import AuthUser, get_current_user, assert_mesma_familia
from datetime import datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo
from pydantic import BaseModel

router = APIRouter()


@router.post("/fechar")
def fechar_mes(
    payload: FecharMesPayload,
    user: AuthUser = Depends(get_current_user),
):
    """
    Fecha o mês: grava o snapshot de cada envelope em historico_envelopes.
    Envelopes de consumo zeram (novo mês limpo); objetivo/reserva acumulam.
    Idempotente: rodar duas vezes no mesmo mês só atualiza o snapshot.
    """
    fam = assert_mesma_familia(user, payload.familia_id)
    db = get_supabase()

    # Apuração no backend (regras da família): não usa fn_fechar_ciclo, que
    # zerava o saldo geral. O fechamento só grava o retrato; saldo nunca muda.
    ini, fim = intervalo_mes(payload.mes)
    ini_ciclo, _ = ciclo_fatura(payload.mes)
    prox = somar_meses(payload.mes, 1)
    cols = "tipo, valor, data, forma_pagamento, descricao, envelope_id"
    mes_tx = (db.table("transacoes").select(cols).eq("familia_id", fam).is_("deleted_at", "null")
              .gte("data", ini).lte("data", fim).execute().data)
    ciclo_tx = (db.table("transacoes").select(cols).eq("familia_id", fam).is_("deleted_at", "null")
                .gte("data", ini_ciclo).lte("data", fim).execute().data)
    envs = (db.table("envelopes").select("id, nome_envelope, valor_planejado, natureza")
            .eq("familia_id", fam).is_("deleted_at", "null").execute().data)
    comps = (db.table("cartao_compromissos").select("valor, mes_fatura")
             .eq("familia_id", fam).is_("deleted_at", "null").gte("mes_fatura", prox).execute().data)
    fixos = (db.table("gastos_fixos").select("valor, valor_pago, pago")
             .eq("familia_id", fam).eq("mes", prox).execute().data)
    saldo = (db.table("saldo_geral").select("valor_total_disponivel").eq("familia_id", fam).execute().data)
    apurado = apurar(payload.mes, mes_tx, envs, comps, fixos,
                     float(saldo[0]["valor_total_disponivel"]) if saldo else 0.0, ciclo_tx)

    db.table("historico_envelopes").delete().eq("familia_id", fam).eq("mes", payload.mes).execute()
    if apurado["envelopes"]:
        db.table("historico_envelopes").insert([{**l, "familia_id": fam} for l in apurado["envelopes"]]).execute()
    linha = {**apurado["mensal"], "familia_id": fam, "fechado_em": datetime.now(ZoneInfo("UTC")).isoformat()}
    ja = db.table("historico_mensal").select("id").eq("familia_id", fam).eq("mes", payload.mes).execute().data
    if ja:
        db.table("historico_mensal").update(linha).eq("id", ja[0]["id"]).execute()
    else:
        db.table("historico_mensal").insert(linha).execute()

    m = apurado["mensal"]
    return {
        "status": "success",
        "mes": payload.mes,
        "envelopes_processados": len(apurado["envelopes"]),
        "ciclo": {
            "receita": m["receita_total"], "saidas": round(m["total_consumo"] + m["total_compromisso"], 2),
            "resultado": m["resultado_mes"], "coberto_por_fora": m["coberto_por_fora"],
        },
        "a_pagar_mes_seguinte": m["extras"],
    }


# Meses antes do modelo novo (out/2026) ficam como estão: não fecham sozinhos.
INICIO_FECHAMENTO_AUTOMATICO = "2026-10"


class FechamentoAutomaticoPayload(BaseModel):
    familia_id: UUID


@router.post("/automatico")
def fechar_automatico(
    payload: FechamentoAutomaticoPayload,
    user: AuthUser = Depends(get_current_user),
):
    """
    O mês fecha sozinho: o app chama ao abrir. Fecha o mês anterior (horário de
    Brasília) se ainda não foi fechado. Rodar de novo no mesmo mês não faz nada.
    """
    fam = assert_mesma_familia(user, payload.familia_id)
    hoje = datetime.now(ZoneInfo("America/Sao_Paulo"))
    anterior = (hoje.replace(day=1) - timedelta(days=1)).strftime("%Y-%m")
    if anterior < INICIO_FECHAMENTO_AUTOMATICO:
        return {"fechado": False, "mes": anterior, "motivo": "antes do modelo novo"}

    db = get_supabase()
    ja = (db.table("historico_mensal").select("mes")
          .eq("familia_id", fam).eq("mes", anterior).limit(1).execute().data)
    if ja:
        return {"fechado": False, "mes": anterior, "motivo": "já fechado"}

    r = fechar_mes(FecharMesPayload(familia_id=fam, mes=anterior), user)
    return {"fechado": True, "mes": anterior, "ciclo": r["ciclo"]}


@router.get("/retrospectiva/{mes}")
def retrospectiva_mes(
    mes: str,
    familia_id: str,
    user: AuthUser = Depends(get_current_user),
):
    """
    A retrospectiva do mês: o que ficou guardado no fechamento do ciclo.
    Mostra receita, gastos, resultado e — se ficou devendo — quanto foi coberto
    por fora. NUNCA expõe a reserva de emergência (que não existe no app).
    """
    fam = assert_mesma_familia(user, familia_id)
    db = get_supabase()
    r = (db.table("historico_mensal")
         .select("mes, receita_total, total_consumo, total_compromisso, "
                 "resultado_mes, coberto_por_fora, parcelas_restantes_valor, parcelas_restantes_qtd, "
                 "saldo_final, extras, fechado_em")
         .eq("familia_id", fam).eq("mes", mes).limit(1).execute())
    if not r.data:
        raise HTTPException(status_code=404, detail="Mês ainda não foi fechado.")
    return r.data[0]


@router.get("/mes/{mes}")
def visao_mes(
    mes: str,
    user: AuthUser = Depends(get_current_user),
    familia_id: str = None,
):
    """
    Visão do mês: o retrato de um mês já fechado (do histórico) ou em andamento.
    Para mês fechado, lê o snapshot. Para o mês corrente, calcula ao vivo.
    """
    familia_id = assert_mesma_familia(user, familia_id)
    db = get_supabase()

    # Tentar o snapshot histórico primeiro
    hist = (db.table("historico_envelopes").select("*")
            .eq("familia_id", familia_id).eq("mes", mes)
            .order("nome_envelope").execute().data)

    if hist:
        total_gasto = sum(float(h["total_gasto"]) for h in hist)
        return {
            "mes": mes,
            "fonte": "historico",
            "total_gasto": round(total_gasto, 2),
            "envelopes": hist,
        }

    # Mês corrente (sem snapshot): calcular ao vivo
    import calendar
    year, month = int(mes[:4]), int(mes[5:7])
    last_day = calendar.monthrange(year, month)[1]
    inicio, fim = f"{mes}-01", f"{mes}-{last_day:02d}"

    txs = (db.table("transacoes")
           .select("valor, tipo, envelope_id, envelopes(nome_envelope, natureza)")
           .eq("familia_id", familia_id).is_("deleted_at", "null")
           .gte("data", inicio).lte("data", fim).execute().data)

    por_envelope = {}
    for t in txs:
        if t["tipo"] != "despesa" or not t.get("envelope_id"):
            continue
        env = t["envelope_id"]
        if env not in por_envelope:
            nome = t["envelopes"]["nome_envelope"] if t.get("envelopes") else "?"
            natureza = t["envelopes"].get("natureza", "consumo") if t.get("envelopes") else "consumo"
            por_envelope[env] = {"nome_envelope": nome, "natureza": natureza, "total_gasto": 0.0}
        por_envelope[env]["total_gasto"] += float(t["valor"])

    envelopes = list(por_envelope.values())
    total_gasto = sum(e["total_gasto"] for e in envelopes)
    return {
        "mes": mes,
        "fonte": "ao_vivo",
        "total_gasto": round(total_gasto, 2),
        "envelopes": envelopes,
    }


@router.get("/ano/{ano}")
def visao_ano(
    ano: str,
    user: AuthUser = Depends(get_current_user),
    familia_id: str = None,
):
    """
    Visão do ano: empilha os meses fechados para revelar padrões.
    Retorna série mensal por envelope + totais — a base para "descobrir hábitos".
    """
    familia_id = assert_mesma_familia(user, familia_id)
    db = get_supabase()

    # Todos os snapshots do ano
    hist = (db.table("historico_envelopes").select("*")
            .eq("familia_id", familia_id)
            .gte("mes", f"{ano}-01").lte("mes", f"{ano}-12")
            .order("mes").execute().data)

    if not hist:
        return {"ano": ano, "meses_fechados": 0, "series": {}, "resumo": {}}

    # Agrupar por categoria → série mensal (padrões que o dia a dia esconde)
    series = {}
    meses_set = set()
    for h in hist:
        nome = h["nome_envelope"]
        mes = h["mes"]
        meses_set.add(mes)
        series.setdefault(nome, {})[mes] = float(h["total_gasto"])

    # Resumo por categoria: média, máximo, total no ano
    resumo = {}
    for nome, meses in series.items():
        valores = list(meses.values())
        resumo[nome] = {
            "total_ano": round(sum(valores), 2),
            "media_mensal": round(sum(valores) / len(valores), 2),
            "maior_mes": round(max(valores), 2),
            "menor_mes": round(min(valores), 2),
            "meses_com_dados": len(valores),
        }

    total_ano = sum(r["total_ano"] for r in resumo.values())

    return {
        "ano": ano,
        "meses_fechados": len(meses_set),
        "meses": sorted(meses_set),
        "series": series,
        "resumo": resumo,
        "total_ano": round(total_ano, 2),
    }
