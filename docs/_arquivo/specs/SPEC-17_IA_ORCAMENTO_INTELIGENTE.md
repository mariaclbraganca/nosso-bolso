# SPEC-17 — Orcamento Inteligente (IA)

**Prioridade:** Baixa (Mes 3+)
**Esforco:** Alto
**Status:** Planejado

---

## Problema

O usuario define valores planejados nos envelopes por intuicao. Nao tem base historica para decidir.

## Funcionalidades

### 1. Sugestao de orcamento

Baseado na media dos ultimos 3 meses:
- "Voce gastou em media R$1.200/mes em Alimentacao. Sugerimos planejar R$1.300."
- Mostrar no `FormEnvelopeSheet` ao criar/editar envelope

### 2. Deteccao de anomalias

Apos registrar um gasto:
- Comparar com media diaria do envelope
- Se > 3x a media: "Gasto de R$800 em Lazer e 3x acima da sua media"
- Mostrar dialog ou snackbar

### 3. Previsao de fim de mes

Card no dashboard:
- "No ritmo atual, voce vai gastar R$1.800 em Alimentacao este mes (planejado: R$1.500)"
- Baseado em regressao linear simples dos gastos diarios

### 4. Implementacao

**Backend — Endpoint:**
```
GET /dashboard/insights?familia_id=<uuid>
```

Retorna:
```json
{
    "sugestoes_orcamento": [
        {"envelope": "Alimentacao", "media_3m": 1200, "sugerido": 1300}
    ],
    "previsao_mes": [
        {"envelope": "Alimentacao", "gasto_atual": 900, "previsao_fim": 1800, "planejado": 1500, "status": "alerta"}
    ],
    "anomalias": []
}
```

Calculos feitos em Python puro (sem necessidade de modelo ML):
- Media movel: `sum(ultimos_3_meses) / 3`
- Previsao: `gasto_ate_hoje / dia_atual * dias_no_mes`
- Anomalia: `valor > media_diaria * 3`

---

## Criterios de Aceite

- [ ] Sugestao de orcamento baseada em historico real
- [ ] Previsao de fim de mes atualizada diariamente
- [ ] Anomalias detectadas em tempo real apos cada gasto
- [ ] Calculos nao dependem de APIs externas (tudo local)

---

## Arquivos Afetados

| Arquivo | Alteracao |
|---------|-----------|
| `envelope-api/routes/dashboard.py` | Adicionar `/insights` |
| `envelope-flutter/lib/screens/relatorios_screen.dart` | Card de insights IA |
| `envelope-flutter/lib/screens/form_envelope_sheet.dart` | Sugestao de valor |
| Nova: `envelope-flutter/lib/widgets/dashboard/insights_card.dart` | Card de previsao |
