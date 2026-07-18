# SPEC-03 — Busca e Filtros Avancados no Extrato

**Prioridade:** Alta (Semana 1)
**Esforco:** Medio
**Status:** Planejado

---

## Problema

O extrato so filtra por mes, tipo, usuario e envelope. Nao existe busca por texto na descricao, filtro por faixa de valor, ou periodo customizado.

## Funcionalidades

### 1. Busca por texto

**Backend:**
```
GET /transacoes/extrato?q=uber&...
```

```python
if q: query = query.ilike("descricao", f"%{q}%")
```

**Flutter:**
- Campo de busca no topo do `ExtratoScreen` com `SearchBar`
- Busca acontece ao digitar (debounce de 500ms)
- Highlight do termo buscado no resultado

### 2. Filtro por faixa de valor

**Backend:**
```
GET /transacoes/extrato?valor_min=100&valor_max=500
```

```python
if valor_min: query = query.gte("valor", valor_min)
if valor_max: query = query.lte("valor", valor_max)
```

**Flutter:**
- `RangeSlider` no painel de filtros
- Valores min/max baseados nos dados do mes

### 3. Filtro por periodo customizado

**Backend:**
```
GET /transacoes/extrato?data_inicio=2026-03-15&data_fim=2026-04-10
```

Substituir o filtro `mes` por range de datas. Manter compatibilidade:
```python
if mes:
    data_inicio = f"{mes}-01"
    data_fim = f"{mes}-{ultimo_dia}"
if data_inicio: query = query.gte("data", data_inicio)
if data_fim: query = query.lte("data", data_fim)
```

**Flutter:**
- `showDateRangePicker()` do Material 3
- Botao ao lado do seletor de mes: "Periodo personalizado"

### 4. Painel de filtros

**Flutter — `FilterDrawer` ou `BottomSheet`:**
- Tipo: despesa / receita / abastecimento (chips)
- Usuario: dropdown (ja existe)
- Envelope: dropdown (ja existe)
- Periodo: mes ou range customizado
- Valor: range slider
- Busca: campo de texto
- Botao "Limpar filtros"

---

## Criterios de Aceite

- [ ] Busca por texto encontra transacoes pela descricao (case-insensitive)
- [ ] Filtro de valor min/max funciona corretamente
- [ ] Periodo customizado aceita qualquer range de datas
- [ ] Filtros sao combinaveis (texto + valor + periodo + usuario)
- [ ] "Limpar filtros" reseta tudo para o estado padrao
- [ ] Debounce na busca para evitar requisicoes excessivas

---

## Arquivos Afetados

| Arquivo | Alteracao |
|---------|-----------|
| `envelope-api/routes/transacoes.py` | Adicionar params `q`, `valor_min`, `valor_max`, `data_inicio`, `data_fim` |
| `envelope-flutter/lib/screens/extrato_screen.dart` | Adicionar SearchBar + painel de filtros |
| Nova: `envelope-flutter/lib/widgets/filter_panel.dart` | Componente reutilizavel de filtros |
