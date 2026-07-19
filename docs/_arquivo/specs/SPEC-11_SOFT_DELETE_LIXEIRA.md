# SPEC-11 — Soft Delete com Lixeira

**Prioridade:** Media (Mes 2)
**Esforco:** Medio
**Status:** Planejado

---

## Problema

Ao deletar uma transacao, ela desaparece para sempre. Sem possibilidade de restaurar.

## Solucao

### 1. Soft delete na tabela transacoes

```sql
ALTER TABLE public.transacoes
ADD COLUMN deleted_at timestamptz DEFAULT NULL;

-- Index para performance em queries filtradas
CREATE INDEX idx_transacoes_deleted ON public.transacoes (deleted_at)
WHERE deleted_at IS NULL;
```

### 2. Comportamento

| Acao | Antes | Depois |
|------|-------|--------|
| Deletar | `DELETE FROM transacoes` | `UPDATE SET deleted_at = now()` |
| Listar | `SELECT *` | `SELECT * WHERE deleted_at IS NULL` |
| Lixeira | Nao existe | `SELECT * WHERE deleted_at IS NOT NULL` |
| Restaurar | Nao existe | `UPDATE SET deleted_at = NULL` |
| Expurge | Nao existe | `DELETE WHERE deleted_at < now() - 30 days` |

### 3. Impacto nos triggers

**Problema:** O trigger atual (`BEFORE DELETE`) reverte o saldo automaticamente. Com soft delete, nao ha DELETE real — o trigger nao dispara.

**Solucao:** Ao fazer soft delete, reverter saldo manualmente antes de marcar `deleted_at`:
```python
@router.delete("/{transacao_id}")
def deletar_transacao(transacao_id: str):
    db = get_supabase()
    # Buscar transacao
    tx = db.table("transacoes").select("*").eq("id", transacao_id).is_("deleted_at", "null").execute().data
    if not tx:
        raise HTTPException(status_code=404, detail="Transacao nao encontrada")
    tx = tx[0]

    # Reverter saldo manualmente
    if tx["tipo"] == "despesa":
        db.table("envelopes").update(...)  # +valor
    elif tx["tipo"] == "abastecimento":
        db.table("envelopes").update(...)  # -valor
        db.table("saldo_geral").update(...)  # +valor
    elif tx["tipo"] == "receita":
        db.table("saldo_geral").update(...)  # -valor

    # Soft delete
    db.table("transacoes").update({"deleted_at": "now()"}).eq("id", transacao_id).execute()
    return {"ok": True}
```

**Alternativa mais limpa:** Manter o DELETE real no trigger mas adicionar uma tabela `transacoes_lixeira` que armazena uma copia antes de deletar (via trigger BEFORE DELETE).

### 4. Endpoint de lixeira

```
GET /transacoes/lixeira?familia_id=<uuid>
POST /transacoes/{id}/restaurar
DELETE /transacoes/{id}/permanente
```

### 5. Flutter — Tela de Lixeira

- Acessivel via menu de configuracoes ou icone no extrato
- Lista transacoes deletadas com data de exclusao
- Swipe para restaurar ou deletar permanentemente
- Aviso: "Itens na lixeira sao removidos apos 30 dias"

### 6. Cron de expurge

Job diario que remove transacoes com `deleted_at` > 30 dias.

---

## Criterios de Aceite

- [ ] Deletar transacao marca `deleted_at` em vez de remover
- [ ] Transacoes deletadas nao aparecem no extrato normal
- [ ] Saldo revertido corretamente ao deletar
- [ ] Restaurar transacao re-aplica o saldo
- [ ] Expurge automatico apos 30 dias
- [ ] Tela de lixeira acessivel

---

## Arquivos Afetados

| Arquivo | Alteracao |
|---------|-----------|
| Supabase SQL | ALTER TABLE transacoes + deleted_at |
| `envelope-api/routes/transacoes.py` | Alterar DELETE, adicionar lixeira/restaurar |
| `envelope-flutter/lib/screens/extrato_screen.dart` | Filtrar deleted_at IS NULL |
| Nova: `envelope-flutter/lib/screens/lixeira_screen.dart` | Tela de lixeira |
