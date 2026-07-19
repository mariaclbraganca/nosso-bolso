# PROMPT MESTRE — TESTE END-TO-END COMPLETO
## App: Nosso Bolso (Envelope Financial App)

---

Você é um agente de QA sênior. Sua missão é testar **todas as funcionalidades** do app "Nosso Bolso" de ponta a ponta, simulando o comportamento real de dois usuários de uma mesma família. Execute cada item na ordem abaixo, registre o resultado (✅ PASS / ❌ FAIL / ⚠️ PARCIAL), e ao final produza um relatório consolidado.

---

## CONTEXTO DO SISTEMA

- **Backend:** FastAPI + Supabase (Python)
- **Frontend:** Flutter (mobile/web)
- **DB:** PostgreSQL com triggers automáticos de saldo
- **Regra central:** Saldo é calculado EXCLUSIVAMENTE por triggers no banco. Nunca por código Python ou Dart.
- **Tipos de transação:** `receita` (entrada), `despesa` (gasto), `abastecimento` (mover saldo para envelope)

---

## PARTE 1 — AUTENTICAÇÃO E ONBOARDING

### 1.1 Cadastro de novo usuário
- Acessar tela de registro (`SignupScreen`)
- Cadastrar usuário A: nome, email válido, senha (mínimo 6 chars)
- Verificar: conta criada no Supabase Auth, perfil criado em `usuarios`
- Verificar: redirecionado para `OnboardingScreen`

### 1.2 Criação de família
- Na `OnboardingScreen`, criar família com nome (ex: "Família Silva")
- Verificar: registro criado em `familias`
- Verificar: `usuarios.familia_id` associado
- Verificar: `saldo_geral` inicializado com valor 0 para a família

### 1.3 Convite para segundo usuário
- Gerar código/link de convite para a família
- Verificar: registro criado em `convites` com token único

### 1.4 Cadastro e ingresso do usuário B
- Abrir app como novo usuário (usuário B)
- Cadastrar com email diferente
- Usar o código de convite para ingressar na família
- Verificar: `usuarios_b.familia_id` = mesma família do usuário A

### 1.5 Login com Google OAuth
- Testar fluxo de login via Google Sign-In
- Verificar: token Supabase válido retornado
- Verificar: usuário criado/vinculado corretamente

### 1.6 Login com email/senha existente
- Fazer logout do usuário A
- Fazer login novamente com email/senha
- Verificar: sessão restaurada, família carregada corretamente

---

## PARTE 2 — CRIAÇÃO DE ENVELOPES

### 2.1 Criar envelope básico
- Usuário A: abrir FAB → "Novo Envelope" (`FormEnvelopeSheet`)
- Preencher: nome="Mercado", valor planejado=R$800,00, cor/ícone
- Verificar: envelope aparece no `DashboardScreen` com saldo=0

### 2.2 Criar múltiplos envelopes
- Criar mais 3 envelopes: "Transporte" (R$300), "Lazer" (R$200), "Saúde" (R$500)
- Verificar: todos listados no grid do dashboard
- Verificar: saldo_planejado correto em cada um

### 2.3 Validação de campos obrigatórios
- Tentar criar envelope SEM nome → verificar erro de validação
- Tentar criar envelope SEM valor planejado → verificar erro
- Tentar criar envelope com valor negativo → verificar bloqueio

---

## PARTE 3 — REGISTRO DE RECEITA (ENTRADA)

### 3.1 Registrar receita pelo usuário A
- FAB → "Recebi" (`FormReceitaScreen`)
- Valor: R$3.000,00, descrição: "Salário Abril", usuário: A
- Verificar: transação tipo `receita` criada em `transacoes`
- Verificar: `saldo_geral` aumentou R$3.000,00 (trigger automático)
- Verificar: NÃO tem `envelope_id` (rule: RECEITA_NO_ENVELOPE)

### 3.2 Registrar receita pelo usuário B
- Usuário B registra receita: R$2.000,00, "Salário B"
- Verificar: `saldo_geral` agora = R$5.000,00
- Verificar: ambas as receitas aparecem no `ExtratoScreen` aba "Entradas"

### 3.3 Validação de receita
- Tentar registrar receita com valor 0 → verificar bloqueio
- Tentar registrar sem selecionar usuário → verificar erro (USER_REQUIRED)

---

## PARTE 4 — ABASTECIMENTO DE ENVELOPES

### 4.1 Abastecer envelope (fluxo básico)
- No dashboard, tocar no envelope "Mercado" → `EnvelopeDetailSheet`
- Tocar em "Abastecer" → `AbastecerSheet`
- Transferir R$800,00 do saldo geral para "Mercado"
- Verificar: `saldo_geral` diminuiu R$800,00
- Verificar: envelope "Mercado" saldo = R$800,00
- Verificar: transação tipo `abastecimento` criada

### 4.2 Abastecer múltiplos envelopes
- Abastecer "Transporte" com R$300,00
- Abastecer "Lazer" com R$200,00
- Abastecer "Saúde" com R$500,00
- Verificar: `saldo_geral` = R$5.000 - R$800 - R$300 - R$200 - R$500 = R$3.200,00
- Verificar: cada envelope com saldo correto

### 4.3 Tentar abastecer mais do que o saldo disponível
- Tentar transferir R$10.000,00 (maior que saldo_geral)
- Verificar: comportamento (bloqueio ou saldo negativo — conforme regra NEGATIVE_OK)

---

## PARTE 5 — REGISTRO DE GASTOS (DESPESAS)

### 5.1 Registrar despesa (fluxo de 4 etapas)
- FAB → "Gastei" (`FormGastoSheet`)
- **Passo 1:** Valor = R$120,00
- **Passo 2:** Selecionar envelope "Mercado"
- **Passo 3:** Descrição = "Compras semana 1"
- **Passo 4:** Selecionar usuário A → Confirmar
- Verificar: transação `despesa` criada
- Verificar: envelope "Mercado" saldo = R$800 - R$120 = R$680,00

### 5.2 Múltiplos gastos em diferentes envelopes
- Despesa R$50,00 em "Transporte" (usuário B) → "Uber"
- Despesa R$80,00 em "Lazer" (usuário A) → "Cinema"
- Despesa R$200,00 em "Mercado" (usuário B) → "Feira"
- Verificar saldos: Mercado=R$480, Transporte=R$250, Lazer=R$120

### 5.3 Gasto que leva envelope a saldo baixo (Warning States)
- Registrar R$400,00 em "Mercado" → saldo = R$80 (< 20% de R$800)
- Verificar: envelope muda para cor **vermelha** no grid
- Verificar: alerta aparece no `AlertBanner` do dashboard

### 5.4 Gasto que leva envelope a saldo negativo
- Registrar R$100,00 em "Lazer" com saldo disponível R$120
- Registrar mais R$150,00 em "Lazer" → saldo = -R$30
- Verificar: envelope fica **dark red** (#8B0000)
- Verificar: transação NÃO é bloqueada (NEGATIVE_OK)

### 5.5 Validação de despesa
- Tentar registrar sem selecionar envelope → erro
- Tentar registrar sem usuário → erro (USER_REQUIRED)
- Tentar registrar com valor negativo → erro

---

## PARTE 6 — EXTRATO (HISTÓRICO)

### 6.1 Visualizar extrato completo
- Navegar para aba "Extrato" (`ExtratoScreen`)
- Verificar: todas as transações aparecem na aba correta (Gastos / Entradas)
- Verificar: cada item mostra valor, descrição, data, usuário, envelope

### 6.2 Filtrar por usuário
- Filtrar extrato pelo usuário A → só aparecem transações do usuário A
- Filtrar pelo usuário B → só aparecem transações do usuário B
- Limpar filtro → todos aparecem

### 6.3 Filtrar por tipo
- Filtrar tipo `despesa` → só gastos
- Filtrar tipo `receita` → só entradas

### 6.4 Filtrar por envelope
- Filtrar pelo envelope "Mercado" → só transações do Mercado

### 6.5 Paginação
- Verificar que paginação funciona (page/limit) quando há mais de 30 registros

---

## PARTE 7 — EXCLUSÃO DE TRANSAÇÕES (UNDO)

### 7.1 Excluir despesa
- No extrato, selecionar a despesa de R$50 "Uber" (usuário B)
- Confirmar exclusão
- Verificar: transação removida do extrato
- Verificar: envelope "Transporte" saldo voltou para R$300 (trigger reversal)

### 7.2 Excluir receita
- Excluir receita de R$2.000 do usuário B
- Verificar: `saldo_geral` diminuiu R$2.000

### 7.3 Excluir abastecimento
- Excluir abastecimento de R$200 do envelope "Lazer"
- Verificar: `saldo_geral` aumentou R$200
- Verificar: envelope "Lazer" saldo diminuiu R$200

---

## PARTE 8 — GASTOS FIXOS

### 8.1 Criar gasto fixo
- Navegar para aba "Fixos" (`FixosScreen`)
- FAB → `FormFixoSheet`
- Criar: "Internet" R$120,00, vencimento dia 5
- Criar: "Aluguel" R$1.500,00, vencimento dia 10
- Verificar: ambos aparecem na lista de fixos
- Verificar: NÃO afetam `saldo_geral` ou envelopes (FIXOS_SEM_TRIGGER)

### 8.2 Marcar fixo como pago (toggle)
- Marcar "Internet" como pago (PATCH `/fixos/{id}`)
- Verificar: status muda para pago na UI
- Verificar: badge/indicador visual alterado

### 8.3 Desmarcar fixo (toggle inverso)
- Desmarcar "Internet" → volta para pendente
- Verificar: estado revertido

### 8.4 Filtrar fixos por mês
- Verificar que fixos do mês atual aparecem
- Trocar seletor de mês → verificar que lista filtra corretamente

### 8.5 Excluir gasto fixo
- Excluir "Aluguel"
- Verificar: removido da lista, saldos não afetados

---

## PARTE 9 — DASHBOARD

### 9.1 Cards de resumo
- Verificar `TotalBalanceCard`: saldo_geral correto
- Verificar `RevenueSummaryCard`: total entradas do mês correto
- Verificar total de gastos do mês correto

### 9.2 Grid de envelopes
- Verificar todos os envelopes listados com saldos corretos
- Verificar cores corretas por status de saúde:
  - Verde: > 50% do planejado
  - Laranja: 20–50%
  - Vermelho: 0–20%
  - Dark red: negativo

### 9.3 SpendingVelocityCard
- Verificar cálculo de velocidade de gastos (ritmo do mês)

### 9.4 EnvelopeHealthSummary
- Verificar contagem de envelopes por status

### 9.5 AlertBanner
- Verificar aparece quando há envelopes críticos
- Verificar desaparece quando situação normaliza

### 9.6 Seletor de mês
- Trocar para mês anterior → dashboard filtra corretamente
- Voltar para mês atual → dados corretos

---

## PARTE 10 — RELATÓRIOS

### 10.1 Gráfico de pizza (envelope)
- Navegar para `RelatoriosScreen`
- Verificar `EnvelopePieChartCard`: fatias proporcionais aos gastos por envelope

### 10.2 Gráfico de barras por usuário
- Verificar `UserSpendingBars`: barras comparativas usuário A vs B

### 10.3 Budget vs Real
- Verificar `BudgetComparisonChart`: planejado vs gasto por envelope

### 10.4 Tendência de gastos
- Verificar `SpendingTrendChart`: evolução ao longo dos dias do mês

### 10.5 Top 5 gastos
- Verificar `TopExpensesCard`: 5 maiores despesas listadas corretamente

### 10.6 StatCardRow
- Verificar estatísticas resumidas (média diária, maior gasto, etc.)

### 10.7 Filtro por usuário nos relatórios
- Filtrar relatório por usuário A → gráficos refletem apenas dados do A

---

## PARTE 11 — SINCRONIZAÇÃO REAL-TIME

### 11.1 Sync entre dispositivos
- Usuário A registra despesa em um dispositivo
- Verificar: usuário B vê o update em tempo real (< 2 segundos)
- Verificar: saldo no dashboard do B atualiza sem precisar recarregar

### 11.2 Sync de abastecimento
- Usuário B abastece envelope
- Verificar: saldo_geral do usuário A atualiza em tempo real

### 11.3 Reconexão após offline
- Simular perda de conexão (modo avião)
- Registrar transação (se possível offline)
- Reconectar → verificar sincronização

---

## PARTE 12 — API DIRETA (BACKEND)

### 12.1 Health check
```
GET /
Esperado: {"status":"ok","version":"2.0"}
```

### 12.2 Listar envelopes
```
GET /envelopes/
Esperado: array de envelopes com saldos corretos
```

### 12.3 Criar transação via API
```
POST /transacoes/
Body: {"tipo":"despesa","valor":50,"envelope_id":"<uuid>","usuario_id":"<uuid>","descricao":"Teste API","familia_id":"<uuid>"}
Esperado: 201 Created, saldo do envelope atualizado
```

### 12.4 Extrato com filtros via API
```
GET /transacoes/extrato?tipo=despesa&mes=2026-04&page=1&limit=10
Esperado: lista paginada filtrada
```

### 12.5 Stats do dashboard via API
```
GET /dashboard/stats?mes=2026-04
Esperado: totais de receita, despesa, por usuário
```

### 12.6 Listar fixos por mês
```
GET /fixos/?mes=2026-04
Esperado: lista de gastos fixos do mês
```

### 12.7 Validação de campos obrigatórios
```
POST /transacoes/ sem usuario_id
Esperado: 422 Unprocessable Entity
```

### 12.8 Deletar transação inexistente
```
DELETE /transacoes/uuid-inexistente
Esperado: 404 Not Found
```

---

## PARTE 13 — ISOLAMENTO MULTI-FAMÍLIA (SaaS RLS)

### 13.1 Isolamento de dados entre famílias
- Criar segunda família (Família 2) com usuário C
- Verificar: usuário C NÃO vê envelopes/transações da Família 1
- Verificar: RLS bloqueia queries cruzadas

### 13.2 Tentativa de acesso indevido
- Tentar `GET /envelopes/` com token de usuário C → deve retornar apenas envelopes da Família 2
- Verificar: nenhum dado da Família 1 vazou

---

## PARTE 14 — EDGE CASES E RESILIÊNCIA

### 14.1 Saldo geral negativo
- Registrar receita R$100, abastecer R$100, depois excluir a receita
- Verificar comportamento com saldo_geral negativo

### 14.2 Transações no limite de meses
- Registrar transação no último dia do mês às 23:59
- Verificar: aparece no mês correto no dashboard e extrato

### 14.3 Valores muito pequenos
- Registrar despesa de R$0,01 → deve funcionar

### 14.4 Valores muito grandes
- Registrar receita de R$999.999,99 → verificar sem overflow

### 14.5 Caracteres especiais em descrição
- Descrição com emojis, acentos, aspas → verificar sem quebrar

### 14.6 Campos em branco opcionais
- Registrar despesa sem descrição (se campo opcional) → deve funcionar

---

## PARTE 15 — PERFORMANCE E UX

### 15.1 Tempo de carregamento inicial
- Verificar: dashboard carrega em < 3 segundos na primeira abertura

### 15.2 Scroll suave no extrato
- Scroll rápido por 100+ transações → sem janks ou travamentos

### 15.3 FAB Speed Dial
- Abrir FAB → 3 opções aparecem com animação
- Fechar sem selecionar → fecha corretamente
- Abrir em todas as abas → funciona em todas

### 15.4 Sheets modais
- Abrir e fechar `FormGastoSheet` sem preencher → não salva nada
- Preencher parcialmente → ao fechar, confirmar descarte

---

## RELATÓRIO FINAL

Ao concluir todos os testes, gere um relatório no seguinte formato:

```
## RELATÓRIO DE TESTES — [DATA]

### RESUMO
- Total de testes: XX
- ✅ PASS: XX
- ❌ FAIL: XX  
- ⚠️ PARCIAL: XX
- Taxa de sucesso: XX%

### FALHAS CRÍTICAS
[Lista de falhas que bloqueiam uso do app]

### FALHAS MENORES
[Lista de bugs que não bloqueiam uso]

### OBSERVAÇÕES
[Comportamentos inesperados, inconsistências de UX, sugestões]

### PRÓXIMOS PASSOS
[O que precisa ser corrigido antes de liberar para produção]
```

---

## NOTAS DE EXECUÇÃO

- **Ordem importa:** Execute na sequência numérica — os testes posteriores dependem de dados criados nos anteriores.
- **Estado entre partes:** Não limpe o banco entre partes (exceto na Parte 13 que testa isolamento).
- **Regra de ouro:** Se um saldo não bater, o problema está no trigger ou na ordem de execução — nunca calcule manualmente no código.
- **Usuário obrigatório:** Toda transação DEVE ter `usuario_id`. Qualquer transação sem usuário indica bug grave.
- **Fixos são informativos:** `gastos_fixos` NUNCA devem alterar `saldo_geral` ou envelopes — se alterarem, é bug crítico.
