# ROADMAP — Nosso Bolso (Envelope App)

Ultima atualizacao: 2026-04-04

---

## Legenda

- 🔴 Nao iniciado
- 🟡 Em andamento
- 🟢 Concluido

---

## Fase 0 — Correcoes (Concluido)

| # | Item | Status | Spec |
|---|------|--------|------|
| 0.1 | Drop trigger antigo `trg_saldo` | 🟢 | — |
| 0.2 | Fix extrato com mes (calendar.monthrange) | 🟢 | — |
| 0.3 | Fix dashboard stats (filtrar familia_id) | 🟢 | — |
| 0.4 | Fix DELETE retornar 404 para ID inexistente | 🟢 | — |
| 0.5 | Adicionar Pydantic em POST /envelopes/ | 🟢 | — |

---

## Fase 1 — Essenciais (Semana 1-2)

| # | Item | Status | Spec | Esforco |
|---|------|--------|------|---------|
| 1.1 | Isolamento API por familia_id | 🔴 | [SPEC-02](specs/SPEC-02_ISOLAMENTO_API_FAMILIA.md) | Baixo |
| 1.2 | Editar transacoes, envelopes, fixos | 🔴 | [SPEC-01](specs/SPEC-01_EDITAR_TRANSACOES_ENVELOPES.md) | Medio |
| 1.3 | Busca e filtros avancados no extrato | 🔴 | [SPEC-03](specs/SPEC-03_BUSCA_TRANSACOES.md) | Medio |
| 1.4 | Paginacao e scroll infinito | 🔴 | [SPEC-12](specs/SPEC-12_PAGINACAO_PERFORMANCE.md) | Baixo |
| 1.5 | Cores dinamicas por usuario | 🔴 | [SPEC-13](specs/SPEC-13_CORES_DINAMICAS_USUARIOS.md) | Trivial |
| 1.6 | Remover debug prints do main.dart | 🔴 | — | Trivial |

---

## Fase 2 — Funcionalidades (Semana 3-4)

| # | Item | Status | Spec | Esforco |
|---|------|--------|------|---------|
| 2.1 | Gastos fixos recorrentes | 🔴 | [SPEC-04](specs/SPEC-04_FIXOS_RECORRENTES.md) | Medio |
| 2.2 | Transferencia entre envelopes | 🔴 | [SPEC-05](specs/SPEC-05_TRANSFERENCIA_ENTRE_ENVELOPES.md) | Baixo |
| 2.3 | Exportar PDF/CSV | 🔴 | [SPEC-07](specs/SPEC-07_EXPORTAR_PDF_CSV.md) | Medio |
| 2.4 | Historico comparativo entre meses | 🔴 | [SPEC-09](specs/SPEC-09_HISTORICO_COMPARATIVO.md) | Medio |

---

## Fase 3 — Experiencia (Mes 2)

| # | Item | Status | Spec | Esforco |
|---|------|--------|------|---------|
| 3.1 | Notificacoes push (FCM) | 🔴 | [SPEC-06](specs/SPEC-06_NOTIFICACOES_PUSH.md) | Alto |
| 3.2 | Metas de economia | 🔴 | [SPEC-08](specs/SPEC-08_METAS_ECONOMIA.md) | Medio |
| 3.3 | Wizard de onboarding | 🔴 | [SPEC-10](specs/SPEC-10_ONBOARDING_WIZARD.md) | Medio |
| 3.4 | Soft delete com lixeira | 🔴 | [SPEC-11](specs/SPEC-11_SOFT_DELETE_LIXEIRA.md) | Medio |

---

## Fase 4 — Diferenciadores (Mes 3+)

| # | Item | Status | Spec | Esforco |
|---|------|--------|------|---------|
| 4.1 | Foto de comprovante | 🔴 | [SPEC-14](specs/SPEC-14_FOTO_COMPROVANTE.md) | Medio |
| 4.2 | Permissoes por membro | 🔴 | [SPEC-15](specs/SPEC-15_PERMISSOES_FAMILIA.md) | Alto |
| 4.3 | Widget home screen | 🔴 | [SPEC-16](specs/SPEC-16_WIDGET_HOME_SCREEN.md) | Medio |
| 4.4 | Orcamento inteligente (IA) | 🔴 | [SPEC-17](specs/SPEC-17_IA_ORCAMENTO_INTELIGENTE.md) | Alto |

---

## Indice de Specs

| Spec | Titulo | Prioridade |
|------|--------|------------|
| SPEC-01 | Editar transacoes, envelopes e fixos | Semana 1 |
| SPEC-02 | Isolamento API por familia | Imediato |
| SPEC-03 | Busca e filtros avancados | Semana 1 |
| SPEC-04 | Gastos fixos recorrentes | Semana 2 |
| SPEC-05 | Transferencia entre envelopes | Semana 2 |
| SPEC-06 | Notificacoes push | Mes 2 |
| SPEC-07 | Exportar PDF/CSV | Semana 3 |
| SPEC-08 | Metas de economia | Mes 2 |
| SPEC-09 | Historico comparativo | Semana 3 |
| SPEC-10 | Onboarding wizard | Mes 2 |
| SPEC-11 | Soft delete / lixeira | Mes 2 |
| SPEC-12 | Paginacao e performance | Semana 1 |
| SPEC-13 | Cores dinamicas | Quick fix |
| SPEC-14 | Foto de comprovante | Mes 3 |
| SPEC-15 | Permissoes familia | Mes 3 |
| SPEC-16 | Widget home screen | Mes 3 |
| SPEC-17 | IA / orcamento inteligente | Mes 3+ |
