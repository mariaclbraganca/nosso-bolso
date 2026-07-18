# DATABASE.md — Nosso Bolso
> Documento único e autoritativo sobre toda a camada de dados do sistema.
> Última atualização: 2026-07-18

---

## Sumário
1. [Visão Geral](#visão-geral)
2. [Supabase — PostgreSQL](#supabase--postgresql)
   - [DER — Diagrama Entidade-Relacionamento](#der--diagrama-entidade-relacionamento)
   - [Tabelas](#tabelas)
   - [Triggers e Funções](#triggers-e-funções)
   - [RLS — Row Level Security](#rls--row-level-security)
   - [Índices](#índices)
3. [MongoDB — IA Compras](#mongodb--ia-compras)
   - [Coleções](#coleções)
   - [Regras de Negócio](#regras-de-negócio)
   - [Fluxo de vida de uma compra](#fluxo-de-vida-de-uma-compra)
4. [Integração entre os bancos](#integração-entre-os-bancos)
5. [Alertas e pontos de atenção](#alertas-e-pontos-de-atenção)

---

## Visão Geral

O sistema usa **dois bancos de dados complementares**:

| Banco | Serviço | Responsabilidade |
|---|---|---|
| **PostgreSQL** | Supabase (cloud) | Dados financeiros estruturados: famílias, envelopes, transações, saldos |
| **MongoDB** | Atlas (cloud) | IA de compras: notas fiscais, itens, dicionário de produtos, perfil familiar |

Os dois bancos se conectam pelo campo `familia_id` (UUID) e por `transacao_supabase_id` (quando uma compra do MongoDB é confirmada e gera uma transação no Supabase).

---

## Supabase — PostgreSQL

### DER — Diagrama Entidade-Relacionamento

```
┌─────────────────┐         ┌──────────────────┐
│    familias     │         │    usuarios       │
│─────────────────│         │──────────────────│
│ id (PK)         │◄────────│ id (PK)          │
│ nome            │         │ nome             │
│ codigo_acesso   │         │ email (UNIQUE)   │
│ created_at      │         │ familia_id (FK)  │
└────────┬────────┘         │ role             │
         │                  │ fcm_token        │
         │                  │ created_at       │
         │                  └──────────────────┘
         │
         ├──────────────────────────────────────────┐
         │                                          │
         ▼                                          ▼
┌─────────────────┐                    ┌────────────────────┐
│   envelopes     │                    │  familia_usuarios  │
│─────────────────│                    │────────────────────│
│ id (PK)         │                    │ id (PK)            │
│ familia_id (FK) │                    │ familia_id (FK)    │
│ nome_envelope   │                    │ usuario_id (FK)    │
│ valor_planejado │                    │ role               │
│ saldo_atual     │                    │ created_at         │
│ emoji / cor     │                    └────────────────────┘
│ is_reserva      │
│ visivel_admin   │
│ deleted_at      │◄──────────────────────────────────────────┐
└────────┬────────┘                                           │
         │                                                    │
         ▼                                                    │
┌─────────────────────┐        ┌───────────────────────┐     │
│     transacoes      │        │   remanejamentos_log  │     │
│─────────────────────│        │───────────────────────│     │
│ id (PK)             │        │ id (PK)               │     │
│ familia_id (FK)     │        │ familia_id (FK)       │     │
│ envelope_id (FK)────┼───────►│ origem_id (FK)────────┼─────┘
│ usuario_id (FK)     │        │ destino_id (FK)───────┼─────┐
│ tipo                │        │ valor                 │     │
│ valor               │        │ usuario_id (FK)       │     │
│ data                │        │ criado_em             │     │
│ descricao           │        └───────────────────────┘     │
│ comprovante_url     │                                       │
│ visivel_admin       │◄──────────────────────────────────────┘
│ deleted_at          │
└─────────────────────┘

┌──────────────────┐        ┌─────────────────────┐
│   saldo_geral    │        │    gastos_fixos      │
│──────────────────│        │─────────────────────│
│ id (PK)          │        │ id (PK)             │
│ familia_id (FK)  │        │ familia_id (FK)     │
│ valor_total_disp │        │ nome                │
│ atualizado_em    │        │ valor               │
└──────────────────┘        │ pago (bool)         │
                            │ mes (YYYY-MM)       │
                            │ recorrente (bool)   │
                            │ dia_vencimento      │
                            │ deleted_at          │
                            └─────────────────────┘

┌────────────────────────┐     ┌──────────────────────────┐
│   contas_patrimonio    │     │   snapshots_patrimonio   │
│────────────────────────│     │──────────────────────────│
│ id (PK)                │◄────│ id (PK)                  │
│ familia_id (FK)        │     │ conta_id (FK)            │
│ nome / banco           │     │ familia_id (FK)          │
│ tipo                   │     │ mes (YYYY-MM)            │
│ saldo_atual            │     │ saldo                    │
│ rendimento_mensal      │     │ created_at               │
│ meta_saldo             │     └──────────────────────────┘
│ cor / emoji            │
└────────────────────────┘

┌───────────────────────┐     ┌─────────────────────┐
│  historico_envelopes  │     │      convites        │
│───────────────────────│     │─────────────────────│
│ id (PK)               │     │ id (PK)             │
│ envelope_id (FK)      │     │ familia_id (FK)     │
│ familia_id (FK)       │     │ token (UNIQUE)      │
│ mes (YYYY-MM)         │     │ usado (bool)        │
│ total_abastecido      │     │ created_at          │
│ total_gasto           │     └─────────────────────┘
│ saldo_fechamento      │
└───────────────────────┘

┌───────────────────────┐
│   configuracoes_app   │
│───────────────────────│
│ chave (PK)            │
│ valor                 │
│ familia_id            │
│ gemini_api_key        │
│ gemini_key_2/3        │
│ updated_at            │
└───────────────────────┘
```

---

### Tabelas

#### `familias`
Representa um grupo familiar. Ponto central do modelo multi-tenant.

| Coluna | Tipo | Obrigatório | Padrão | Descrição |
|---|---|---|---|---|
| `id` | uuid | ✅ | `uuid_generate_v4()` | PK |
| `nome` | text | ✅ | — | Nome da família |
| `codigo_acesso` | text | — | gerado por trigger | Código único para convite |
| `created_at` | timestamptz | — | `now()` | — |

**Regra de negócio:** ao inserir uma família, dois triggers disparam automaticamente — um gera o `codigo_acesso` e outro (`trg_init_family`) cria o registro em `saldo_geral` zerado para essa família.

---

#### `usuarios`
Perfil de cada membro. Espelha `auth.users` do Supabase Auth.

| Coluna | Tipo | Obrigatório | Padrão | Descrição |
|---|---|---|---|---|
| `id` | uuid | ✅ | `uuid_generate_v4()` | PK — mesmo UUID do Auth |
| `nome` | text | ✅ | — | — |
| `email` | text | ✅ | — | UNIQUE |
| `familia_id` | uuid | — | — | FK → `familias.id` |
| `role` | text | — | `'membro'` | `'admin'` ou `'membro'` |
| `fcm_token` | text | — | — | Token para push notifications |
| `created_at` | timestamptz | — | `now()` | — |

---

#### `envelopes`
Categorias de orçamento da família (ex: Mercado, Lazer, Saúde).

| Coluna | Tipo | Obrigatório | Padrão | Descrição |
|---|---|---|---|---|
| `id` | uuid | ✅ | `uuid_generate_v4()` | PK |
| `familia_id` | uuid | — | — | FK → `familias.id` |
| `nome_envelope` | text | ✅ | — | — |
| `valor_planejado` | numeric | — | `0` | Meta mensal |
| `saldo_atual` | numeric | — | `0` | Atualizado automaticamente por trigger |
| `emoji` | text | — | `'📦'` | — |
| `cor` | text | — | `'#4CAF50'` | — |
| `is_reserva` | boolean | — | `false` | Envelope de reserva de emergência |
| `visivel_apenas_admin` | boolean | ✅ | `false` | Oculto para membros não-admin |
| `deleted_at` | timestamptz | — | `null` | Soft delete |
| `valor_objetivo` | numeric | — | — | Meta total (para reservas) |

---

#### `transacoes`
Toda movimentação financeira do sistema. O trigger `trg_atualiza_saldo` reage a INSERT/UPDATE/DELETE aqui.

| Coluna | Tipo | Obrigatório | Padrão | Descrição |
|---|---|---|---|---|
| `id` | uuid | ✅ | `uuid_generate_v4()` | PK |
| `familia_id` | uuid | — | — | FK → `familias.id` |
| `envelope_id` | uuid | — | — | FK → `envelopes.id` (null para receitas) |
| `usuario_id` | uuid | — | — | FK → `usuarios.id` |
| `tipo` | text | ✅ | — | `'receita'`, `'despesa'` ou `'abastecimento'` |
| `valor` | numeric | ✅ | — | Sempre positivo |
| `data` | date | ✅ | `CURRENT_DATE` | — |
| `descricao` | text | — | — | — |
| `comprovante_url` | text | — | — | URL do comprovante no Storage |
| `visivel_apenas_admin` | boolean | ✅ | `false` | — |
| `deleted_at` | timestamptz | — | `null` | Soft delete |

**Regra de negócio dos tipos:**
- `receita` → soma em `saldo_geral.valor_total_disponivel`
- `abastecimento` → subtrai de `saldo_geral` e soma em `envelopes.saldo_atual`
- `despesa` → subtrai de `envelopes.saldo_atual`

---

#### `saldo_geral`
Uma linha por família. Representa o dinheiro recebido ainda não distribuído nos envelopes.

| Coluna | Tipo | Descrição |
|---|---|---|
| `id` | uuid | PK |
| `familia_id` | uuid | FK → `familias.id` (UNIQUE) |
| `valor_total_disponivel` | numeric | Saldo fora dos envelopes |
| `atualizado_em` | timestamptz | — |

**Regra:** `valor_total_disponivel = Σ receitas − Σ abastecimentos`. Nunca editado diretamente — sempre via trigger.

---

#### `gastos_fixos`
Contas fixas mensais (aluguel, internet, etc.).

| Coluna | Tipo | Descrição |
|---|---|---|
| `id` | uuid | PK |
| `familia_id` | uuid | FK → `familias.id` |
| `nome` | text | — |
| `valor` | numeric | — |
| `pago` | boolean | `false` = pendente |
| `mes` | text | Formato `YYYY-MM` |
| `recorrente` | boolean | Se replica todo mês |
| `dia_vencimento` | integer | Dia do mês |
| `deleted_at` | timestamptz | Soft delete |

---

#### `historico_envelopes`
Snapshot de fechamento mensal por envelope. Gerado no fim de cada mês.

| Coluna | Tipo | Descrição |
|---|---|---|
| `envelope_id` | uuid | FK → `envelopes.id` |
| `familia_id` | uuid | FK → `familias.id` |
| `mes` | text | `YYYY-MM` |
| `total_abastecido` | numeric | — |
| `total_gasto` | numeric | — |
| `saldo_fechamento` | numeric | Saldo no último dia do mês |

---

#### `remanejamentos_log`
Auditoria de transferências entre envelopes.

| Coluna | Tipo | Descrição |
|---|---|---|
| `origem_id` | uuid | FK → `envelopes.id` |
| `destino_id` | uuid | FK → `envelopes.id` |
| `valor` | numeric | — |
| `usuario_id` | uuid | Quem fez o remanejamento |
| `criado_em` | timestamptz | — |

---

#### `contas_patrimonio`
Contas bancárias e investimentos da família.

| Coluna | Tipo | Descrição |
|---|---|---|
| `tipo` | text | `conta_corrente`, `poupanca`, `investimento`, etc. |
| `saldo_atual` | numeric | Atualizado manualmente |
| `rendimento_mensal` | numeric | % de rendimento |
| `meta_saldo` | numeric | Objetivo de saldo |

---

#### `snapshots_patrimonio`
Histórico mensal de cada conta de patrimônio (uma linha por conta por mês).

---

#### `convites`
Tokens de convite para novos membros entrarem na família.

---

#### `configuracoes_app`
Chave-valor global. Guarda chaves de API do Gemini por família.

---

### Triggers e Funções

#### `trg_atualiza_saldo` → `fn_atualiza_saldo_v3()`
**Tabela:** `transacoes` | **Eventos:** INSERT, UPDATE, DELETE BEFORE

Lógica central do sistema financeiro:

```
INSERT receita      → saldo_geral += valor
INSERT abastecimento → saldo_geral -= valor; envelope.saldo_atual += valor
INSERT despesa      → envelope.saldo_atual -= valor

DELETE receita      → saldo_geral -= valor
DELETE abastecimento → saldo_geral += valor; envelope.saldo_atual -= valor
DELETE despesa      → envelope.saldo_atual += valor

UPDATE              → reverte o OLD e aplica o NEW
```

---

#### `trg_generate_code` → `fn_generate_access_code()`
**Tabela:** `familias` | **Evento:** INSERT BEFORE

Gera um `codigo_acesso` único alfanumérico de 6 caracteres.

---

#### `trg_init_family` → `fn_init_family_data()`
**Tabela:** `familias` | **Evento:** INSERT AFTER

Cria automaticamente o registro em `saldo_geral` com `valor_total_disponivel = 0` para a nova família.

---

#### `trg_atualiza_saldo_fixo` → `fn_atualiza_saldo_fixo()`
**Tabela:** `gastos_fixos` | **Evento:** UPDATE AFTER

Quando um fixo é marcado como `pago = true`, debita o valor do saldo correspondente.

---

#### `trg_deleta_saldo_fixo` → `fn_deleta_saldo_fixo()`
**Tabela:** `gastos_fixos` | **Evento:** DELETE AFTER

Reverte o impacto no saldo ao excluir um gasto fixo.

---

#### `trg_valida_fixo_invariante` → `fn_valida_fixo_invariante()`
**Tabela:** `gastos_fixos` | **Evento:** INSERT/UPDATE BEFORE

Valida invariantes de negócio antes de gravar (ex: impede inconsistências de estado).

---

### RLS — Row Level Security

**Padrão geral:** usuário só acessa dados da própria família via:
```sql
familia_id IN (SELECT familia_id FROM usuarios WHERE id = auth.uid())
```

Todas as tabelas têm RLS habilitado. Nenhuma política com `qual = true` existe — acesso anônimo bloqueado em toda a base.

| Tabela | Políticas ativas |
|---|---|
| `envelopes` | ALL por família (EXISTS usuarios) + INSERT com `with_check` |
| `transacoes` | ALL por família (EXISTS usuarios) + INSERT com `with_check` |
| `gastos_fixos` | ALL por família (EXISTS usuarios) |
| `saldo_geral` | ALL por família (EXISTS usuarios) |
| `configuracoes_app` | SELECT por família autenticada (ou `familia_id IS NULL` para configs globais) |
| `usuarios` | SELECT próprio perfil + membros da mesma família; UPDATE próprio perfil |
| `familias` | SELECT própria família; INSERT apenas autenticado |
| `historico_envelopes` | ALL por família |
| `remanejamentos_log` | ALL por família |
| `contas_patrimonio` | ALL por família |
| `snapshots_patrimonio` | ALL por família (via `familia_usuarios`) |

---

### Índices

| Índice | Tabela | Tipo | Propósito |
|---|---|---|---|
| `envelopes_pkey` | `envelopes` | UNIQUE btree | PK |
| `transacoes_pkey` | `transacoes` | UNIQUE btree | PK |
| `saldo_geral_familia_id_key` | `saldo_geral` | UNIQUE btree | Garante 1 registro por família |
| `familias_codigo_acesso_key` | `familias` | UNIQUE btree | Unicidade do código de convite |
| `ix_remanejamentos_familia` | `remanejamentos_log` | btree | Consulta por família + data desc |
| `snapshots_patrimonio_conta_id_mes_idx` | `snapshots_patrimonio` | UNIQUE btree | 1 snapshot por conta por mês |

---

## MongoDB — IA Compras

**Banco:** `envelope_ia`
**Coleções:** `compras`, `perfis_familia`, `dicionario_produtos`

---

### Coleções

#### `compras`
Armazena notas fiscais processadas e compras capturadas por notificação.

```json
{
  "compra_id": "uuid-v4",
  "familia_id": "uuid-da-familia",
  "data_compra": "2026-07-18T00:00:00",
  "supermercado": "Supermercado X",
  "valor_total": 183.68,
  "qr_code_url": "https://...",
  "fonte": "nfce | ifood | nubank",
  "status_integracao": "pendente | confirmado | cancelado | falhou",
  "transacao_supabase_id": "uuid | null",
  "llm_provider": "gemini | gemini_mobile",
  "created_at": "2026-07-18T...",
  "itens": [
    {
      "nome_original": "PEITO FRANGO KG",
      "nome_padronizado": "Peito de Frango",
      "produto_ref_id": "objectid-do-dicionario",
      "categoria": "Proteínas",
      "quantidade": 1.5,
      "unidade": "kg",
      "valor_unitario": 14.90,
      "valor_total_item": 22.35,
      "status_consumo": "ativo | consumido | vencido",
      "data_feedback_estimada": "2026-07-25T..."
    }
  ]
}
```

**Valores de `fonte`:**
- `nfce` — escaneada pelo app via QR Code da nota fiscal
- `ifood` — capturada via notificação do iFood Benefícios
- `nubank` — capturada via notificação do Nubank (Pix/compra)

**Valores de `status_integracao`:**
- `pendente` — aguardando confirmação do usuário no app
- `confirmado` — usuário aprovou; transação criada no Supabase
- `cancelado` — usuário recusou
- `falhou` — erro na extração pelo Gemini

**Categorias de item (enum fixo):**
`Proteínas`, `Carboidratos`, `Hortifrúti`, `Laticínios`, `Padaria`, `Bebidas`, `Lanches`, `Temperos e Condimentos`, `Limpeza`, `Higiene Pessoal`, `Congelados`, `Grãos e Cereais`, `Outros`

---

#### `dicionario_produtos`
Dicionário de produtos por família. Aprende com cada compra processada.

```json
{
  "_id": "ObjectId",
  "familia_id": "uuid-da-familia",
  "nome_canonico": "Peito de Frango",
  "categoria": "Proteínas",
  "sinonimos_llm": ["PEITO FRANGO KG", "FR PEITO FRANGO", "Peit Frango"],
  "preco_medio": 14.90,
  "unidade_padrao": "kg",
  "created_at": "2026-07-18T..."
}
```

**Regra de negócio:** ao processar cada item de uma nota, o sistema busca no dicionário da família por `nome_canonico`. Se encontrar, atualiza o preço médio (média simples) e adiciona o nome original como sinônimo. Se não encontrar, cria um novo registro.

---

#### `perfis_familia`
Perfil de comportamento de compras da família. Usado pela IA para personalizar sugestões.

```json
{
  "familia_id": "uuid-da-familia",
  "nome_familia": "Família Silva",
  "num_membros": 4,
  "cesta_basica_inegociavel": ["Ovos", "Arroz", "Feijão", "Leite"],
  "restricoes_alimentares": ["sem glúten"],
  "regras_financeiras": {
    "limite_mensal": 1200.0,
    "percentual_proteina": 0.30,
    "priorizar_oferta": true
  },
  "envelope_supermercado_id": "uuid-do-envelope-mercado | null"
}
```

**Campo crítico:** `envelope_supermercado_id` — armazena qual envelope Supabase corresponde ao mercado da família. Usado para verificar saldo disponível antes de sugerir compras.

---

### Regras de Negócio

#### Extração de NFC-e
1. App escaneia QR Code da nota → raspa HTML da SEFAZ (feito no dispositivo, pois o Render tem IP bloqueado pela SEFAZ-GO)
2. HTML enviado ao backend → Gemini extrai itens em JSON estruturado
3. **Source grounding**: itens cujo nome não aparece no texto da nota são removidos (anti-alucinação)
4. **Sanity check de valor**: se o valor extraído pelo Gemini divergir > R$0,50 do valor parseado diretamente no HTML, usa o valor do HTML
5. Resultado salvo como `status_integracao: pendente`
6. Usuário confirma no app → cria transação no Supabase + atualiza `status_integracao: confirmado`

#### Captura por Notificação
1. `NotificationListenerService` captura notificações do Nubank (`com.nu.production`) e iFood
2. Regex extrai valor e estabelecimento do texto
3. Fallback para Gemini se regex falhar
4. POST para `/api/v1/compras/notificacao-nubank` ou `/notificacao-ifood`
5. Salvo como `status_integracao: pendente` com `itens: []`
6. Aparece em "Compras IA" para o usuário categorizar

#### Feedback de Consumo
- Cada item tem `data_feedback_estimada` calculada por `shelf_life` segundo a categoria
- Quando a data vence e `status_consumo == 'ativo'`, o item aparece para feedback
- Usuário marca como `consumido` ou `vencido`

#### Pressão Orçamentária
- Se `saldo_atual < 50%` do esperado proporcional ao dia do mês → IA ativa modo de economia (evita sugerir proteínas premium)

---

### Fluxo de vida de uma compra

```
[NFC-e / Notificação]
        │
        ▼
  MongoDB: compras
  status_integracao = "pendente"
  itens = [...] ou []
        │
        │ Usuário confirma no app
        ▼
  POST /api/v1/compras/confirmar
        │
        ├──► Supabase: INSERT transacoes
        │    tipo = "despesa"
        │    envelope_id = envelope_supermercado_id
        │
        └──► MongoDB: compras
             status_integracao = "confirmado"
             transacao_supabase_id = <uuid>
```

---

## Integração entre os bancos

| Campo | De | Para | Propósito |
|---|---|---|---|
| `familia_id` (UUID) | Supabase `familias.id` | MongoDB todos os docs | Isolamento multi-tenant |
| `transacao_supabase_id` | Supabase `transacoes.id` | MongoDB `compras` | Rastrear qual compra gerou qual transação |
| `envelope_supermercado_id` | Supabase `envelopes.id` | MongoDB `perfis_familia` | IA sabe qual envelope debitar ao confirmar compra |
| `produto_ref_id` | MongoDB `dicionario_produtos._id` | MongoDB `compras.itens` | Referência cruzada dentro do próprio Mongo |

---

## Invariantes e boas práticas

- `saldo_geral.valor_total_disponivel` nunca deve ser editado diretamente — sempre via trigger em `transacoes`
- MongoDB `compras`: índice composto `idx_compras_familia_status` em `{ familia_id, status_integracao }` — criado
