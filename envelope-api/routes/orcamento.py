"""Rotas do orçado por mês (ver orcamento_mes.py)."""
import re
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from database import get_supabase
from auth import AuthUser, get_current_user, assert_mesma_familia
from fechamento_calculo import somar_meses
from orcamento_mes import montar_a_partir, orcado_efetivo

router = APIRouter()


def _mes_valido(mes: str) -> str:
    if not re.match(r"^\d{4}-(0[1-9]|1[0-2])$", mes):
        raise HTTPException(422, "mês deve ser YYYY-MM")
    return mes


def _dados(db, fam: str, mes: str):
    envs = (db.table("envelopes").select("id, valor_planejado")
            .eq("familia_id", fam).is_("deleted_at", "null").execute().data)
    linhas = db.table("orcamento_mes").select("envelope_id, valor_planejado").eq("familia_id", fam).eq("mes", mes).execute().data
    return envs, linhas


class ItemOrcado(BaseModel):
    envelope_id: str
    valor_planejado: float = Field(ge=0)


class OrcamentoPayload(BaseModel):
    itens: List[ItemOrcado]


@router.get("/{mes}")
def orcado_do_mes(mes: str, familia_id: str = None, user: AuthUser = Depends(get_current_user)):
    fam = assert_mesma_familia(user, familia_id)
    envs, linhas = _dados(get_supabase(), fam, _mes_valido(mes))
    return orcado_efetivo(envs, linhas)


@router.put("/{mes}")
def ajustar_orcado(mes: str, payload: OrcamentoPayload, user: AuthUser = Depends(get_current_user)):
    """Ajusta o orçado só deste mês."""
    fam = user.familia_id
    db = get_supabase()
    ids = {e["id"] for e in db.table("envelopes").select("id").eq("familia_id", fam).execute().data}
    linhas = []
    for i in payload.itens:
        if i.envelope_id not in ids:
            raise HTTPException(404, "Envelope não encontrado")
        linhas.append({"familia_id": fam, "envelope_id": i.envelope_id, "mes": _mes_valido(mes), "valor_planejado": i.valor_planejado})
    if linhas:
        db.table("orcamento_mes").upsert(linhas, on_conflict="familia_id,mes,envelope_id").execute()
    return {"ok": True, "itens": len(linhas)}


@router.post("/{mes}/montar")
def montar_mes(mes: str, user: AuthUser = Depends(get_current_user)):
    """Monta o orçado do mês a partir do anterior. Não sobrescreve valores já ajustados."""
    fam = user.familia_id
    db = get_supabase()
    _mes_valido(mes)
    envs, atuais = _dados(db, fam, mes)
    ja = {l["envelope_id"] for l in atuais}
    _, anterior = _dados(db, fam, somar_meses(mes, -1))
    novas = [l for l in montar_a_partir(envs, anterior, mes, fam) if l["envelope_id"] not in ja]
    if novas:
        db.table("orcamento_mes").insert(novas).execute()
    return {"ok": True, "criados": len(novas)}
