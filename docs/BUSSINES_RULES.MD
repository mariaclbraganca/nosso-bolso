\# BUSINESS\_RULES.md — Regras de Negócio 



\## Fluxo de Receita (RN05)

\- Receitas aumentam o `saldo\_geral` na tabela `saldo\_geral`.

\- Receitas \*\*não\*\* podem ser atribuídas a um envelope no momento da entrada.

\- O campo `envelope\_id` deve ser nulo para transações do tipo 'receita'.



\## Fluxo de Gastos Fixos (RN06)

\- Gastos fixos são itens informativos (ex: Aluguel, Internet).

\- Marcar como "Pago" não subtrai do saldo dos envelopes nem do saldo geral.

\- Serve apenas para controle de checklist mensal.



\## Distribuição de Saldo (Abastecimento)

\- O "Abastecimento" retira valor do `saldo\_geral` e adiciona ao `saldo\_atual` de um envelope específico.

\- Esta operação é realizada via trigger ao inserir uma transação do tipo 'abastecimento'.



\## Regras de Usuário

\- Usuários fixos: Aruã, Alan e Alanna.

\- Toda e qualquer transação deve registrar quem a realizou (`usuario\_id` obrigatório).

