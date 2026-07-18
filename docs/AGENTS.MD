\# AGENTS.md — Regras de Ouro



\## Regras Absolutas (Nunca Viole)

\- \*\*TRIGGER\_IS\_LAW\*\*: Nunca calcule saldo em Python ou Dart. Insira apenas em `transacoes`. O trigger PostgreSQL é a única fonte de verdade para saldos.

\- \*\*NO\_GOD\_FILES\*\*: Nenhum arquivo deve exceder 200 linhas. Se chegar a 180, quebre em um novo módulo ou sub-widget.

\- \*\*REALTIME\_ONLY\*\*: Nunca use `setState` para atualizar saldos. Use `StreamProvider` com `.stream()` do Supabase para refletir mudanças em tempo real.

\- \*\*RECEITA\_NO\_ENVELOPE\*\*: Transações do tipo `receita` devem ter `envelope\_id = NULL`. Validação obrigatória no Pydantic e constraint no banco.

\- \*\*FIXOS\_SEM\_TRIGGER\*\*: Gastos fixos não passam pela tabela `transacoes`. São gerenciados na tabela `gastos\_fixos` e não afetam o saldo automático via trigger.



\## Constantes de Cor (UI/UX)

\- \*\*Positivo (>50%)\*\*: Verde (#4CAF50).

\- \*\*Alerta (20-50%)\*\*: Laranja (#FF9800).

\- \*\*Crítico (0-20%)\*\*: Vermelho (#EF4444).

\- \*\*Negativo (<0)\*\*: Vermelho Escuro (#8B0000).



\## Anti-patterns Proibidos

\- Nunca fazer `saldo = saldo - valor` no código.

\- Nunca inserir gastos fixos na tabela de `transacoes`.

\- Nunca permitir transação sem `usuario\_id`.

