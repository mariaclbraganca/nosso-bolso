# SPEC-04 — Gastos Fixos Recorrentes

**Prioridade:** Alta (Semana 2)
**Esforco:** Medio
**Status:** Planejado

---

## Problema

Todo mes o usuario precisa recriar manualmente gastos como "Aluguel R$1.500", "Internet R$120". Nao existe automacao.

## Solucao

### 1. Novos campos na tabela `gastos_fixos`

```sql
ALTER TABLE public.gastos_fixos
ADD COLUMN recorrente boolean DEFAULT false,
ADD COLUMN frequencia text DEFAULT 'mensal'
    CHECK (frequencia IN ('mensal', 'semanal', 'anual')),
ADD COLUMN dia_vencimento integer DEFAULT 1
    CHECK (dia_vencimento BETWEEN 1 AND 31);
```

### 2. Endpoint de recorrencia

**`POST /fixos/recorrer`** — Chamado ao virar o mes (ou manualmente)

```python
@router.post("/recorrer")
def recorrer_fixos(familia_id: str, mes_destino: str):
    """Clona fixos recorrentes do mes anterior para o mes destino."""
    db = get_supabase()
    # Calcular mes anterior
    year, month = int(mes_destino[:4]), int(mes_destino[5:7])
    if month == 1:
        mes_anterior = f"{year-1}-12"
    else:
        mes_anterior = f"{year}-{month-1:02d}"

    fixos = db.table("gastos_fixos") \
        .select("nome, valor, familia_id, dia_vencimento") \
        .eq("familia_id", familia_id) \
        .eq("mes", mes_anterior) \
        .eq("recorrente", True) \
        .execute().data

    novos = []
    for f in fixos:
        novos.append({
            "nome": f["nome"],
            "valor": f["valor"],
            "familia_id": f["familia_id"],
            "mes": mes_destino,
            "pago": False,
            "recorrente": True,
            "dia_vencimento": f.get("dia_vencimento", 1),
        })

    if novos:
        db.table("gastos_fixos").insert(novos).execute()

    return {"clonados": len(novos), "mes": mes_destino}
```

### 3. Automacao no Flutter

Ao navegar para o mes seguinte no `FixosScreen`:
1. Verificar se ja existem fixos para aquele mes
2. Se nao: mostrar dialog "Deseja copiar os fixos recorrentes do mes anterior?"
3. Se sim: chamar `POST /fixos/recorrer`

### 4. UI de recorrencia

No `FormFixoSheet`, adicionar:
- Toggle "Repetir todo mes" (`recorrente`)
- Campo "Dia do vencimento" (`dia_vencimento`)
- Indicador visual: icone de loop nos itens recorrentes na lista

### 5. Modelo Pydantic atualizado

```python
class GastoFixoCreate(BaseModel):
    nome: str
    valor: float
    mes: str
    familia_id: Optional[str] = None
    recorrente: bool = False
    dia_vencimento: int = 1

    @field_validator('dia_vencimento')
    @classmethod
    def dia_valido(cls, v):
        if v < 1 or v > 31:
            raise ValueError('dia_vencimento deve ser entre 1 e 31')
        return v
```

---

## Criterios de Aceite

- [ ] `POST /fixos/` aceita campos `recorrente` e `dia_vencimento`
- [ ] `POST /fixos/recorrer` clona apenas fixos com `recorrente=true`
- [ ] Fixos clonados comecam com `pago=false`
- [ ] Nao duplica se ja existem fixos para o mes destino
- [ ] Toggle visual de recorrencia na lista de fixos
- [ ] Dialog de confirmacao ao entrar em mes vazio

---

## Arquivos Afetados

| Arquivo | Alteracao |
|---------|-----------|
| Supabase SQL | ALTER TABLE gastos_fixos + novos campos |
| `envelope-api/routes/fixos.py` | Adicionar `POST /recorrer` |
| `envelope-api/models.py` | Atualizar `GastoFixoCreate` |
| `envelope-flutter/lib/screens/fixos_screen.dart` | Dialog de recorrencia + icone loop |
| `envelope-flutter/lib/screens/form_fixo_sheet.dart` | Toggle recorrente + campo vencimento |
