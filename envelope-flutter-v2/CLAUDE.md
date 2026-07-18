# Nosso Bolso v2 — CLAUDE.md

Redesign completo do app financeiro familiar. Este projeto é o front novo — o backend (`envelope-api`) é compartilhado com o v1 e não deve ser modificado aqui.

## Stack
- Flutter + Riverpod (estado)
- Supabase (auth + banco)
- Google Fonts (Inter)
- fl_chart (gráficos)
- mobile_scanner (NFC-e)

## Arquitetura de pastas

```
lib/
├── main.dart
├── constants.dart          ← URLs, chaves, supabase client
├── theme/
│   ├── app_theme.dart      ← AppColors, AppTheme, AppTextStyles
│   └── app_spacing.dart    ← constantes de espaçamento
├── providers/              ← copiados do v1, sem alteração
├── services/               ← copiados do v1, sem alteração
├── widgets/
│   ├── unicorn/            ← sistema de unicórnios animados
│   │   ├── unicorn_bubble.dart
│   │   ├── unicorn_celebration.dart
│   │   ├── unicorn_loading.dart
│   │   └── unicorn_empty.dart
│   └── shared/             ← componentes reutilizáveis do design system
└── screens/
    ├── main_navigation_screen.dart
    ├── home/
    ├── extrato/
    ├── planos/
    └── minha_vida/
```

## Design System

### Cores (AppColors)
```dart
bg     = #080A06   // fundo principal
surf   = #111408   // superfície, bottom nav
card   = #181C12   // cards
bord   = #1E2419   // bordas
acc    = #9ED465   // verde primário
gold   = #F5C542   // dourado premium
tx     = #EFF5E1   // texto principal
mu     = #5A6450   // texto secundário
grn    = #4CAF50   // sucesso
red    = #EF4444   // erro
org    = #FF9800   // atenção
```

### Tipografia (AppTextStyles)
```dart
display  // 32px Bold    — saldos principais
title    // 20px SemiBold — títulos de seção
body     // 15px Regular  — conteúdo
caption  // 11px Medium   — labels e badges
mono     // 18px Bold     — valores monetários (tabular nums)
```

### Espaçamentos (AppSpacing)
```dart
pagePadding = 20.0   // padding horizontal de telas
cardGap     = 12.0   // gap entre cards
sectionGap  = 24.0   // gap entre seções
```

### Border radius
- Cards: 16px
- Botões: 12px
- Chips/badges: 20px
- Inputs: 12px

## Navegação

Bottom nav com 4 abas — SEM Hub intermediário:
1. **Home** — Dashboard com envelopes + unicórnio grande
2. **Extrato** — Transações + Relatórios
3. **Planos** — Fixos / Metas / Contas (switcher, não tabs)
4. **Minha Vida** — Saúde + Exercício unificados

FAB central com 3 ações apenas:
- Gastei (primário)
- Recebi (secundário)
- Compras IA (com badge de pendentes)

## Unicórnios

4 personagens, cada um com papel definido:
- **Astrix** — guia financeiro (Dashboard, insights)
- **Sweet** — celebrações (metas batidas, conquistas)
- **Happy** — motivação (sequências, progresso)
- **Geronimo** — alertas (envelopes negativos, vencimentos)

Regras obrigatórias:
- Sempre animados — nunca estáticos
- Bubble persistente em todas as telas principais (mín. 80px)
- Destaque em empty states (mín. 160px, centralizado)
- Substituem spinners de loading
- Celebração com partículas ao bater metas

## Regras de código

- NUNCA usar cores hardcoded — sempre `AppColors.*`
- NUNCA usar Scaffold dentro de TabBarView
- NUNCA usar AppBar dentro de filho de IndexedStack
- Padding horizontal sempre 20px
- Todo valor monetário usa `AppTextStyles.mono`
- Widgets invisíveis (opacity 0) SEMPRE com `IgnorePointer`
- FABs dentro de Stack SEMPRE com `heroTag` único

## Skills disponíveis

- `/design-review` — avaliação completa de tela (antes de commitar)
- `/ui-check` — verificação rápida de erros óbvios
- `/new-screen` — template para criar nova tela
- `/unicorn-check` — verificar presença e animação dos unicórnios
- `/screen-flow` — mapear e validar fluxo de navegação
- `/ds-token` — verificar conformidade com design system
- `/v2-status` — progresso geral do redesign
- `/code-review` — revisão de código
- `/verify` — verificar que o app está rodando
- `/simplify` — limpar código após implementar módulo
- `/run` — rodar o app e tirar screenshot

## Workflow por tela

1. Implementar a tela
2. `/ui-check` — erros rápidos
3. `/unicorn-check` — unicórnios OK?
4. `/ds-token` — conformidade com design system
5. `/run` — visual aprovado?
6. `/design-review` — aprovação final
7. Commit

## Backend

Mesmo backend do v1 — `envelope-api` no Render.
Copiar `lib/services/` e `lib/providers/` do v1 sem modificação.
Copiar `lib/constants.dart` do v1.
