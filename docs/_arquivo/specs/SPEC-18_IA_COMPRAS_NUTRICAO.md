# SPEC-18 — Módulo IA de Compras e Nutrição

**Status:** Aprovado para implementação  
**Data:** 2026-05-03  
**Versão:** 1.0  
**Depende de:** Core Financeiro v2 (funcionando)

---

## 1. Decisões arquiteturais (7/7 resolvidas)

| # | Pilar | Decisão | Justificativa |
|---|-------|---------|---------------|
| P1 | Compra → Despesa | Confirmação 1-toque (Opção B) | Protege contra scan acidental |
| P2 | ChromaDB | Removido. Injeção direta no prompt | perfil_familia tem ~500 tokens |
| P3 | Ollama fallback | Circuit Breaker → Gemini Flash | 5s timeout, custo centavos |
| P4 | nome_padronizado | dicionario_produtos + merge manual | Evita duplicidade no burn rate |
| P5 | Estrutura de pastas | Módulo isolado /ia_compras/ | NO_GOD_FILES inegociável |
| P6 | Feedback temporal | Shelf-life por categoria | 5-7d perecível, 30-45d seco |
| P7 | Categorias | Enum rígido no LangExtract | Blinda dados para o nutricionista |

---

## 2. Stack final (sem ChromaDB)

| Camada | Tecnologia | Papel |
|--------|-----------|-------|
| Ingestão | Scraper Python (requests + BeautifulSoup) | Raspa HTML da SEFAZ |
| Extração | LangExtract + Gemma 4 (Ollama) | HTML → JSON estruturado |
| Fallback | LangExtract + Gemini Flash (Google AI) | Circuit breaker se Ollama cair |
| Armazenamento | MongoDB | Compras, perfil, dicionário |
| Orquestração | Google AI Studio API | Gera lista de compras final |
| Financeiro | Supabase PostgreSQL (existente) | Lê saldo_atual do envelope |
| Frontend | Flutter + Riverpod (existente) | Scan, confirmação, feedback |

---

## 3. Estrutura de pastas

```
envelope-api/
├── main.py                    # Existente — adicionar include_router do módulo
├── database.py                # Existente — Supabase client
├── models.py                  # Existente — modelos do core financeiro
├── routes/                    # Existente
│   ├── transacoes.py
│   ├── envelopes.py
│   ├── dashboard.py
│   ├── abastecer.py
│   ├── fixos.py
│   ├── remanejar.py
│   ├── insights.py
│   └── notificacoes.py
│
├── ia_compras/                # ← NOVO MÓDULO (isolado)
│   ├── __init__.py
│   ├── router.py              # Endpoints FastAPI (≤180 linhas)
│   ├── models_compras.py      # Pydantic models + Enums (≤150 linhas)
│   ├── scraper_sefaz.py       # Raspagem HTML da SEFAZ (≤120 linhas)
│   ├── agente_extrator.py     # LangExtract + Ollama/Gemini (≤150 linhas)
│   ├── agente_estoque.py      # Burn rate heurístico (≤120 linhas)
│   ├── agente_orcamento.py    # Consulta saldo envelope Supabase (≤60 linhas)
│   ├── agente_orquestrador.py # Google AI Studio + prompt (≤150 linhas)
│   ├── circuit_breaker.py     # Fallback Ollama → Gemini (≤80 linhas)
│   ├── mongo_client.py        # Conexão MongoDB singleton (≤40 linhas)
│   └── shelf_life.py          # Tabela de tempo de vida por categoria (≤60 linhas)
│
└── requirements.txt           # Atualizado com pymongo, langextract, etc.
```

**Registro no main.py:**
```python
from ia_compras.router import router as compras_router
app.include_router(compras_router, prefix="/api/v1/compras", tags=["ia-compras"])
```

---

## 4. Enum de categorias (Pilar 7)

```python
# ia_compras/models_compras.py
from enum import Enum

class CategoriaItem(str, Enum):
    PROTEINAS = "Proteínas"
    CARBOIDRATOS = "Carboidratos"
    HORTIFRUTI = "Hortifrúti"
    LATICINIOS = "Laticínios"
    PADARIA = "Padaria"
    BEBIDAS = "Bebidas"
    LANCHES = "Lanches"
    TEMPEROS = "Temperos e Condimentos"
    LIMPEZA = "Limpeza"
    HIGIENE = "Higiene Pessoal"
    CONGELADOS = "Congelados"
    GRAOS = "Grãos e Cereais"
    OUTROS = "Outros"
```

---

## 5. Tabela shelf-life (Pilar 6)

```python
# ia_compras/shelf_life.py
from ia_compras.models_compras import CategoriaItem
from datetime import timedelta

SHELF_LIFE: dict[CategoriaItem, timedelta] = {
    CategoriaItem.HORTIFRUTI:  timedelta(days=6),
    CategoriaItem.PADARIA:     timedelta(days=5),
    CategoriaItem.LATICINIOS:  timedelta(days=14),
    CategoriaItem.PROTEINAS:   timedelta(days=7),   # fresco; congelado usa CONGELADOS
    CategoriaItem.CONGELADOS:  timedelta(days=45),
    CategoriaItem.BEBIDAS:     timedelta(days=30),
    CategoriaItem.LANCHES:     timedelta(days=21),
    CategoriaItem.CARBOIDRATOS:timedelta(days=30),
    CategoriaItem.TEMPEROS:    timedelta(days=60),
    CategoriaItem.LIMPEZA:     timedelta(days=60),
    CategoriaItem.HIGIENE:     timedelta(days=45),
    CategoriaItem.GRAOS:       timedelta(days=45),
    CategoriaItem.OUTROS:      timedelta(days=30),
}

def calcular_data_feedback(data_compra, categoria: CategoriaItem):
    """Retorna a data em que o app deve pedir feedback sobre este item."""
    return data_compra + SHELF_LIFE.get(categoria, timedelta(days=30))
```

---

## 6. Modelagem MongoDB

### 6.1. Coleção: `historico_compras`

```json
{
  "_id": "ObjectId",
  "compra_id": "uuid-gerado-api",
  "familia_id": "uuid-referencia-supabase",
  "data_compra": "2026-05-03T18:30:00Z",
  "supermercado": "Atacadão",
  "valor_total": 245.90,
  "qr_code_url": "https://nfce.sefaz.go.gov.br/...",
  "status_integracao": "pendente",
  "transacao_supabase_id": null,
  "itens": [
    {
      "nome_original": "BISC RECH INT MOR 130G",
      "nome_padronizado": "Biscoito Recheado Integral Morango",
      "produto_ref_id": "ObjectId-do-dicionario",
      "categoria": "Lanches",
      "quantidade": 2.0,
      "unidade": "un",
      "valor_unitario": 3.50,
      "valor_total_item": 7.00,
      "status_consumo": "ativo",
      "data_feedback_estimada": "2026-05-24T18:30:00Z"
    }
  ],
  "created_at": "2026-05-03T18:31:00Z"
}
```

**Campos-chave:**
- `status_integracao`: `pendente` → `confirmado` → `cancelado`
- `transacao_supabase_id`: preenchido quando o usuário confirma (Pilar 1)
- `produto_ref_id`: link para o `dicionario_produtos` (Pilar 4)
- `data_feedback_estimada`: calculada pelo `shelf_life.py` (Pilar 6)

### 6.2. Coleção: `perfil_familia`

```json
{
  "_id": "ObjectId",
  "familia_id": "uuid-referencia-supabase",
  "perfil_moradores": [
    {"nome": "Frederico", "contexto": "Foco/Trabalho, almoça em restaurante"},
    {"nome": "Maria Clara", "contexto": "Saúde/Estudo, come em casa"},
    {"nome": "Alan", "contexto": "Rotina flexível, lanches rápidos"}
  ],
  "paladar_e_saude": {
    "itens_proibidos": ["Fígado", "Refrigerantes com açúcar"],
    "preferencias": ["Frango grelhado", "Lanches práticos"],
    "suplementacao": ["Ômega-3", "CoQ10", "Whey Protein"]
  },
  "logistica_e_rotina": {
    "tempo_max_preparo_jantar_min": 30,
    "jantar_em_casa_dias_uteis": true,
    "compras_frequencia_dias": 15
  },
  "cesta_basica_inegociavel": [
    "Ovos", "Peito de Frango", "Arroz", "Tomate", "Queijo Mussarela"
  ],
  "regras_financeiras": {
    "limite_mensal": 1400.00,
    "regra_substituicao": "Se carne bovina estourar orçamento, priorizar frango e suíno"
  },
  "updated_at": "2026-05-03T00:00:00Z"
}
```

### 6.3. Coleção: `dicionario_produtos` (Pilar 4)

```json
{
  "_id": "ObjectId",
  "familia_id": "uuid-referencia-supabase",
  "nome_canonico": "Filé de Frango Congelado",
  "categoria": "Proteínas",
  "sinonimos_llm": [
    "FILE FRANGO CONG 1KG",
    "FRANGO FILE CONG KG",
    "FLE FRANG CONGEL 1K"
  ],
  "preco_medio": 18.90,
  "unidade_padrao": "kg",
  "created_at": "2026-05-03T00:00:00Z"
}
```

**Fluxo do Pilar 4:**
1. LangExtract gera `nome_padronizado` a partir do texto da nota
2. Agente Extrator busca no `dicionario_produtos` por match exato ou similaridade
3. Se encontrar → usa o `nome_canonico` existente + atualiza `preco_medio`
4. Se não encontrar → cria entrada nova + adiciona como sinônimo
5. Na UI de feedback, o usuário pode mesclar produtos duplicados

---

## 7. Modelos Pydantic

```python
# ia_compras/models_compras.py

from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime
from uuid import UUID
from enum import Enum

class CategoriaItem(str, Enum):
    PROTEINAS = "Proteínas"
    CARBOIDRATOS = "Carboidratos"
    HORTIFRUTI = "Hortifrúti"
    LATICINIOS = "Laticínios"
    PADARIA = "Padaria"
    BEBIDAS = "Bebidas"
    LANCHES = "Lanches"
    TEMPEROS = "Temperos e Condimentos"
    LIMPEZA = "Limpeza"
    HIGIENE = "Higiene Pessoal"
    CONGELADOS = "Congelados"
    GRAOS = "Grãos e Cereais"
    OUTROS = "Outros"

class StatusConsumo(str, Enum):
    ATIVO = "ativo"
    ACABOU = "acabou"
    ESTRAGOU = "estragou"

class StatusIntegracao(str, Enum):
    PENDENTE = "pendente"
    CONFIRMADO = "confirmado"
    CANCELADO = "cancelado"

# --- Requests ---

class IngestaoRequest(BaseModel):
    familia_id: UUID
    qr_code_url: str

    @field_validator("qr_code_url")
    @classmethod
    def url_valida(cls, v):
        if "nfce" not in v.lower() and "sefaz" not in v.lower():
            raise ValueError("URL não parece ser de uma NFC-e da SEFAZ")
        return v

class FeedbackItemRequest(BaseModel):
    compra_id: str
    nome_padronizado: str
    status: StatusConsumo

class ConfirmarCompraRequest(BaseModel):
    compra_id: str
    familia_id: UUID
    usuario_id: UUID
    envelope_id: UUID

class PlanejamentoRequest(BaseModel):
    familia_id: UUID
    dias: int = 15

    @field_validator("dias")
    @classmethod
    def dias_valido(cls, v):
        if v not in (7, 15, 30):
            raise ValueError("dias deve ser 7, 15 ou 30")
        return v

class MergeProdutoRequest(BaseModel):
    produto_manter_id: str
    produto_remover_id: str

# --- Responses ---

class ItemExtraido(BaseModel):
    nome_original: str
    nome_padronizado: str
    categoria: CategoriaItem
    quantidade: float
    unidade: str
    valor_unitario: float
    valor_total_item: float

class CompraExtraida(BaseModel):
    compra_id: str
    supermercado: str
    valor_total: float
    data_compra: datetime
    itens: list[ItemExtraido]
    status_integracao: StatusIntegracao = StatusIntegracao.PENDENTE

class ItemLista(BaseModel):
    nome: str
    categoria: CategoriaItem
    quantidade_sugerida: float
    unidade: str
    preco_estimado: float
    motivo: str
    corte_sugerido: bool = False

class ListaComprasGerada(BaseModel):
    familia_id: str
    dias_cobertura: int
    saldo_envelope: float
    custo_estimado_total: float
    dentro_do_orcamento: bool
    itens: list[ItemLista]
    gerado_em: datetime
```

---

## 8. Contratos de API

### 8.1. Ingestão (scan QR code)
```
POST /api/v1/compras/ingestao
Body: IngestaoRequest
Response: 202 Accepted + {"compra_id": "uuid", "status": "processando"}
```
Background task: scraper → LangExtract → MongoDB (status=pendente)

### 8.2. Listar compras pendentes de confirmação
```
GET /api/v1/compras/pendentes?familia_id={uuid}
Response: list[CompraExtraida]
```
Flutter consome esse endpoint para exibir os cards de confirmação.

### 8.3. Confirmar compra → registra despesa no core
```
POST /api/v1/compras/confirmar
Body: ConfirmarCompraRequest
Ação interna:
  1. POST /transacoes (tipo=despesa, envelope_id, valor_total) → TRIGGER_IS_LAW
  2. MongoDB: status_integracao = "confirmado", transacao_supabase_id = id retornado
Response: 200 + {"transacao_id": "uuid-supabase", "saldo_restante": float}
```

### 8.4. Cancelar compra pendente
```
DELETE /api/v1/compras/{compra_id}?familia_id={uuid}
Ação: MongoDB status_integracao = "cancelado"
Response: 200
```

### 8.5. Feedback de consumo (swipe)
```
PATCH /api/v1/compras/feedback
Body: FeedbackItemRequest
Response: 200
```

### 8.6. Listar itens aguardando feedback (shelf-life vencido)
```
GET /api/v1/compras/feedback-pendente?familia_id={uuid}
Ação: Query itens onde data_feedback_estimada ≤ now() AND status_consumo = "ativo"
Response: lista de itens com compra_id, nome, categoria, dias_desde_compra
```

### 8.7. Gerar lista de compras inteligente
```
GET /api/v1/compras/planejar?familia_id={uuid}&dias=15
Ação: Pipeline multi-agente (estoque → orçamento → orquestrador)
Response: ListaComprasGerada
```

### 8.8. Merge de produtos duplicados (Pilar 4)
```
POST /api/v1/compras/produtos/merge
Body: MergeProdutoRequest
Ação: Une sinonimos_llm, recalcula preco_medio, atualiza referências
Response: 200
```

---

## 9. Circuit breaker (Pilar 3)

```python
# ia_compras/circuit_breaker.py
import httpx
from enum import Enum

class LLMProvider(str, Enum):
    OLLAMA = "ollama"
    GEMINI = "gemini"

OLLAMA_URL = "http://sua-vps:11434/api/generate"
OLLAMA_TIMEOUT = 5.0

async def extrair_com_fallback(html_bruto: str, schema: dict) -> tuple[dict, LLMProvider]:
    """Tenta Ollama local; se falhar em 5s, escala para Gemini Flash."""
    try:
        async with httpx.AsyncClient(timeout=OLLAMA_TIMEOUT) as client:
            resp = await client.post(OLLAMA_URL, json={
                "model": "gemma3:12b",
                "prompt": _montar_prompt_extracao(html_bruto, schema),
                "stream": False
            })
            resp.raise_for_status()
            return _parse_response(resp.json()), LLMProvider.OLLAMA
    except (httpx.TimeoutException, httpx.ConnectError, httpx.HTTPStatusError):
        # Fallback: Google AI Studio (Gemini Flash)
        resultado = await _chamar_gemini_flash(html_bruto, schema)
        return resultado, LLMProvider.GEMINI
```

---

## 10. Fluxo de integração com o core (Pilar 1 — detalhado)

```
Usuário escaneia QR Code no Flutter
           │
           ▼
POST /api/v1/compras/ingestao (202 Accepted)
           │
           ▼ (Background Task)
scraper_sefaz.py → HTML bruto
           │
           ▼
circuit_breaker.py → Ollama ou Gemini
           │
           ▼
agente_extrator.py → LangExtract valida source grounding
           │                    │
           │           ❌ Alucinação detectada → Aborta, salva raw com erro
           ▼
MongoDB: status_integracao = "pendente"
           │
           ▼
Flutter consulta: GET /pendentes → Mostra card de confirmação
           │
     ┌─────┴─────┐
     ▼            ▼
  "Sim"       "Cancelar"
     │            │
     ▼            ▼
POST /confirmar   DELETE /compra_id
     │
     ▼
API financeira: POST /transacoes
  tipo = "despesa"
  envelope_id = envelope "Mercado"
  valor = valor_total da nota
  descricao = "Atacadão — 15 itens"
  ─── TRIGGER_IS_LAW ───
     │
     ▼
MongoDB: status = "confirmado"
         transacao_supabase_id = id
```

**Regra crítica:** O valor que sai do envelope é o `valor_total` da nota, não a soma dos itens. Isso garante que arredondamentos da SEFAZ não criem centavos fantasmas.

---

## 11. Ordem de implementação (fases)

### Fase A — Fundação (semana 1)
1. [ ] Configurar MongoDB (container Docker ou MongoDB Atlas free tier)
2. [ ] Criar `ia_compras/mongo_client.py` (singleton)
3. [ ] Criar `ia_compras/models_compras.py` (Enums + Pydantic)
4. [ ] Criar `ia_compras/shelf_life.py`
5. [ ] Criar coleções no MongoDB: `historico_compras`, `perfil_familia`, `dicionario_produtos`
6. [ ] Inserir manualmente o `perfil_familia` da família

### Fase B — Ingestão (semana 2)
1. [ ] Implementar `scraper_sefaz.py` (refatorar do TF2)
2. [ ] Implementar `circuit_breaker.py`
3. [ ] Implementar `agente_extrator.py` com LangExtract
4. [ ] Implementar `router.py`: POST /ingestao
5. [ ] Testar com 3 notas reais da SEFAZ-GO

### Fase C — Confirmação + Bridge financeiro (semana 3)
1. [ ] Implementar `router.py`: GET /pendentes
2. [ ] Implementar `router.py`: POST /confirmar (integração com POST /transacoes)
3. [ ] Implementar `router.py`: DELETE /{compra_id}
4. [ ] Flutter: tela de "Compras Pendentes" com card de confirmação
5. [ ] Testar ciclo completo: scan → pendente → confirmar → saldo desce

### Fase D — Feedback loop (semana 4)
1. [ ] Implementar `router.py`: PATCH /feedback
2. [ ] Implementar `router.py`: GET /feedback-pendente (com shelf-life)
3. [ ] Flutter: tela Tinder-like de feedback de consumo
4. [ ] Implementar lógica de merge no `dicionario_produtos`
5. [ ] Testar: comprar → esperar shelf-life → feedback → burn rate

### Fase E — Geração de lista inteligente (semana 5-6)
1. [ ] Implementar `agente_estoque.py` (burn rate heurístico)
2. [ ] Implementar `agente_orcamento.py` (consulta Supabase)
3. [ ] Implementar `agente_orquestrador.py` (Google AI Studio + perfil)
4. [ ] Implementar `router.py`: GET /planejar
5. [ ] Flutter: tela de lista gerada com flag "corte_sugerido"

---

## 12. Novas regras para AGENTS.md

```markdown
## Módulo IA Compras (regras adicionais)

- **COMPRA_NAO_E_DESPESA**: Uma compra escaneada NÃO é uma despesa até o
  usuário confirmar no app. O scraper salva no MongoDB com status "pendente".
  O POST /transacoes (trigger) só é chamado após confirmação explícita.

- **VALOR_DA_NOTA**: O valor registrado como despesa é o valor_total da nota
  fiscal, não a soma dos itens. Isso evita discrepâncias de arredondamento.

- **CATEGORIA_ENUM_ONLY**: O LangExtract deve usar CategoriaItem como enum
  obrigatório. Categorias fora do enum são rejeitadas na validação Pydantic.

- **MONGO_ISOLADO**: Dados do MongoDB nunca são usados para calcular saldo.
  MongoDB é data layer documental. Saldo vive no Supabase (TRIGGER_IS_LAW).

- **FALLBACK_OBRIGATORIO**: Toda chamada ao Ollama local DEVE ter fallback
  para Gemini Flash via circuit_breaker.py. Timeout de 5 segundos.
```

---

## 13. Dependências novas (requirements.txt)

```
# Módulo IA Compras
pymongo==4.7.0
motor==3.4.0           # Async MongoDB driver
httpx==0.27.0          # Async HTTP (circuit breaker)
beautifulsoup4==4.12.3 # Scraper SEFAZ
langextract>=0.1.0     # Google LangExtract
google-genai>=1.0.0    # Google AI Studio SDK
```
