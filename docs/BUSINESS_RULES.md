# BUSINESS_RULES.md — Regras de Negócio (Nosso Bolso)

> Fonte de verdade para o comportamento do sistema.
> Última atualização: 2026-07-19

---

## Financeiro

### RN01 — Saldo é lei do trigger
`saldo_geral.valor_total_disponivel` e `envelopes.saldo_atual` NUNCA são
calculados em código (Python/Dart). Só o trigger `trg_atualiza_saldo` em
`transacoes` altera saldos. Ver `docs/DATABASE.md`.

### RN02 — Tipos de transação
- `receita` → soma em `saldo_geral`. `envelope_id` deve ser **NULL**.
- `abastecimento` → subtrai de `saldo_geral`, soma em `envelopes.saldo_atual`.
- `despesa` → subtrai de `envelopes.saldo_atual`.
- Todo valor é positivo. Toda transação exige `usuario_id`.

### RN03 — Saldo negativo é válido
`saldo_atual < 0` é estado permitido (não bloquear). Pintar de `#8B0000` no app.

### RN04 — Gastos fixos
- Ficam em `gastos_fixos`, **fora** da tabela `transacoes`.
- Marcar como **pago SUBTRAI** do `saldo_geral` (via lógica no `routes/fixos.py`,
  ajustando `saldo_geral`); desmarcar reverte. Alterar o valor de um fixo já pago
  ajusta o delta no `saldo_geral`.
- `recorrente = true` replica o fixo nos meses seguintes.

### RN05 — Abastecimento (distribuição)
Retira do `saldo_geral` e adiciona ao `saldo_atual` de um envelope, via
transação tipo `abastecimento` (trigger faz o movimento).

### RN06 — Cores do envelope (pct = saldo_atual / valor_planejado)
`>50%` verde `#4CAF50` · `20–50%` laranja `#FF9800` · `0–20%` vermelho `#EF4444`
· `<0` vermelho escuro `#8B0000`.

---

## Compras (IA / NFC-e / Notificações)

### RN07 — Compra não é despesa até confirmar
Compra escaneada (NFC-e) ou capturada por notificação entra no MongoDB com
`status_integracao: pendente`. Só vira `despesa` no Supabase após o usuário
confirmar no app ("Compras IA").

### RN08 — Valor da nota, não soma dos itens
A despesa registrada usa o `valor_total` da nota fiscal, não a soma dos itens
(evita discrepância de arredondamento).

### RN09 — Captura por notificação: roteamento por tipo
- **Pix recebido** → lança `receita` direto no Supabase. NÃO vira compra pendente.
- **Compra / Pix enviado** → compra pendente de envelope (gasto).
- Deduplicação em 2 camadas: app ignora texto repetido por 5min; backend rejeita
  compra idêntica (família+estabelecimento+valor+dia) nos últimos 10min.

### RN10 — Enriquecimento por cupom
Uma compra pendente sem itens (vinda de notificação) pode ser enriquecida
escaneando a NFC-e: o botão "Tenho o cupom" vincula os itens àquela compra
(via `compra_id`) em vez de criar uma nova.

### RN11 — Categoria só do enum
Itens de compra usam `CategoriaItem` (enum fixo). Categoria fora do enum é
rejeitada na validação. Dados do MongoDB nunca calculam saldo.

---

## Jejum / Bem-estar

### RN12 — Sem dinheiro no jejum
Nenhum dado financeiro aparece dentro do módulo Jejum. Filosofia de
autoestima/bem-estar.

### RN13 — Linguagem positiva
Interrupção de jejum é "dia de descanso", nunca "falha/quebra". Só marcos
positivos do parceiro são compartilhados no Fast Together — interrupções,
humor e reflexões são privados.

### RN14 — Streak e jokers
`sequencia_atual`/`recorde_sequencia` só mudam via trigger `trg_sequencia_jejum`:
- completo ou joker → +1 (joker consome 1 joker do mês)
- interrompido → zera
Máximo de 1 jejum `em_andamento` por usuário. Máx 2 notificações Fast
Together/dia por par.

### RN15 — Unicórnios do jejum
Só Sweet e Happy no contexto de jejum/bem-estar. Astrix e Geronimo ficam fora.

---

## Usuários / Família

### RN16 — Isolamento multi-tenant
Toda leitura/escrita filtra por `familia_id`. RLS no Supabase; o backend usa
service role (bypassa RLS) e portanto DEVE filtrar manualmente sempre.
`usuario_id` é obrigatório em toda transação.
