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
from auth import AuthUser, get_current_user, assert_mesma_familia

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

    # Chama a função SQL fn_fechar_mes (faz snapshot + zera consumo atomicamente)
    result = db.rpc("fn_fechar_mes", {
        "p_familia_id": fam,
        "p_mes": payload.mes,
    }).execute()

    envelopes_fechados = result.data or []
    zerados = [e for e in envelopes_fechados if e.get("out_zerado")]

    # Fecha o CICLO: apura resultado do mês (receita - despesas - fixos),
    # grava a memória (resultado_mes / coberto_por_fora) e zera o saldo_geral.
    ciclo = db.rpc("fn_fechar_ciclo", {
        "p_familia_id": fam,
        "p_mes": payload.mes,
    }).execute()
    ciclo_dados = (ciclo.data or [{}])[0]

    return {
        "status": "success",
        "mes": payload.mes,
        "envelopes_processados": len(envelopes_fechados),
        "envelopes_zerados": len(zerados),
        "detalhe": envelopes_fechados,
        # A retrospectiva do ciclo — a consciência do mês
        "ciclo": {
            "receita": ciclo_dados.get("receita", 0),
            "saidas": ciclo_dados.get("saidas", 0),
            "resultado": ciclo_dados.get("resultado", 0),
            "coberto_por_fora": ciclo_dados.get("coberto", 0),
        },
    }


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
                 "resultado_mes, coberto_por_fora, parcelas_restantes_valor, parcelas_restantes_qtd")
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
