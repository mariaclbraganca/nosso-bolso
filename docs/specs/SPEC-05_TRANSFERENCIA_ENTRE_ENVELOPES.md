# SPEC-05 — Transferencia entre Envelopes

**Prioridade:** Alta (Semana 2)
**Esforco:** Baixo
**Status:** Planejado

---

## Problema

Para mover dinheiro do envelope "Lazer" para "Mercado", o usuario precisa:
1. Devolver dinheiro do Lazer ao saldo geral (nao existe essa opcao)
2. Abastecer Mercado com o saldo geral

Fluxo desnecessariamente complicado. Deveria ser direto.

## Solucao

### 1. Novo tipo de transacao: `transferencia`

**Opcao A (recomendada): Duas transacoes atomicas**

Criar endpoint que executa em sequencia:
1. Despesa no envelope origem (diminui saldo)
2. Abastecimento no envelope destino (aumenta saldo)
3. O `saldo_geral` NAO e afetado (dinheiro so muda de envelope)

**Endpoint:**
```
POST /envelopes/transferir
Body: {
    "origem_id": "<uuid>",
    "destino_id": "<uuid>",
    "valor": 200,
    "usuario_id": "<uuid>"
}
```

**Implementacao:**
```python
@router.post("/transferir")
def transferir_entre_envelopes(payload: TransferenciaEnvelope):
    db = get_supabase()
    # Debita origem
    db.table("envelopes").update({
        "saldo_atual": db.rpc("decrement", {
            "row_id": str(payload.origem_id),
            "amount": payload.valor
        })
    })
    # Na verdade, a forma mais simples e atualizar diretamente:
    origem = db.table("envelopes").select("saldo_atual").eq("id", str(payload.origem_id)).execute().data[0]
    destino = db.table("envelopes").select("saldo_atual").eq("id", str(payload.destino_id)).execute().data[0]

    db.table("envelopes").update({"saldo_atual": origem["saldo_atual"] - payload.valor}).eq("id", str(payload.origem_id)).execute()
    db.table("envelopes").update({"saldo_atual": destino["saldo_atual"] + payload.valor}).eq("id", str(payload.destino_id)).execute()

    return {"ok": True, "origem": str(payload.origem_id), "destino": str(payload.destino_id), "valor": payload.valor}
```

> **ATENCAO:** Essa abordagem NAO passa pelo trigger (transacao direta em envelopes). Para manter audit trail, considerar criar um tipo `transferencia` no trigger ou registrar 2 transacoes.

**Opcao B (com audit trail): Tipo `transferencia` no trigger**

```sql
-- Adicionar tipo no check constraint
ALTER TABLE transacoes DROP CONSTRAINT transacoes_tipo_check;
ALTER TABLE transacoes ADD CONSTRAINT transacoes_tipo_check
    CHECK (tipo IN ('receita', 'despesa', 'abastecimento', 'transferencia'));
```

Nesse caso, `transferencia` teria `envelope_id` (origem) e um novo campo `envelope_destino_id`. O trigger moveria saldo entre os dois envelopes.

### 2. Flutter — `TransferirSheet`

- Selecionar envelope origem (dropdown)
- Selecionar envelope destino (dropdown, exclui o origem)
- Valor (com validacao: nao pode ser maior que saldo do origem — ou NEGATIVE_OK)
- Mostrar saldo de cada envelope em tempo real
- Botao "Transferir"

### 3. Acesso

- Adicionar opcao "Transferir" no FAB speed dial (4a opcao)
- Ou botao "Transferir" dentro do `EnvelopeDetailSheet`

---

## Modelo Pydantic

```python
class TransferenciaEnvelope(BaseModel):
    origem_id: UUID
    destino_id: UUID
    valor: float
    usuario_id: UUID

    @field_validator('valor')
    @classmethod
    def valor_positivo(cls, v):
        if v <= 0:
            raise ValueError('valor deve ser maior que zero')
        return v

    @model_validator(mode='after')
    def ids_diferentes(self):
        if self.origem_id == self.destino_id:
            raise ValueError('origem e destino devem ser diferentes')
        return self
```

---

## Criterios de Aceite

- [ ] Transferencia debita origem e credita destino atomicamente
- [ ] `saldo_geral` NAO e afetado
- [ ] Validacao: origem != destino
- [ ] Validacao: valor > 0
- [ ] Historico mostra a transferencia (audit trail)
- [ ] Acessivel via FAB ou EnvelopeDetailSheet

---

## Arquivos Afetados

| Arquivo | Alteracao |
|---------|-----------|
| `envelope-api/routes/envelopes.py` | Adicionar `POST /transferir` |
| `envelope-api/models.py` | Adicionar `TransferenciaEnvelope` |
| Nova: `envelope-flutter/lib/screens/transferir_sheet.dart` | Tela de transferencia |
| `envelope-flutter/lib/widgets/speed_dial_fab.dart` | Adicionar 4a opcao |
