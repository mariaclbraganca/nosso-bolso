Este documento define os roteiros de teste obrigatórios para validar a integridade do Nosso Bolso v2. O agente deve seguir cada caso de teste (TC) na ordem descrita.



Configuração Inicial

Ambiente: Flutter Web.



URL Base: http://localhost:64664/.



Ação Pré-Teste: Limpar o console do navegador e verificar se o redirecionamento indevido foi neutralizado no main.dart.



TC-01: Registro de Receita (Fluxo de Entrada)

Ação: Abrir o formulário "Recebi", selecionar um usuário (Aruã, Alan ou Alanna) e inserir um valor (ex: R$ 1.000,00).



Expectativa Visual: O formulário deve ter a cor verde (#4CAF50) e não permitir a seleção de envelopes.



Expectativa Técnica: \* O envelope\_id enviado no POST deve ser NULL.



O saldo\_geral no topo da Dashboard deve aumentar instantaneamente via Realtime.



Falha: Se o saldo não subir, audite a função fn\_atualiza\_saldo\_envelope no bloco tipo = 'receita'.



TC-02: Abastecimento de Envelope (Regra Crítica de Débito)

Ação: Após a receita, clicar em "Sim, Distribuir" e mover R$ 200,00 para um envelope vazio.



Expectativa Técnica:



A transação deve ter o tipo: 'abastecimento'.



O saldo\_atual do envelope deve subir para R$ 200,00.



CRÍTICO: O saldo\_geral deve diminuir exatamente R$ 200,00.



Falha: Se o saldo geral não diminuir, corrija o trigger no bloco tipo = 'abastecimento' (deve haver um UPDATE no saldo\_geral).



TC-03: Registro de Despesa (Gasto Variável)

Ação: Selecionar um envelope abastecido, clicar em "Gastei" e inserir R$ 50,00.



Expectativa Visual: A cor do envelope deve atualizar para Verde, Laranja ou Vermelho baseada na regra de %.



Expectativa Técnica: O valor deve ser subtraído do saldo\_atual do envelope através do Trigger SQL.



Falha: Se o valor não mudar, verifique se o Flutter está usando .stream() no envelopesProvider.



TC-04: Gastos Fixos (Checklist Informativo)

Ação: Ir para a tela de Fixos e marcar uma conta como "Paga".



Expectativa: O ícone deve mudar para "✅" e o label para "Pago", mas nenhum saldo (geral ou envelope) deve sofrer alteração.



Falha: Se algum saldo mudar, remova a lógica de trigger desta tabela.



TC-05: Estorno de Transação (Exclusão)

Ação: Ir para o Extrato, localizar o gasto de R$ 50,00 e realizar o "Swipe to Delete".



Expectativa: O saldo do envelope deve retornar ao valor original (R$ 200,00) automaticamente pelo trigger ON DELETE.



Auditoria de Fidelidade UI (Cores e Comportamentos)

FAB: O botão "+" deve rotacionar 45° e abrir as opções "Gastei" (Vermelho #EF4444) e "Recebi" (Verde #4CAF50).



Negativos: Se um envelope for forçado a ficar negativo (ex: gasto de R$ 300 num saldo de R$ 200), a cor deve ser obrigatoriamente Vermelho Escuro (#8B0000).

