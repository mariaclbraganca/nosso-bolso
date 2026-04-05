from pydantic import BaseModel, field_validator, model_validator
from typing import Optional
from datetime import date
from uuid import UUID

class TransacaoCreate(BaseModel):
    valor: float
    tipo: str
    usuario_id: UUID
    envelope_id: Optional[UUID] = None
    descricao: Optional[str] = None
    data: date = date.today()
    familia_id: UUID

    @model_validator(mode='after')
    def validar_envelope_id(self):
        if self.tipo in ('despesa', 'abastecimento') and not self.envelope_id:
            raise ValueError(f'tipo {self.tipo} exige envelope_id')
        if self.tipo == 'receita' and self.envelope_id:
            raise ValueError('tipo receita não pode ter envelope_id')
        return self

    @field_validator('tipo')
    @classmethod
    def tipo_valido(cls, v):
        if v not in ('receita', 'despesa', 'abastecimento'):
            raise ValueError('tipo deve ser receita, despesa ou abastecimento')
        return v

    @field_validator('valor')
    @classmethod
    def valor_positivo(cls, v):
        if v <= 0:
            raise ValueError('valor deve ser maior que zero')
        return v

class AbastecerEnvelope(BaseModel):
    envelope_id: UUID
    valor: float
    usuario_id: UUID
    familia_id: UUID

class ReceitaCreate(BaseModel):
    """Receita: tipo sempre = 'receita', envelope_id sempre = None"""
    valor: float
    usuario_id: UUID
    descricao: Optional[str] = None
    data: date = date.today()
    familia_id: UUID

    @field_validator('valor')
    @classmethod
    def valor_positivo(cls, v):
        if v <= 0:
            raise ValueError('valor deve ser maior que zero')
        return v

class Usuario(BaseModel):
    id: UUID
    nome: str
    email: str
    familia_id: UUID
    role: str = 'membro'

class GastoFixoCreate(BaseModel):
    nome: str
    valor: float
    mes: str
    familia_id: UUID
    recorrente: bool = False
    dia_vencimento: Optional[int] = None

    @field_validator('dia_vencimento')
    @classmethod
    def dia_valido(cls, v):
        if v is not None and (v < 1 or v > 31):
            raise ValueError('dia_vencimento deve ser entre 1 e 31')
        return v

class TransacaoUpdate(BaseModel):
    valor: Optional[float] = None
    descricao: Optional[str] = None
    envelope_id: Optional[UUID] = None

    @field_validator('valor')
    @classmethod
    def valor_positivo(cls, v):
        if v is not None and v <= 0:
            raise ValueError('valor deve ser maior que zero')
        return v

class EnvelopeCreate(BaseModel):
    nome_envelope: str
    valor_planejado: float
    emoji: str = '📦'
    cor: str
    familia_id: UUID
    is_reserva: bool = False
    valor_objetivo: Optional[float] = None

class EnvelopeUpdate(BaseModel):
    nome_envelope: Optional[str] = None
    valor_planejado: Optional[float] = None
    emoji: Optional[str] = None
    cor: Optional[str] = None
    is_reserva: Optional[bool] = None
    valor_objetivo: Optional[float] = None

    @field_validator('valor_planejado')
    @classmethod
    def valor_positivo(cls, v):
        if v is not None and v <= 0:
            raise ValueError('valor_planejado deve ser maior que zero')
        return v

class RemanejarPayload(BaseModel):
    origem_id: UUID
    destino_id: UUID
    valor: float
    familia_id: UUID
    usuario_id: UUID

    @field_validator('valor')
    @classmethod
    def valor_positivo(cls, v):
        if v <= 0:
            raise ValueError('valor deve ser maior que zero')
        return v

class GastoFixoUpdate(BaseModel):
    pago: Optional[bool] = None
    nome: Optional[str] = None
    valor: Optional[float] = None
    recorrente: Optional[bool] = None
    dia_vencimento: Optional[int] = None

    @field_validator('dia_vencimento')
    @classmethod
    def dia_valido(cls, v):
        if v is not None and (v < 1 or v > 31):
            raise ValueError('dia_vencimento deve ser entre 1 e 31')
        return v

    @field_validator('valor')
    @classmethod
    def valor_positivo(cls, v):
        if v is not None and v <= 0:
            raise ValueError('valor deve ser maior que zero')
        return v
