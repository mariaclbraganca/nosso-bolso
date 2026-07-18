\# UI\_SPEC.md — Especificações de Design v2



\## Paleta de Cores (Hex)

\- \*\*Fundo\*\*: #0B0E09

\- \*\*Cards\*\*: #1A1E15

\- \*\*Destaque (Acento)\*\*: #8DC65B

\- \*\*Texto Primário\*\*: #E4EAD8

\- \*\*Texto Secundário\*\*: #6A7460



\## Componentes Chave

\- \*\*Speed Dial FAB\*\*: 

&#x20; - Ícone "+" rotaciona 45 graus ao abrir.

&#x20; - Opção "Gastei": Vermelho (#EF4444).

&#x20; - Opção "Recebi": Verde (#4CAF50).

\- \*\*Envelope Cards\*\*: 

&#x20; - Barra de progresso horizontal.

&#x20; - Altura do card fixa para manter o grid simétrico.

\- \*\*Saldo Geral\*\*: Exibido em destaque no topo com fonte de tamanho 32pt.



\## Transições

\- Uso de `AnimatedContainer` para expansão das opções do FAB.

\- Modais (`BottomSheet`) devem abrir com 0.3s de duração.

