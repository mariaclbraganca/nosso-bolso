# Nosso Bolso v2 — CLAUDE.md

App financeiro familiar (redesign v2, `envelope-flutter-v2`). Além das finanças
(envelopes, transações, fixos, metas), integra três módulos de bem-estar em
**Minha Vida**: Saúde, Exercício e Jejum.

O backend `envelope-api` (FastAPI + Supabase + MongoDB) é **compartilhado** e
**pode ser modificado** quando a feature exigir — vários módulos foram criados/
alterados aqui (jejum, IA de compras, notificações). Não é mais read-only.

## Stack

**Mobile** (`envelope-flutter-v2`)
- Flutter + Riverpod ^2.5 (estado)
- supabase_flutter ^2.5 (auth + banco + realtime)
- flutter_local_notifications ^17.2 (notificações locais + agendamento)
- flutter_notification_listener ^1.4 (captura de notificações Nubank/iFood)
- fl_chart (gráficos) · mobile_scanner (NFC-e) · sentry_flutter ^8.9 (erros)
- Google Fonts (Inter)

**Backend** (`envelope-api`, FastAPI no Render)
- Supabase (Postgres) — dados financeiros + jejum (jejum_config, jejum_registros,
  jejum_together) + saúde
- MongoDB — compras extraídas de NFC-e/notificações
- Google Gemini — extração de NFC-e, insights de saúde/jejum
- Módulos: `routes/` (financeiro), `ia_compras/`, `ia_saude/`
  (router_saude, router_exercicio, router_jejum), `ia_financeiro/`

## Arquitetura de pastas (mobile)

```
lib/
├── main.dart · constants.dart (URLs, chaves, supabase client, sentryDsn)
├── theme/           ← app_theme.dart (AppColors, AppTextStyles), app_spacing.dart
├── providers/       ← Riverpod (jejum_provider, saude_provider, compras_provider…)
├── services/        ← API + integrações (jejum_api_service, jejum_notification_service,
│                       nubank/ifood_notification_service, active_notifications_service…)
├── widgets/unicorn/ ← sistema de unicórnios animados (unicorn_system.dart)
└── screens/
    ├── main_navigation_screen.dart  ← bottom nav + FAB + popup de compras pendentes
    ├── home/ · extrato/ · planos/ · compras/
    └── minha_vida/
        ├── minha_vida_screen.dart   ← 3 segmentos: Saúde · Exercício · Jejum
        ├── saude/  · exercicio/  · jejum/
```

## Design System

### Cores (AppColors) — NUNCA hardcodar, sempre `AppColors.*`
```
bg #080A06 · surf #111408 · card #181C12 · bord #1E2419
acc #9ED465 (verde primário) · gold #F5C542 · tx #EFF5E1 · mu #5A6450
grn #4CAF50 (sucesso) · red #EF4444 (erro) · org #FF9800 (atenção)
blu #60A5FA · pur #A78BFA (usados nos módulos de bem-estar)
```

### Tipografia (AppTextStyles)
`display` 32px · `title` 20px · `body` 15px · `caption` 11px · `mono` (valores $, tabular)

### Espaçamento (AppSpacing) · Radius
pagePad 20 · cardGap 12 · sectionGap 24 · cards 16 · botões 12 · chips 20 · inputs 12

## Navegação

Bottom nav — 4 abas, SEM Hub intermediário:
1. **Home** — dashboard com envelopes + chip de jejum ativo + unicórnio
2. **Extrato** — transações + relatórios
3. **Planos** — Fixos / Metas / Contas (switcher)
4. **Minha Vida** — **3 segmentos grandes lado a lado**: 🌿 Saúde · 💪 Exercício · ⏱ Jejum
   (cada um é filho do IndexedStack em `minha_vida_screen.dart`; Jejum NÃO é aba da Saúde)

FAB central com 3 ações: Gastei · Recebi · Compras IA (badge de pendentes).

## Módulo Jejum (`screens/minha_vida/jejum/`)

3º segmento de Minha Vida. Abas internas: Hoje · Histórico · Insights · Configurar.
- Filosofia: bem-estar/psicológico, autoestima. **Nenhum dado financeiro aparece
  dentro do jejum** — dinheiro faz a pessoa se sentir mal.
- Linguagem sempre positiva: interrupção é "dia de descanso", nunca "falha/quebra".
- **Unicórnios: SÓ Sweet e Happy no contexto de jejum/bem-estar.** Astrix e Geronimo
  ficam FORA do jejum (mesmo onde o artefato os mostrava, usar Happy).
- Notificações de marco (12h/16h/hidratação/janela) via agendamento local;
  Fast Together via FCM. Ver [[jejum-e-terceiro-segmento-minha-vida]] na memória.

## Unicórnios

4 personagens: **Astrix** (guia financeiro), **Sweet** (celebrações), **Happy**
(motivação), **Geronimo** (alertas). No módulo Jejum/bem-estar, só Sweet e Happy.
Regras: sempre animados · bubble persistente nas telas principais (mín. 80px) ·
destaque em empty states (mín. 160px) · substituem spinners · celebração com partículas.

## Captura de notificações (Nubank / iFood)

`ifood_notification_service` é o listener central → roteia para Nubank/iFood.
- **Android 14+**: o `NotificationsHandlerService` no manifest EXIGE
  `foregroundServiceType="specialUse"` + `<property PROPERTY_SPECIAL_USE_FGS_SUBTYPE>`
  + permissões FOREGROUND_SERVICE(_SPECIAL_USE). Sem isso o listener não inicia.
- Usuário precisa conceder "Acesso a notificações" manualmente (o app não auto-concede).
- Roteamento por tipo: **pix_recebido → receita**; compra/pix_enviado → gasto pendente.
- Dedup em 2 camadas (app 5min + backend 10min). Ver [[captura-notificacoes-android14-fgs]].

## Regras de código

- NUNCA cores hardcoded — sempre `AppColors.*`
- NUNCA Scaffold dentro de TabBarView · NUNCA AppBar dentro de filho de IndexedStack
- Padding horizontal sempre 20px · valores monetários sempre `AppTextStyles.mono`
- Widgets invisíveis (opacity 0) SEMPRE com `IgnorePointer`
- FABs dentro de Stack SEMPRE com `heroTag` único
- Sentry: logs de sucesso são `debugPrint` local; só FALHAS reais vão ao Sentry

## Fluxo de trabalho / deploy

- Testes reais em celular físico (emulador não recebe Nubank/iFood).
  Device principal: Samsung A546E (Android 16). Também há S711B e emulador NossoBolso.
- Backend deploya no Render via push para `main` (auto-deploy, ~1-2min).
- Mudança de AndroidManifest exige rebuild completo (não hot reload).
- `flutter analyze` limpo antes de commitar. Commit só quando o usuário pede.

## Skills disponíveis

`/design-review` · `/ui-check` · `/new-screen` · `/unicorn-check` · `/screen-flow`
· `/ds-token` · `/v2-status` · `/code-review` · `/verify` · `/simplify` · `/run`
