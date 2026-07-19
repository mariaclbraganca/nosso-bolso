# SPEC-01 — Editar Transações, Envelopes e Gastos Fixos

**Prioridade:** Alta (Semana 1)
**Esforço:** Medio
**Status:** Planejado

---

## Problema

Hoje o unico jeito de corrigir um erro e deletar e recriar. Nao existe nenhum endpoint ou tela de edicao.

## Escopo

### 1. Editar Transacao

**Backend — `PUT /transacoes/{id}`**
- Campos editaveis: `valor`, `descricao`, `envelope_id` (apenas para despesa/abastecimento)
- Campos imutaveis: `tipo`, `usuario_id`, `familia_id`
- Validacoes: mesmas do `POST` (valor > 0, envelope obrigatorio para despesa, etc.)
- Trigger: o trigger `trg_atualiza_saldo` ja suporta `UPDATE` — reverte o valor antigo e aplica o novo automaticamente

**Modelo Pydantic:**
```python
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
```

**Endpoint:**
```python
@router.put("/{transacao_id}")
def editar_transacao(transacao_id: str, payload: TransacaoUpdate):
    db = get_supabase()
    data = {k: v for k, v in payload.model_dump().items() if v is not None}
    if 'envelope_id' in data:
        data['envelope_id'] = str(data['envelope_id'])
    result = db.table("transacoes").update(data).eq("id", transacao_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Transacao nao encontrada")
    return result.data[0]
```

**Flutter — Tela de edicao:**
- No `ExtratoScreen`, ao tocar na transacao, abrir `EditTransacaoSheet`
- Campos pre-preenchidos com valores atuais
- Botao "Salvar" executa `PUT`

### 2. Editar Envelope

**Backend — `PUT /envelopes/{id}`**
```
PUT /envelopes/{id}
Body: {"nome_envelope": "...", "valor_planejado": 900, "emoji": "...", "cor": "..."}
```

- Editar `nome_envelope`, `valor_planejado`, `emoji`, `cor`
- NAO editar `saldo_atual` (calculado por triggers)
- Validacao: `valor_planejado > 0`, `nome_envelope` obrigatorio

**Flutter:**
- No `EnvelopeDetailSheet`, adicionar botao "Editar"
- Abre `FormEnvelopeSheet` pre-preenchido (reutilizar tela de criacao)

### 3. Editar Gasto Fixo

**Backend — `PUT /fixos/{id}`**
```
PUT /fixos/{id}
Body: {"nome": "Internet Fibra", "valor": 150.00}
```

- Campos editaveis: `nome`, `valor`
- Se `pago = true` e o valor mudou, recalcular a diferenca no `saldo_geral`

**Flutter:**
- No `FixosScreen`, ao tocar no item, abrir `FormFixoSheet` pre-preenchido

### 4. Deletar Envelope

**Backend — `DELETE /envelopes/{id}`**
- Verificar se envelope tem transacoes vinculadas
- Se sim: retornar 409 Conflict com mensagem "Envelope possui X transacoes"
- Se nao: deletar

---

## Criterios de Aceite

- [ ] `PUT /transacoes/{id}` atualiza valor e trigger recalcula saldo automaticamente
- [ ] `PUT /envelopes/{id}` atualiza nome/valor planejado sem afetar saldo_atual
- [ ] `PUT /fixos/{id}` atualiza nome/valor e ajusta saldo_geral se necessario
- [ ] `DELETE /envelopes/{id}` bloqueia se houver transacoes vinculadas
- [ ] Todas as telas de edicao pre-preenchem os campos atuais
- [ ] Nenhum calculo de saldo e feito fora do trigger

---

## Arquivos Afetados

| Arquivo | Alteracao |
|---------|-----------|
| `envelope-api/routes/transacoes.py` | Adicionar `PUT /{id}` |
| `envelope-api/routes/envelopes.py` | Adicionar `PUT /{id}`, `DELETE /{id}` |
| `envelope-api/routes/fixos.py` | Expandir `PATCH` para aceitar nome/valor |
| `envelope-api/models.py` | Adicionar `TransacaoUpdate`, `EnvelopeUpdate` |
| `envelope-flutter/lib/screens/extrato_screen.dart` | Adicionar tap → edit sheet |
| `envelope-flutter/lib/screens/envelope_detail_sheet.dart` | Adicionar botao editar |
| `envelope-flutter/lib/screens/fixos_screen.dart` | Adicionar tap → edit |
| `envelope-flutter/lib/screens/form_envelope_sheet.dart` | Aceitar modo edicao |
| `envelope-flutter/lib/screens/form_fixo_sheet.dart` | Aceitar modo edicao |
| Nova: `envelope-flutter/lib/screens/edit_transacao_sheet.dart` | Tela de edicao |
