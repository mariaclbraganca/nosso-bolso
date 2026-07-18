# SPEC-08 — Metas de Economia

**Prioridade:** Media (Mes 2)
**Esforco:** Medio
**Status:** Planejado

---

## Problema

Envelopes sao para gastos mensais. Nao existe forma de rastrear objetivos de longo prazo como "Juntar R$5.000 para viagem".

## Solucao

### 1. Nova tabela: `metas`

```sql
CREATE TABLE public.metas (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome text NOT NULL,
    valor_alvo numeric(12,2) NOT NULL,
    valor_atual numeric(12,2) NOT NULL DEFAULT 0,
    emoji text DEFAULT '🎯',
    cor text DEFAULT '#60A5FA',
    prazo date,
    familia_id uuid REFERENCES familias(id) ON DELETE CASCADE,
    created_at timestamptz DEFAULT now()
);

ALTER TABLE public.metas ENABLE ROW LEVEL SECURITY;
ALTER PUBLICATION supabase_realtime ADD TABLE metas;
```

### 2. Endpoints

| Metodo | Endpoint | Descricao |
|--------|----------|-----------|
| `GET` | `/metas/?familia_id=` | Listar metas |
| `POST` | `/metas/` | Criar meta |
| `PUT` | `/metas/{id}` | Editar meta |
| `DELETE` | `/metas/{id}` | Excluir meta |
| `POST` | `/metas/{id}/contribuir` | Adicionar valor a meta |

### 3. Contribuicao a meta

**Fluxo:**
1. Usuario escolhe meta e valor
2. O valor e debitado do `saldo_geral` (como abastecimento)
3. O valor e creditado em `metas.valor_atual`
4. Registrar como transacao tipo `meta` para audit trail

**Ou, mais simples:** meta nao afeta saldo — e apenas um tracker visual. O usuario deposita em um envelope "Reserva" e marca progresso manualmente. Decisao de design.

### 4. Flutter — Tela de Metas

**`MetasScreen`** — pode ser 5a aba ou sub-tela do Dashboard:
- Lista de metas com barra de progresso circular
- Percentual: `valor_atual / valor_alvo * 100`
- Dias restantes ate o prazo
- Botao "Contribuir" em cada meta
- Status por cor:
  - Verde: on track (ritmo suficiente para atingir no prazo)
  - Amarelo: atrasado
  - Vermelho: muito atrasado

**`FormMetaSheet`:**
- Nome da meta
- Valor alvo (R$)
- Prazo (DatePicker)
- Emoji

### 5. Widget no Dashboard

Card resumo: "Suas Metas" mostrando as 3 metas mais proximas do prazo com mini barras de progresso.

---

## Criterios de Aceite

- [ ] CRUD completo de metas via API
- [ ] Barra de progresso visual com percentual
- [ ] Contribuicao debita saldo_geral (ou modo tracker manual)
- [ ] Prazo com indicador de "dias restantes"
- [ ] Card de resumo no dashboard
- [ ] Real-time via StreamProvider

---

## Arquivos Afetados

| Arquivo | Alteracao |
|---------|-----------|
| Supabase SQL | CREATE TABLE metas |
| Nova: `envelope-api/routes/metas.py` | CRUD + contribuir |
| Nova: `envelope-api/models.py` | MetaCreate, MetaUpdate |
| `envelope-api/main.py` | Registrar router metas |
| Nova: `envelope-flutter/lib/screens/metas_screen.dart` | Tela de metas |
| Nova: `envelope-flutter/lib/screens/form_meta_sheet.dart` | Criar/editar meta |
| Nova: `envelope-flutter/lib/providers/metas_provider.dart` | StreamProvider |
| Nova: `envelope-flutter/lib/widgets/dashboard/metas_summary_card.dart` | Card no dashboard |
