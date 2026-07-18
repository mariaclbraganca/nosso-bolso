# SPEC-09 — Historico Comparativo entre Meses

**Prioridade:** Media (Semana 3)
**Esforco:** Medio
**Status:** Planejado

---

## Problema

Os relatorios so mostram o mes atual. O usuario nao consegue ver evolucao, comparar gastos entre meses, ou identificar tendencias.

## Funcionalidades

### 1. Endpoint de historico mensal

**`GET /dashboard/historico?familia_id=<uuid>&meses=6`**

Retorna agregado dos ultimos N meses:
```json
{
    "meses": [
        {"mes": "2025-11", "receitas": 5000, "despesas": 4200, "saldo_final": 800},
        {"mes": "2025-12", "receitas": 7000, "despesas": 5500, "saldo_final": 1500},
        {"mes": "2026-01", "receitas": 5000, "despesas": 4800, "saldo_final": 200},
        ...
    ],
    "media_receitas": 5500,
    "media_despesas": 4800,
    "tendencia": "estavel"
}
```

### 2. Endpoint de comparacao por envelope

**`GET /dashboard/comparacao-envelopes?familia_id=<uuid>&mes1=2026-03&mes2=2026-04`**

```json
{
    "envelopes": [
        {
            "nome": "Alimentacao",
            "mes1_gasto": 1200,
            "mes2_gasto": 1450,
            "variacao_pct": 20.8,
            "direcao": "subiu"
        },
        ...
    ]
}
```

### 3. Flutter — Novos graficos em `RelatoriosScreen`

**Grafico de evolucao mensal:**
- Barras empilhadas: receita (verde) vs despesa (vermelho) por mes
- Linha de saldo acumulado
- Ultimos 6 meses
- Usar `fl_chart` BarChart

**Comparacao mes a mes:**
- Selecionar 2 meses via dropdown
- Tabela comparativa por envelope com setas (subiu/desceu)
- Highlight em vermelho quando gasto aumentou > 20%

**Card de insight:**
- "Voce gastou 15% mais em Alimentacao este mes"
- "Seus gastos com Lazer cairam 30% — parabens!"
- Baseado na comparacao automatica com mes anterior

### 4. Media movel

Mostrar media dos ultimos 3 meses como linha pontilhada nos graficos. Permite identificar se o mes atual esta acima ou abaixo da media.

---

## Criterios de Aceite

- [ ] Endpoint retorna historico dos ultimos N meses
- [ ] Grafico de evolucao mensal com barras + linha de saldo
- [ ] Comparacao entre 2 meses com variacao percentual
- [ ] Insights automaticos baseados em comparacao
- [ ] Media movel visivel nos graficos

---

## Arquivos Afetados

| Arquivo | Alteracao |
|---------|-----------|
| `envelope-api/routes/dashboard.py` | Adicionar `/historico` e `/comparacao-envelopes` |
| `envelope-flutter/lib/screens/relatorios_screen.dart` | Novos graficos |
| Nova: `envelope-flutter/lib/widgets/relatorios/evolucao_mensal_chart.dart` | Barras empilhadas |
| Nova: `envelope-flutter/lib/widgets/relatorios/comparacao_meses_card.dart` | Tabela comparativa |
