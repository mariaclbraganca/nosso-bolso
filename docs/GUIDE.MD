\# GUIDE.md — Roadmap de Desenvolvimento 



\## Fase 1: Fundação do Banco de Dados

\- \[ ] Executar SQL v2 (tabelas: usuarios, envelopes, transacoes, saldo\_geral, gastos\_fixos).

\- \[ ] Implementar Trigger v2 (incluindo lógica de adição de saldo via receita).

\- \[ ] Habilitar Realtime nas 4 tabelas principais.



\## Fase 2: Backend \& API

\- \[ ] Criar rotas para Receitas (`POST /transacoes` com tipo=receita).

\- \[ ] Criar rotas para Gastos Fixos (`GET /fixos` e `PATCH /fixos/{id}`).

\- \[ ] Atualizar endpoint de Stats para refletir o saldo geral e gastos por usuário.



\## Fase 3: Interface Flutter 

\- \[ ] Implementar `SpeedDialFAB` (Botão + que vira X e abre opções).

\- \[ ] Criar `FormReceitaScreen` (obrigatório `envelope\_id = null`).

\- \[ ] Criar tela de `GastosFixosScreen` com toggle de pago/pendente.

\- \[ ] Atualizar `ExtratoScreen` com abas para filtrar Despesas e Receitas.



\## Fase 4: Fluxos de UX

\- \[ ] Implementar diálogo pós-receita: "Deseja distribuir nos envelopes agora?".

\- \[ ] Validar estorno de gastos (Swipe to Delete) em tempo real.

