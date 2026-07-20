# DIAGNÓSTICO_FLUTTER.md

> Levantamento diagnóstico do `envelope-flutter-v2` (+ `envelope-api` quando relevante).
> Coletado em 2026-07-19. **Nada foi corrigido** — apenas coletado e documentado.
> Flutter analyze rodado com `--no-pub`. Projeto NÃO usa go_router/build_runner/freezed.

---

## 1. Erros de compilação/lint reais

### 1.1 `flutter analyze --no-pub`
**Resultado: 170 issues, TODOS de severidade `info` (0 errors, 0 warnings).**

Distribuição por regra:
| Regra | Ocorrências | Natureza |
|-------|-------------|----------|
| `prefer_const_constructors` | 132 | Performance (cosmético) |
| `prefer_const_literals_to_create_immutables` | 11 | Performance (cosmético) |
| `curly_braces_in_flow_control_structures` | 11 | Estilo |
| `deprecated_member_use` | 8 | **Relevante** — `Sentry.setExtra` deprecado |
| `unnecessary_brace_in_string_interps` | 4 | Estilo |
| `unnecessary_cast` | 2 | Estilo |
| `prefer_final_fields` | 1 | Estilo |
| `non_constant_identifier_names` | 1 | Estilo |

**Único ponto de atenção real:** `deprecated_member_use` — `setExtra` do Sentry está deprecado (usar Contexts). Ocorre em:
- `lib/services/active_notifications_service.dart:35`
- `lib/services/ifood_notification_service.dart:45`
- `lib/services/nubank_notification_service.dart:152, 232, 252, 286, 287`

Todo o resto é cosmético (const/chaves). **Nenhum erro que impeça compilação.**

### 1.2 `dart fix --dry-run`
**108 fixes propostos em 35 arquivos** — todos automáticos e cosméticos (majoritariamente `prefer_const_constructors`). Códigos aplicáveis:
`curly_braces_in_flow_control_structures`, `prefer_const_constructors`, `prefer_final_fields`, `unnecessary_brace_in_string_interps`, `unnecessary_cast`.
> Podem ser aplicados em bloco com `dart fix --apply` sem risco funcional.

### 1.3 `flutter pub outdated`
Dependências desatualizadas (nenhuma quebra, mas várias major atrás):

| Pacote | Atual | Resolvable | Latest | Nota |
|--------|-------|-----------|--------|------|
| flutter_riverpod | 2.6.1 | 2.6.1 | **3.3.2** | major nova (3.x muda API) |
| supabase_flutter | 2.14.1 | 2.15.4 | 2.16.0 | patch disponível |
| flutter_local_notifications | 17.2.4 | 19.5.0 | **22.1.0** | 5 majors atrás |
| sentry_flutter | 8.14.2 | 8.14.2 | **9.24.0** | trava por constraint |
| fl_chart | 0.68.0 | 0.71.0 | **1.2.0** | pré-1.0 → 1.x |
| mobile_scanner | 5.2.3 | 6.0.11 | **7.3.0** | usado no NFC-e |
| google_sign_in | 6.2.2 | 6.2.2 | **7.2.0** | major (afeta login) |
| flutter_secure_storage | 9.2.4 | 10.3.1 | 10.3.1 | usado p/ chaves Gemini |
| share_plus | 10.1.4 | 12.0.2 | 13.2.1 | |
| flutter_lints (dev) | 3.0.2 | 4.0.0 | 6.0.0 | |

**Avisos:** 9 dependências travadas em versões < resolvable; pacote `js` (transitivo) **descontinuado**.
> Nenhum conflito de versão que impeça build. Riscos de upgrade concentrados em riverpod 3.x, google_sign_in 7.x e flutter_local_notifications (majors com breaking changes).

---

## 2. Erros em runtime (captura de erros)

### 2.1 Sentry — ERROS REAIS (via API, org `estudante-w5` / projeto `flutter`, região DE)
DSN em `lib/constants.dart:7`. **15 issues nos últimos 14 dias, TODOS `fatal` e TODOS de LAYOUT/constraints** — nenhum é lógica de negócio. Todos no device **SM-A546E, Android 16, release 2.0.0+1, produção** (são os testes recentes do usuário, madrugada de 2026-07-20).

| # | Erro | Count | Categoria |
|---|------|-------|-----------|
| 1 | RenderFlex overflowed by **108px** on the right | 1 | Overflow horizontal |
| 2 | RenderFlex overflowed by **12px** on the right | 12 | Overflow horizontal |
| 3 | RenderFlex overflowed by **1.6px** on the bottom | 10 | Overflow vertical |
| 4 | RenderFlex overflowed by **18px** on the right | 10 | Overflow horizontal |
| 5-10,12-15 | AssertionError `box.dart:2165 'hasSize'` | 3-7 cada | RenderBox sem layout |
| 11 | StateError: **RenderObject does not have constraints before layout** | 7 | Constraints ausentes |

**Total de eventos:** ~90 ocorrências em 14 dias, 1 usuário (o dev).

**⚠️ LIMITAÇÃO CRÍTICA da instrumentação Sentry atual:**
- As stack traces têm **ZERO frames do app** (`APP FRAMES: 0`) — só framework Flutter (`assertions.dart`, `box.dart`, `object.dart`). O build release não envia símbolos Dart (falta `--split-debug-info` + upload de debug symbols), então **é impossível saber a linha/widget exato** a partir do Sentry.
- Os **breadcrumbs só têm lifecycle Android** (MainActivity resumed/paused) — **falta o `SentryNavigatorObserver`**, então não há rastro de qual TELA Dart estava ativa no crash.
- **Recomendação para o analista:** os erros `hasSize`/`does not have constraints` são o mesmo tipo de cascata que já causou o freeze do "confirmar compra" (DropdownButtonFormField sem `isExpanded`) — provável causa raiz: **widget de largura ilimitada dentro de Row/Flex** (Dropdown, TextField ou Text sem Expanded/Flexible). Para localizar: adicionar `SentryNavigatorObserver` + `--split-debug-info` e reproduzir.

**Pontos no código onde erros vão ao Sentry:**

**`Sentry.captureException` / `captureMessage` (9 pontos):**
| Arquivo:linha | Tipo | O que captura |
|---------------|------|---------------|
| `main.dart:55` | captureException | Erro global não tratado (runZonedGuarded) |
| `services/active_notifications_service.dart:32` | captureMessage | (aviso ao processar notificações ativas) |
| `services/active_notifications_service.dart:41` | captureException | Falha ao processar notificações ativas |
| `services/ifood_notification_service.dart:42` | captureMessage | Falta de permissão de notificação |
| `services/nubank_notification_service.dart:149` | captureMessage | (parse/processamento Nubank) |
| `services/nubank_notification_service.dart:230` | captureMessage | Session null — não inseriu |
| `services/nubank_notification_service.dart:250` | captureMessage | familia_id vazio mesmo após fallback DB |
| `services/nubank_notification_service.dart:283` | captureMessage | API retornou status != 200/201 |
| `services/nubank_notification_service.dart:302` | captureException | Erro ao criar compra pendente |

> Observação: a captura de erros do app está **concentrada em notificações** (Nubank/iFood) e no handler global. As telas comuns NÃO enviam ao Sentry — usam `catch` local silencioso.

### 2.2 `catch (e` em todo o lib/
**91 blocos catch** em 52 arquivos. Top ofensores (mais catches = mais lógica que pode falhar silenciosamente):
| Arquivo | Nº catch |
|---------|----------|
| `screens/compras/compras_ia_sheet.dart` | 6 |
| `services/gemini_monitor_service.dart` | 5 |
| `services/gemini_key_service.dart` | 5 |
| `screens/minha_vida/jejum/jejum_timer_screen.dart` | 4 |
| `services/saude_api_service.dart` | 3 |
| `services/notificacao_fila_service.dart` | 3 |
| `services/gemini_patrimonio_service.dart` | 3 |
| `services/gemini_nfce_service.dart` | 3 |
| `screens/planos/fixos_tab.dart` | 3 |
| `screens/auth/login_screen.dart` | 3 |
| ...+42 arquivos com 1-2 cada |

> **Padrão preocupante:** muitos `catch (_) {}` e `catch (e) { debugPrint(...) }` engolem o erro sem reportar. Ex.: `perfil_metabolico_view.dart:348` (`catch (_) {}` ao registrar peso). Apenas 1 `debugPrint('[erro...` explícito no lib/ inteiro — o resto é silencioso ou vira Sentry só nas notificações.

---

## 3. Navegação — mapa completo

### 3.1 Dependências de roteamento
**NÃO usa go_router, auto_route, beamer nem routemaster** (confirmado em pubspec.yaml e pubspec.lock — zero ocorrências). Navegação 100% **imperativa** (`Navigator.push`/`pop` direto).

### 3.2 Contagem global (lib/screens + lib/services)
| Método | Ocorrências |
|--------|-------------|
| `Navigator.push` / `Navigator.of(context).push` | 28 |
| `Navigator.pushReplacement(Named)` | 2 |
| `Navigator.pushNamed` | 0 |
| `Navigator.pop` | 91 |
| `showModalBottomSheet` | 41 |
| `showDialog` | 24 |

### 3.3 Infra de navegação (`lib/services/app_navigator.dart`)
- `navigatorKey` (GlobalKey<NavigatorState>) — navegar sem context (usado por notificações).
- `scaffoldMessengerKey` (GlobalKey<ScaffoldMessengerState>) — SnackBar sem context de sheet fechado.
- `_PendingNavigation` — singleton com callback registrado pelo `MainNavigationScreen` p/ trocar aba do IndexedStack (`navHome/Extrato/Planos/Vida` = 0-3).

### 3.4 ⚠️ INCONSISTÊNCIA de rotas nomeadas (relevante p/ bug de logout)
Há DOIS estilos de navegação nomeada que conflitam:
- `unicorn_splash_screen.dart:55` → `Navigator.of(context).pushReplacementNamed('/home')`
  → **remove o AuthGate da pilha de navegação.**
- `config_hub_screen.dart:296` → `pushNamedAndRemoveUntil('/gate', ...)` (logout)
  → precisou dessa rota `/gate` justamente porque o splash tirou o AuthGate.

> Este é o ponto onde o histórico de bug de logout mora. Rotas nomeadas usadas: `/home` (splash) e `/gate` (logout). Ver rotas definidas em `main.dart`.

### 3.5 Navigator.push — destinos (arquivo:linha)
```
login_screen.dart:191            → SignUpScreen
compras_ia_sheet.dart:96,734     → Navigator.push<String> (retorna URL do scanner)
compras_ia_sheet.dart:341,353    → (feedback/lista compras)
config_hub_screen.dart:97        → PerfilFamiliaScreen
config_hub_screen.dart:115       → InsightsScreen
config_hub_screen.dart:126       → ConfiguracaoIAScreen
config_hub_screen.dart:137       → NotificationSettingsScreen
config_hub_screen.dart:154       → SimuladorGastosScreen (novo)
config_hub_screen.dart:188,198   → PinScreen (fluxo)
simulador_gastos_screen.dart:141 → _DetalheSimulacaoScreen
extrato_screen.dart:153,161,713  → LixeiraScreen / ResumoMensalScreen
home_screen.dart:252             → (detalhe)
jejum_chip_home.dart:58          → JejumTimerScreen
jejum_timer_screen.dart:676      → pushReplacement (próximo jejum)
jejum_view.dart:59,472,489,573,695 → timer / fases / config
dashboard_diario_view.dart:103,684,734 → saúde
perfil_metabolico_view.dart:68,286 → saúde
patrimonio_tab.dart:66           → (detalhe patrimônio)
unicorn_splash_screen.dart:55    → pushReplacementNamed('/home')
```

### 3.6 showModalBottomSheet (41 — arquivos)
compras_ia_sheet (2), perfil_familia_screen (1), edit_transacao_sheet (2), extrato_screen (2), home_screen (3), main_navigation_screen (3), exercicio_view (1), jejum_config_sheet (2), jejum_insights_view (1), jejum_onboarding_screen (1), jejum_timer_screen (3), jejum_view (3), minha_vida_screen (1), dashboard_diario_view (1), saude_view (1), contas_tab (1), fixos_tab (1), form_fixo_sheet (1), metas_tab (2), patrimonio_tab (3), envelope_detail_sheet (4), form_envelope_sheet (1), form_receita_sheet (1).

### 3.7 showDialog (24 — arquivos)
onboarding_screen (2), compras_ia_sheet (2), config_hub_screen (1), perfil_familia_screen (1), simulador_gastos_screen (3), extrato_screen (1), lixeira_screen (1), main_navigation_screen (1), jejum_timer_screen (3), perfil_metabolico_view (1), contas_tab (1), fixos_tab (1), form_fixo_sheet (1), patrimonio_tab (1), envelope_detail_sheet (1), form_envelope_sheet (2), form_receita_sheet (1).

### 3.8 async + context/Navigator após await SEM mounted
- **47 arquivos** em `lib/screens/` usam `await`.
- **154 checagens** `mounted`/`context.mounted` espalhadas — cobertura alta.
- **Único arquivo suspeito** (usa context/Navigator + await, ZERO `mounted` no arquivo):
  `lib/screens/minha_vida/saude/perfil_metabolico_view.dart`
  - **FALSO-POSITIVO verificado:** em `_registrarPeso` (linha 337), o `Navigator.pop(context)` acontece **ANTES** do `await SaudeApiService.registrarPeso` (linha 340). Depois do await só há `ref.invalidate` (seguro, não usa context). Portanto **não é bug real** — mas é o único ponto sem guarda de mounted, vale revisar se evoluir.

> Conclusão: cobertura de `mounted` é boa no projeto. Não há uso perigoso de context após await sem checagem detectado.

---

## 4. Estado global e ciclo de vida

### 4.1 ⚠️ `UnicornSplashScreen._shown` (static bool) NUNCA é resetado
```dart
// lib/screens/unicorn_splash_screen.dart
static bool _shown = false;              // linha 7
static bool get hasShown => _shown;      // linha 8
...
UnicornSplashScreen._shown = true;       // linha 37 — ÚNICO ponto que altera
```
- Setado para `true` uma vez; **nunca volta a `false`**.
- O `signOut` (ver 4.3) **não** reseta.
- Consumido em `main.dart:96` (`if (!UnicornSplashScreen.hasShown)`).
- **Impacto:** ao deslogar e logar de novo SEM matar o app, o splash do unicórnio não reaparece (fica "já mostrado" em RAM). Some só ao reiniciar o app.

### 4.2 Outros `static bool` / singletons (ciclo de vida)
| Local | Flag | Resetado no logout? |
|-------|------|--------------------|
| `unicorn_splash_screen.dart:7` | `_shown` | ❌ Não |
| `services/ifood_notification_service.dart:20` | `_iniciado` | ❌ Não |
| `services/jejum_notification_service.dart:21` | `_inicializado` | ❌ Não |
| `services/notification_service.dart:22` | `_initialized` | ❌ Não |
| `services/app_navigator.dart` | `_PendingNavigation._instance` | ❌ Não |
> Nenhum desses é resetado no logout. Em geral inofensivo (re-init idempotente), mas o `_shown` do splash é o de impacto visível.

### 4.3 Método de logout completo (`signOut`)
```dart
// lib/providers/auth_provider.dart
Future<void> signOut() async {
  await GeminiKeyService.limparCacheLocal();      // limpa chaves Gemini (secure storage)
  try { if (!kIsWeb) await GoogleSignIn().signOut(); } catch (_) {}
  await _supabase.auth.signOut();
}
```
No ponto de chamada (`config_hub_screen.dart`):
```dart
await ref.read(authServiceProvider).signOut();
ref.read(pinNotifierProvider.notifier).bloquear();       // reseta sessão PIN
ref.invalidate(perfilUsuarioLogadoProvider);             // AuthGate reavalia
Navigator.of(context).pushNamedAndRemoveUntil('/gate', (route) => false);
```
**O que o logout reseta hoje:** chaves Gemini (secure storage) ✅ · Google sign-in ✅ · sessão Supabase ✅ · sessão PIN ✅ · cache do perfil ✅.
**O que NÃO reseta:** `UnicornSplashScreen._shown` ❌ · flags `_iniciado`/`_inicializado` dos serviços de notificação ❌.

### 4.4 invalidate/refresh no fluxo login/logout
- `config_hub_screen.dart:306` → `ref.invalidate(perfilUsuarioLogadoProvider)` (logout)
- `main.dart:125` → `ref.invalidate(perfilUsuarioLogadoProvider)` (retry no AuthGate)
> Só o `perfilUsuarioLogadoProvider` é invalidado. Providers de dados (envelopes, saldo, jejum) dependem de auto-dispose/rebuild pela cadeia de `perfilUsuarioLogadoProvider`.

### 4.5 `sugestaoJantarProvider` — CÓDIGO MORTO
- **Definido:** `lib/providers/saude_provider.dart:36` (`FutureProvider.autoDispose`).
- **Consumido:** em **NENHUM lugar** (única ocorrência no lib/ inteiro é a própria definição).
> É código morto — nenhuma tela faz `ref.watch(sugestaoJantarProvider)`. Candidato a remoção. (Existe uma tela `sugestao_jantar_screen.dart` mas ela não consome este provider.)

---

## 5. Arquivos fora do escopo do repomix

### 5.1 `.g.dart` / `.freezed.dart`
**NENHUM arquivo gerado existe.** O projeto **não usa** `build_runner`, `freezed` nem `json_serializable` (confirmado em pubspec.yaml — zero dependências desse tipo).
> **Implicação para análise:** toda serialização é manual (`Map<String, dynamic>` + `fromJson`/`toJson` escritos à mão). Não há equals/hashCode gerado, nem código escondido do repomix. **O repomix enviado é completo** quanto à lógica — os padrões de exclusão (`*.g.dart`, `*.freezed.dart`) não removeram nada porque não existem.
> Modelos são majoritariamente `Map<String, dynamic>` crus passados entre camadas (padrão do projeto). As únicas classes com toJson/fromJson manuais recentes: `_ItemGasto`/`_Simulacao` em `simulador_gastos_screen.dart`, itens da fila em `notificacao_fila_service.dart`.

### 5.2 `git log --oneline -20` (navegação recente)
```
e523a95 feat: tela Simulador de gastos (Configurações › Inteligência)
cc574bb fix: 2ª leva da auditoria — 9 correções de lógica/UX
f0a62ab fix: saldo lê fonte de verdade + delete/restore via API (sync Mongo)
dc289ca fix: destrava 'Salvando...' ao concluir jejum
f2c770d feat: seletor 'Quando você iniciou?' ao começar o jejum
d9d1bee fix: organiza fluxo do timer de jejum ao atingir a meta
78674af feat: timer de jejum mostra quando começa/termina + edição do início
8314d51 security: corrige 3 riscos (cobrança dupla, chaves texto plano, isolamento)
d533a43 fix: erros do Sentry — TypeError histórico saúde + exact_alarms jejum
d6f1586 feat: escanear cupom NFC-e para enriquecer compra pendente existente
4bb9a2c feat: jejum 3º segmento + dashboard + captura notificações + popup pendentes
c96a3e5 feat: módulo jejum 100% conforme ao artefato — backend IA + telas
```
> A maior parte da atividade recente é no **módulo jejum** (timer, fluxos) e **saldo/compras**. O commit `4bb9a2c` mexeu na navegação (3º segmento + popup pendentes no main_navigation).

---

## 6. Reprodução manual de bugs (PREENCHER — só o usuário sabe)

> Esta seção precisa ser preenchida pelo usuário observando o app rodando.
> Formato para cada bug (3 a 5):

### Bug 1
- **Tela de origem:** _(ex: Home)_
- **Ação do usuário:** _(ex: toquei no chip de jejum ativo)_
- **Tela esperada:** _(ex: abrir o timer)_
- **O que aconteceu de fato:** _(ex: voltou pra Home / travou / tela em branco)_
- **Texto exato do erro (se houver):** _(SnackBar / console / Sentry)_

### Bug 2
- **Tela de origem:**
- **Ação do usuário:**
- **Tela esperada:**
- **O que aconteceu de fato:**
- **Texto exato do erro:**

### Bug 3
- **Tela de origem:**
- **Ação do usuário:**
- **Tela esperada:**
- **O que aconteceu de fato:**
- **Texto exato do erro:**

### Bug 4 (opcional)
### Bug 5 (opcional)

---

## Resumo executivo (o que merece atenção)

| # | Achado | Severidade |
|---|--------|-----------|
| 0 | **Sentry: 15 crashes fatais reais, TODOS de layout** (overflow/constraints) no A546E — mas sem símbolos/observer, não dá pra localizar a tela. Instrumentação incompleta. | **Alta** |
| 1 | `UnicornSplashScreen._shown` static nunca reseta no logout | Baixa (visual) |
| 2 | `sugestaoJantarProvider` é código morto (nunca consumido) | Limpeza |
| 3 | Inconsistência de rotas nomeadas `/home` (splash) vs `/gate` (logout) | Média (foi origem de bug) |
| 4 | 91 blocos `catch`, muitos silenciosos (`catch (_) {}`) sem reportar | Média (esconde erros) |
| 5 | `Sentry.setExtra` deprecado em 8 pontos | Baixa |
| 6 | Deps majors atrás (riverpod 3.x, google_sign_in 7.x, local_notifications) | Média (upgrade arriscado) |
| 7 | 170 lints `info` (cosméticos) — `dart fix` resolve 108 automaticamente | Baixa |
| — | **0 errors, 0 warnings** no analyze | ✅ compila limpo |
