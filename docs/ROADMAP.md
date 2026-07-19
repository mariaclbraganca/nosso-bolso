# ROADMAP — Nosso Bolso

> O que já foi entregue e o que falta.
> Última atualização: 2026-07-19

Legenda: 🟢 concluído · 🟡 em andamento · 🔴 não iniciado

---

## Entregue (🟢)

### Financeiro (base)
- Envelopes, transações (receita/despesa/abastecimento), saldo via trigger
- Gastos fixos recorrentes com toggle pago (ajusta saldo_geral)
- Transferência/remanejamento entre envelopes + log de auditoria
- Metas de economia · Contas de patrimônio + snapshots mensais
- Isolamento por família (RLS + filtro backend) · Permissões admin/membro
- Editar transações/envelopes/fixos · Busca e filtros no extrato · Paginação
- Soft delete + lixeira · Exportar PDF/CSV · Histórico comparativo entre meses
- Foto de comprovante · Cores dinâmicas por usuário · Onboarding (criar/entrar família)

### IA de Compras
- Ingestão NFC-e (scraping no device + Gemini) com anti-alucinação
- Dicionário de produtos por família (aprende preço médio + sinônimos)
- Feedback de consumo (shelf-life) · Lista inteligente / orçamento
- Captura por notificação (Nubank/iFood) com roteamento pix→receita + dedup
- Enriquecimento de compra pendente por cupom (vínculo via compra_id)

### Bem-estar (Minha Vida)
- Saúde (dashboard diário, macros, hidratação, histórico, perfil metabólico)
- Exercício
- **Jejum** — módulo completo: onboarding, protocolos + sugestão IA, timer com
  fases metabólicas, histórico (calendário + KPIs), insights IA, Fast Together
  (dupla), celebração/reflexão, notificações de marco, chip na Home

### Infra
- Notificações push (FCM + locais) · Cron GitHub Actions (motivações jejum)
- Sentry em produção · Deploy Render auto via push

---

## Pendente / Ideias (🔴)

| Item | Notas |
|------|-------|
| Widget de home screen (Android) | Único item das specs antigas ainda não feito |
| Regra ProGuard/R8 para TypeToken | Só afeta build release (Play Store) |
| Publicação na Play Store | Requer o ProGuard acima + assinatura |

---

> Specs históricas detalhadas (features já entregues) em `docs/_arquivo/specs/`.
