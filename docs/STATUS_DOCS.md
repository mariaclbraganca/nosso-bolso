# Índice da Documentação — Nosso Bolso

> Mapa de toda a documentação do projeto e quem é fonte de verdade do quê.
> Última atualização: 2026-07-19

---

## Documentos vivos (manter atualizados)

| Documento | Fonte de verdade de… | Atualizar quando… |
|-----------|----------------------|-------------------|
| `envelope-flutter-v2/CLAUDE.md` | Diretriz técnica do mobile (arquitetura, design system, regras de código) | Mudar arquitetura, módulo, regra de UI/código |
| `docs/DATABASE.md` | Camada de dados (tabelas, colunas, triggers, RLS, índices, MongoDB) | Nova tabela/coluna/trigger/índice |
| `AGENTS.md` (raiz) | Regras de ouro + stack + anti-patterns | Nova regra absoluta ou mudança de stack |
| `docs/BUSINESS_RULES.md` | Regras de negócio (RN01…RN16) | Nova regra de cálculo/comportamento |
| `docs/ROADMAP.md` | O que foi entregue e o que falta | Concluir/adicionar feature |
| `DEPLOY.md` (raiz) | Como deploya (Render, cron, secrets, Supabase) | Mudar processo de deploy |

## Convenções

- Regras de dev/negócio: `AGENTS.md` + `docs/BUSINESS_RULES.md`
- Implementação mobile: `envelope-flutter-v2/CLAUDE.md`
- Dados: `docs/DATABASE.md`
- Próximos passos: `docs/ROADMAP.md`

## Arquivo histórico (`docs/_arquivo/`)

Contém material de referência já superado — **não é fonte de verdade**:
- `specs/SPEC-01…18` — specs das features já entregues (o ROADMAP resume o estado)
- `AGENTS.MD`, `BUSSINES_RULES_antigo.MD`, `GUIDE.MD`, `SKILLS.MD` — duplicatas/versões antigas
- `UI_SPEC.MD`, `TEST_SPECS.MD` — specs visuais/teste antigas (design system atual está no CLAUDE.md)
- `PROMPT_*`, `RELATORIO_TESTES_2026-04-04.md` — prompts e relatórios pontuais de abr/2026
