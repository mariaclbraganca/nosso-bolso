"""
Rota do PLANO DO MÊS — entradas previstas e compromissos do cartão.

- entradas_previstas: salário, aluguel recebido, vale… (previsto × recebido).
  Recorrentes são replicadas do mês anterior ao listar (igual aos fixos).
- cartao_compromissos: parcelas e assinaturas que caem nas próximas faturas.

Depende da migration 09 (SQL_09_plano_do_mes.sql).
"""
from datetime import datetime, timezone
from typing import Literal, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, model_validator

from auth import AuthUser, assert_mesma_familia, get_current_user
from database import get_supabase

router = APIRouter()

_MES = r"^\d{4}-\d{2}$"


def mes_anterior(mes: str) -> str:
    ano, m = int(mes[:4]), int(mes[5:7])
    return f"{ano - 1}-12" if m == 1 else f"{ano}-{m - 1:02d}"


def _agora() -> str:
    return datetime.now(timezone.utc).isoformat()


# ── Entradas previstas ────────────────────────────────────────────────────────

class EntradaCreate(BaseModel):
    familia_id: UUID
    mes: str = Field(pattern=_MES)
    nome: str = Field(min_length=1, max_length=80)
    valor: float = Field(ge=0)
    dia: Optional[int] = Field(default=None, ge=1, le=31)
    tipo: Literal["dinheiro", "vale", "eventual"] = "dinheiro"
    recorrente: bool = True
    # Receita lançada na hora (ex.: trabalho de um irmão): já entra recebida.
    recebido: bool = False
    valor_recebido: Optional[float] = Field(default=None, ge=0)
    quem: Optional[str] = Field(default=None, max_length=60)
    destino: Literal["mes", "reserva"] = "mes"


class EntradaUpdate(BaseModel):
    nome: Optional[str] = Field(default=None, min_length=1, max_length=80)
    valor: Optional[float] = Field(default=None, ge=0)
    dia: Optional[int] = Field(default=None, ge=1, le=31)
    tipo: Optional[Literal["dinheiro", "vale", "eventual"]] = None
    recorrente: Optional[bool] = None
    quem: Optional[str] = Field(default=None, max_length=60)
    destino: Optional[Literal["mes", "reserva"]] = None
    recebido: Optional[bool] = None
    valor_recebido: Optional[float] = Field(default=None, ge=0)


def replicar_recorrentes(atuais: list[dict], anteriores: list[dict], mes: str, familia_id: str) -> list[dict]:
    """Entradas recorrentes do mês anterior que ainda não existem neste mês."""
    nomes = {e["nome"] for e in atuais}
    return [{
        "familia_id": familia_id, "mes": mes, "nome": e["nome"], "valor": e["valor"],
        "dia": e.get("dia"), "tipo": e.get("tipo", "dinheiro"), "recorrente": True,
        "destino": e.get("destino") or "mes",
    } for e in anteriores if e.get("recorrente") and e["nome"] not in nomes]


@router.get("/entradas")
def listar_entradas(mes: str, familia_id: str = None, user: AuthUser = Depends(get_current_user)):
    familia_id = assert_mesma_familia(user, familia_id)
    db = get_supabase()

    def buscar(m):
        return (db.table("entradas_previstas").select("*")
                .eq("familia_id", familia_id).eq("mes", m).is_("deleted_at", "null")
                .order("dia").execute().data)

    atuais = buscar(mes)
    novos = replicar_recorrentes(atuais, buscar(mes_anterior(mes)), mes, familia_id)
    if novos:
        db.table("entradas_previstas").insert(novos).execute()
        atuais = buscar(mes)
    return atuais


@router.post("/entradas")
def criar_entrada(payload: EntradaCreate, user: AuthUser = Depends(get_current_user)):
    fam = assert_mesma_familia(user, str(payload.familia_id))
    data = payload.model_dump()
    data["familia_id"] = fam
    return get_supabase().table("entradas_previstas").insert(data).execute().data[0]


def _da_familia(tabela: str, item_id: str, user: AuthUser) -> None:
    res = (get_supabase().table(tabela).select("id")
           .eq("id", item_id).eq("familia_id", user.familia_id).is_("deleted_at", "null").execute())
    if not res.data:
        raise HTTPException(status_code=404, detail="Não encontrado")


@router.patch("/entradas/{entrada_id}")
def atualizar_entrada(entrada_id: str, payload: EntradaUpdate, user: AuthUser = Depends(get_current_user)):
    _da_familia("entradas_previstas", entrada_id, user)
    mudancas = payload.model_dump(exclude_unset=True)
    if not mudancas:
        raise HTTPException(status_code=422, detail="Nada para atualizar")
    return (get_supabase().table("entradas_previstas").update(mudancas)
            .eq("id", entrada_id).execute().data[0])


@router.delete("/entradas/{entrada_id}")
def deletar_entrada(entrada_id: str, user: AuthUser = Depends(get_current_user)):
    _da_familia("entradas_previstas", entrada_id, user)
    get_supabase().table("entradas_previstas").update({"deleted_at": _agora()}).eq("id", entrada_id).execute()
    return {"ok": True}


# ── Compromissos do cartão ────────────────────────────────────────────────────

class CompromissoCreate(BaseModel):
    familia_id: UUID
    descricao: str = Field(min_length=1, max_length=80)
    valor: float = Field(gt=0)
    mes_fatura: str = Field(pattern=_MES)
    parcela_atual: Optional[int] = Field(default=None, ge=1)
    total_parcelas: Optional[int] = Field(default=None, ge=1)
    cartao: str = Field(default="Nubank", max_length=40)

    @model_validator(mode="after")
    def parcelas_coerentes(self):
        if (self.parcela_atual is None) != (self.total_parcelas is None):
            raise ValueError("Informe parcela atual e total juntos (ou nenhum, para assinatura)")
        if self.parcela_atual is not None and self.parcela_atual > self.total_parcelas:
            raise ValueError("Parcela atual maior que o total")
        return self


@router.get("/cartao")
def listar_compromissos(familia_id: str = None, user: AuthUser = Depends(get_current_user)):
    familia_id = assert_mesma_familia(user, familia_id)
    return (get_supabase().table("cartao_compromissos").select("*")
            .eq("familia_id", familia_id).is_("deleted_at", "null")
            .order("mes_fatura").execute().data)


@router.post("/cartao")
def criar_compromisso(payload: CompromissoCreate, user: AuthUser = Depends(get_current_user)):
    fam = assert_mesma_familia(user, str(payload.familia_id))
    data = payload.model_dump()
    data["familia_id"] = fam
    return get_supabase().table("cartao_compromissos").insert(data).execute().data[0]


@router.delete("/cartao/{compromisso_id}")
def deletar_compromisso(compromisso_id: str, user: AuthUser = Depends(get_current_user)):
    _da_familia("cartao_compromissos", compromisso_id, user)
    get_supabase().table("cartao_compromissos").update({"deleted_at": _agora()}).eq("id", compromisso_id).execute()
    return {"ok": True}
