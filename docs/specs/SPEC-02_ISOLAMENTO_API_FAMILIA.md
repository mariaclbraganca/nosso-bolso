# SPEC-02 — Isolamento da API por Familia

**Prioridade:** Critica (Imediato)
**Esforco:** Baixo
**Status:** Planejado

---

## Problema

Todos os endpoints de leitura (`GET /envelopes/`, `GET /transacoes/extrato`, etc.) retornam dados de **todas** as familias. O backend usa a service role key do Supabase, que bypassa RLS. Qualquer chamada a API pode acessar dados de familias alheias.

## Solucao

Adicionar `familia_id` como parametro obrigatorio em todos os endpoints de leitura e como filtro implicito em todos os endpoints de escrita.

### Endpoints a corrigir

| Endpoint | Correcao |
|----------|----------|
| `GET /envelopes/` | Adicionar `?familia_id=` obrigatorio |
| `POST /envelopes/` | Incluir `familia_id` no insert |
| `GET /transacoes/extrato` | Adicionar `?familia_id=` obrigatorio |
| `GET /fixos/` | Adicionar `?familia_id=` obrigatorio |
| `POST /fixos/` | Incluir `familia_id` no insert |
| `GET /dashboard/stats` | Ja corrigido (recebe `familia_id`) |

### Exemplo — `GET /envelopes/`

**Antes:**
```python
@router.get("/")
def listar_envelopes():
    db = get_supabase()
    return db.table("envelopes").select("*").execute().data
```

**Depois:**
```python
@router.get("/")
def listar_envelopes(familia_id: str):
    db = get_supabase()
    return db.table("envelopes").select("*").eq("familia_id", familia_id).execute().data
```

### Fase 2 (futuro): Autenticacao JWT

Trocar `?familia_id=` por autenticacao real:
1. Flutter envia token JWT do Supabase no header `Authorization: Bearer <token>`
2. Backend valida o token e extrai `user_id`
3. Backend busca `familia_id` do usuario no banco
4. Todas as queries filtram por essa familia

Isso elimina o risco de um usuario passar `familia_id` de outra familia na URL.

---

## Criterios de Aceite

- [ ] Todos os endpoints de leitura exigem `familia_id`
- [ ] `GET /envelopes/` sem `familia_id` retorna 422
- [ ] Nenhum dado de outra familia aparece nas respostas
- [ ] Flutter passa `familia_id` em todas as chamadas HTTP

---

## Arquivos Afetados

| Arquivo | Alteracao |
|---------|-----------|
| `envelope-api/routes/envelopes.py` | Adicionar param `familia_id` no GET e POST |
| `envelope-api/routes/transacoes.py` | Adicionar param `familia_id` no extrato |
| `envelope-api/routes/fixos.py` | Adicionar param `familia_id` no GET e POST |
| `envelope-flutter/lib/providers/*.dart` | Incluir `familia_id` nas chamadas HTTP |
