"""Fechamento do dia — o ritual das 23h30.

GET  /dia/resumo  → gastos do dia da família, pendências com envelope sugerido,
                    quanto dá pra gastar por dia até o fim do ciclo e o streak.
POST /dia/fechar  → confirma as pendências (sugestão ou ajuste do usuário) e
                    registra o fechamento do dia da família.
"""
import calendar
import logging
import re
import unicodedata
from collections import Counter
from datetime import date, datetime, timedelta
from typing import Optional
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from auth import AuthUser, get_current_user
from database import get_supabase
from ia_compras.mongo_client import get_compras_collection
from ia_compras.router import integrar_compra

router = APIRouter()
logger = logging.getLogger(__name__)

TZ = ZoneInfo("America/Sao_Paulo")

# Fallback quando o estabelecimento nunca apareceu: palavra-chave → trecho do nome do envelope
_PALAVRAS_ENVELOPE = [
    (("SUPERMERC", "MERCADO", "ATACAD", "TATICO", "ASSAI", "ATACADAO", "HORTIFRUTI", "PADARIA", "ACOUGUE"),
     ("MERCADO", "ALIMENTA")),
    (("IFOOD", "RAPPI", "RESTAURANTE", "LANCHONETE", "PIZZA", "BURGER"),
     ("DELIVERY", "IFOOD", "ALIMENTA", "LAZER")),
    (("POSTO", "COMBUST", "SHELL", "IPIRANGA", "PETROBRAS", "UBER"),
     ("COMBUST", "CARRO", "TRANSPORTE", "GASOLINA")),
    (("FARMACIA", "DROGA", "DROGASIL", "PAGUE MENOS"),
     ("FARMACIA", "SAUDE")),
]

_STOPWORDS = {"DE", "DA", "DO", "DOS", "DAS", "E", "LTDA", "SA", "ME", "EIRELI", "COMPRA", "PIX", "NO", "NA"}


class AjusteEnvelope(BaseModel):
    compra_id: str
    envelope_id: str


class FecharDiaRequest(BaseModel):
    data: Optional[date] = None
    ajustes: list[AjusteEnvelope] = []   # troca do envelope sugerido
    descartar: list[str] = []            # compra_ids que não são gasto (ex.: duplicada)


def _hoje() -> date:
    return datetime.now(TZ).date()


def _normalizar(texto: str) -> str:
    t = unicodedata.normalize("NFKD", texto or "").encode("ascii", "ignore").decode()
    return re.sub(r"[^A-Z0-9 ]", " ", t.upper())


def _chave_estabelecimento(nome: str) -> str:
    """Primeiras 2 palavras significativas: 'SUPERMERCADO TATICO LTDA' → 'SUPERMERCADO TATICO'."""
    tokens = [t for t in _normalizar(nome).split() if t not in _STOPWORDS and len(t) > 1]
    return " ".join(tokens[:2])


def _envelopes_ativos(db, fam: str) -> list[dict]:
    return db.table("envelopes").select("id, nome_envelope, emoji, saldo_atual, natureza, is_reserva") \
        .eq("familia_id", fam).is_("deleted_at", "null").execute().data or []


def _historico_despesas(db, fam: str) -> list[dict]:
    desde = (_hoje() - timedelta(days=180)).isoformat()
    return db.table("transacoes").select("descricao, envelope_id") \
        .eq("familia_id", fam).eq("tipo", "despesa").gte("data", desde) \
        .is_("deleted_at", "null").not_.is_("envelope_id", "null") \
        .order("data", desc=True).limit(1000).execute().data or []


def _sugerir_envelope(estabelecimento: str, historico: list[dict], envelopes: list[dict]) -> Optional[dict]:
    ativos = {e["id"]: e for e in envelopes}
    chave = _chave_estabelecimento(estabelecimento)

    # 1. Histórico da família: envelope mais usado para o mesmo estabelecimento
    if chave:
        votos = Counter(
            t["envelope_id"] for t in historico
            if t["envelope_id"] in ativos and chave in _normalizar(t.get("descricao") or "")
        )
        if votos:
            return ativos[votos.most_common(1)[0][0]]

    # 2. Palavra-chave no nome do estabelecimento → envelope com nome compatível
    nome = _normalizar(estabelecimento)
    for gatilhos, alvos in _PALAVRAS_ENVELOPE:
        if any(g in nome for g in gatilhos):
            for alvo in alvos:
                for e in envelopes:
                    if alvo in _normalizar(e["nome_envelope"]):
                        return e
    return None


def _nomes_membros(db, fam: str) -> dict[str, str]:
    rows = db.table("usuarios").select("id, nome").eq("familia_id", fam).execute().data or []
    return {r["id"]: (r.get("nome") or "").split(" ")[0] for r in rows}


def _streak(db, fam: str, hoje: date) -> int:
    rows = db.table("fechamentos_dia").select("data").eq("familia_id", fam) \
        .lte("data", hoje.isoformat()).order("data", desc=True).limit(400).execute().data or []
    fechados = {r["data"] for r in rows}
    # Hoje ainda aberto não quebra a sequência: conta a partir de ontem
    dia = hoje if hoje.isoformat() in fechados else hoje - timedelta(days=1)
    n = 0
    while dia.isoformat() in fechados:
        n += 1
        dia -= timedelta(days=1)
    return n


def _pendentes(fam: str) -> list[dict]:
    try:
        return list(get_compras_collection().find(
            {"familia_id": fam, "status_integracao": "pendente"},
            {"_id": 0, "compra_id": 1, "supermercado": 1, "valor_total": 1,
             "data_compra": 1, "fonte": 1, "usuario_id": 1},
        ).sort("data_compra", 1))
    except Exception as e:
        logger.warning("dia: MongoDB indisponível ao listar pendentes: %s", e)
        return []


def _montar_resumo(db, fam: str, dia: date) -> dict:
    envelopes = _envelopes_ativos(db, fam)
    historico = _historico_despesas(db, fam)
    membros = _nomes_membros(db, fam)

    gastos = db.table("transacoes").select("id, valor, descricao, envelope_id, usuario_id") \
        .eq("familia_id", fam).eq("tipo", "despesa").eq("data", dia.isoformat()) \
        .is_("deleted_at", "null").execute().data or []
    env_por_id = {e["id"]: e for e in envelopes}

    pendentes = []
    for p in _pendentes(fam):
        sug = _sugerir_envelope(p.get("supermercado", ""), historico, envelopes)
        pendentes.append({
            "compra_id": p["compra_id"],
            "estabelecimento": p.get("supermercado"),
            "valor": float(p.get("valor_total") or 0),
            "data": str(p.get("data_compra", ""))[:10],
            "fonte": p.get("fonte"),
            "quem": membros.get(p.get("usuario_id") or ""),
            "envelope_sugerido": {"id": sug["id"], "nome": sug["nome_envelope"], "emoji": sug.get("emoji")}
                                 if sug else None,
        })

    total_confirmado = round(sum(float(g["valor"]) for g in gastos), 2)
    total_pendente_hoje = round(sum(p["valor"] for p in pendentes if p["data"] == dia.isoformat()), 2)

    # Disponível para gastar: envelopes de consumo (reserva e objetivo ficam de fora)
    disponivel = round(sum(
        float(e.get("saldo_atual") or 0) for e in envelopes
        if (e.get("natureza") or ("reserva" if e.get("is_reserva") else "consumo")) == "consumo"
    ), 2)
    ultimo_dia = calendar.monthrange(dia.year, dia.month)[1]
    dias_restantes = ultimo_dia - dia.day   # de amanhã até o fim do ciclo
    # Pendentes ainda vão sair dos envelopes: desconta para não inflar o número
    disponivel_real = round(disponivel - sum(p["valor"] for p in pendentes), 2)
    por_dia = round(max(disponivel_real, 0) / dias_restantes, 2) if dias_restantes > 0 else None

    fech = db.table("fechamentos_dia").select("usuario_id, fechado_em") \
        .eq("familia_id", fam).eq("data", dia.isoformat()).execute().data

    return {
        "data": dia.isoformat(),
        "gastos": [{
            "id": g["id"], "valor": float(g["valor"]), "descricao": g.get("descricao"),
            "quem": membros.get(g.get("usuario_id") or ""),
            "envelope": env_por_id.get(g.get("envelope_id"), {}).get("nome_envelope"),
        } for g in gastos],
        "pendentes": pendentes,
        "total_dia": round(total_confirmado + total_pendente_hoje, 2),
        "disponivel_consumo": disponivel_real,
        "dias_restantes": dias_restantes,
        "pode_gastar_por_dia": por_dia,
        "fechado": bool(fech),
        "fechado_por": membros.get(fech[0]["usuario_id"]) if fech else None,
        "streak": _streak(db, fam, dia),
    }


@router.get("/resumo")
def resumo_dia(data: Optional[date] = None, user: AuthUser = Depends(get_current_user)):
    return _montar_resumo(get_supabase(), user.familia_id, data or _hoje())


@router.post("/fechar")
def fechar_dia(payload: FecharDiaRequest, user: AuthUser = Depends(get_current_user)):
    fam = user.familia_id
    db = get_supabase()
    dia = payload.data or _hoje()
    col = get_compras_collection()

    envelopes = _envelopes_ativos(db, fam)
    ids_validos = {e["id"] for e in envelopes}
    historico = _historico_despesas(db, fam)
    ajustes = {a.compra_id: a.envelope_id for a in payload.ajustes}
    if any(env not in ids_validos for env in ajustes.values()):
        raise HTTPException(400, "Envelope inválido no ajuste")

    for compra_id in payload.descartar:
        col.update_one({"compra_id": compra_id, "familia_id": fam, "status_integracao": "pendente"},
                       {"$set": {"status_integracao": "cancelado"}})

    confirmadas, sem_envelope, erros = 0, [], []
    for compra in col.find({"familia_id": fam, "status_integracao": "pendente"}):
        env_id = ajustes.get(compra["compra_id"])
        if not env_id:
            sug = _sugerir_envelope(compra.get("supermercado", ""), historico, envelopes)
            env_id = sug["id"] if sug else None
        if not env_id:
            sem_envelope.append(compra["compra_id"])
            continue
        try:
            integrar_compra(compra, env_id, compra.get("usuario_id") or user.id, fam)
            confirmadas += 1
        except Exception as e:
            logger.error("dia: falha ao integrar compra %s: %s", compra["compra_id"], e)
            erros.append(compra["compra_id"])

    # Sem envelope para alguma pendência → o dia não fecha; o app pede para escolher
    if sem_envelope or erros:
        resumo = _montar_resumo(db, fam, dia)
        return {"fechado": False, "confirmadas": confirmadas,
                "sem_envelope": sem_envelope, "erros": erros, "resumo": resumo}

    total = db.table("transacoes").select("valor").eq("familia_id", fam).eq("tipo", "despesa") \
        .eq("data", dia.isoformat()).is_("deleted_at", "null").execute().data or []
    db.table("fechamentos_dia").upsert({
        "familia_id": fam,
        "data": dia.isoformat(),
        "usuario_id": user.id,
        "fechado_em": datetime.now(TZ).isoformat(),
        "total_gasto": round(sum(float(t["valor"]) for t in total), 2),
        "confirmadas": confirmadas,
    }, on_conflict="familia_id,data").execute()

    return {"fechado": True, "confirmadas": confirmadas, "resumo": _montar_resumo(db, fam, dia)}
