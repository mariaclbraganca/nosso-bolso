# SPEC-15 — Permissoes por Membro da Familia

**Prioridade:** Baixa (Mes 3)
**Esforco:** Alto
**Status:** Planejado

---

## Problema

Todos os membros da familia tem acesso total. Nao existe distinção entre quem pode criar envelopes, editar valores planejados, ou apenas registrar gastos.

## Solucao

### 1. Campo de role na tabela usuarios

```sql
ALTER TABLE public.usuarios
ADD COLUMN role text DEFAULT 'membro'
    CHECK (role IN ('admin', 'membro', 'visualizador'));
```

### 2. Niveis de permissao

| Acao | Admin | Membro | Visualizador |
|------|-------|--------|--------------|
| Ver dashboard/relatorios | Sim | Sim | Sim |
| Registrar gasto/receita | Sim | Sim | Nao |
| Criar/editar envelope | Sim | Nao | Nao |
| Criar/editar gasto fixo | Sim | Nao | Nao |
| Abastecer envelope | Sim | Sim | Nao |
| Deletar transacao | Sim | Propria | Nao |
| Convidar membros | Sim | Nao | Nao |
| Alterar permissoes | Sim | Nao | Nao |
| Exportar dados | Sim | Sim | Nao |

### 3. Enforcement

**Backend:** Middleware que verifica role antes de cada operacao:
```python
def check_role(usuario_id: str, roles_permitidos: list):
    db = get_supabase()
    user = db.table("usuarios").select("role").eq("id", usuario_id).execute().data
    if not user or user[0]["role"] not in roles_permitidos:
        raise HTTPException(status_code=403, detail="Permissao negada")
```

**Flutter:** Esconder botoes/opcoes baseado no role do usuario logado:
```dart
if (perfil.role == 'admin') ...[
    // Mostrar botao editar envelope
]
```

### 4. Tela de gerenciamento (admin only)

- Lista de membros da familia com role atual
- Dropdown para alterar role
- Opcao de remover membro

---

## Criterios de Aceite

- [ ] Criador da familia e automaticamente admin
- [ ] Membro so pode registrar transacoes e ver dados
- [ ] Visualizador so pode consultar, nao altera nada
- [ ] Admin pode alterar roles de outros membros
- [ ] UI esconde opcoes nao permitidas (nao so bloqueia no backend)

---

## Arquivos Afetados

| Arquivo | Alteracao |
|---------|-----------|
| Supabase SQL | ALTER TABLE usuarios + role |
| Todos os `envelope-api/routes/*.py` | Verificar role |
| `envelope-flutter/lib/providers/usuarios_provider.dart` | Expor role |
| Todas as telas com acoes restritas | Condicional de role |
| Nova: `envelope-flutter/lib/screens/gerenciar_familia_screen.dart` | Admin panel |
