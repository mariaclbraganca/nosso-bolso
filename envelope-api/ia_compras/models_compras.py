from enum import Enum
from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime
from uuid import UUID


class CategoriaItem(str, Enum):
    PROTEINAS = "Proteínas"
    CARBOIDRATOS = "Carboidratos"
    HORTIFRUTI = "Hortifrúti"
    LATICINIOS = "Laticínios"
    PADARIA = "Padaria"
    BEBIDAS = "Bebidas"
    LANCHES = "Lanches"
    TEMPEROS = "Temperos e Condimentos"
    LIMPEZA = "Limpeza"
    HIGIENE = "Higiene Pessoal"
    CONGELADOS = "Congelados"
    GRAOS = "Grãos e Cereais"
    OUTROS = "Outros"


class StatusConsumo(str, Enum):
    ATIVO = "ativo"
    ACABOU = "acabou"
    ESTRAGOU = "estragou"


class StatusIntegracao(str, Enum):
    PENDENTE = "pendente"
    CONFIRMADO = "confirmado"
    CANCELADO = "cancelado"
    FALHOU = "falhou"


# --- Requests ---

class IngestaoRequest(BaseModel):
    familia_id: UUID
    qr_code_url: str

    @field_validator("qr_code_url")
    @classmethod
    def url_valida(cls, v):
        if "nfce" not in v.lower() and "sefaz" not in v.lower():
            raise ValueError("URL não parece ser de uma NFC-e da SEFAZ")
        return v


class FeedbackItemRequest(BaseModel):
    compra_id: str
    nome_padronizado: str
    status: StatusConsumo


class ConfirmarCompraRequest(BaseModel):
    compra_id: str
    familia_id: UUID
    usuario_id: UUID
    envelope_id: UUID


class PlanejamentoRequest(BaseModel):
    familia_id: UUID
    dias: int = 15

    @field_validator("dias")
    @classmethod
    def dias_valido(cls, v):
        if v not in (7, 15, 30):
            raise ValueError("dias deve ser 7, 15 ou 30")
        return v


class MergeProdutoRequest(BaseModel):
    produto_manter_id: str
    produto_remover_id: str


# --- Responses ---

class ItemExtraido(BaseModel):
    nome_original: str
    nome_padronizado: str
    categoria: CategoriaItem
    quantidade: float
    unidade: str
    valor_unitario: float
    valor_total_item: float


class CompraExtraida(BaseModel):
    compra_id: str
    supermercado: str
    valor_total: float
    data_compra: datetime
    itens: list[ItemExtraido]
    status_integracao: StatusIntegracao = StatusIntegracao.PENDENTE


class ItemLista(BaseModel):
    nome: str
    categoria: CategoriaItem
    quantidade_sugerida: float
    unidade: str
    preco_estimado: float
    motivo: str
    corte_sugerido: bool = False


class ListaComprasGerada(BaseModel):
    familia_id: str
    dias_cobertura: int
    saldo_envelope: float
    custo_estimado_total: float
    dentro_do_orcamento: bool
    itens: list[ItemLista]
    gerado_em: datetime
