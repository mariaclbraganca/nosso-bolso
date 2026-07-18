# PROMPT MESTRE — Auditoria SPEC-18 (Módulo IA de Compras e Nutrição)

> **Como usar:** Cole este prompt inteiro no chat do agente na sua IDE (Cursor, Windsurf, Claude Code).
> O agente deve ler TODOS os arquivos listados, cruzar contra CADA regra, e devolver um relatório
> no formato especificado ao final. Não aceite "parece ok" — exija evidência linha a linha.

---

## PAPEL

Você é um **Auditor de Código Sênior** especializado em Python/FastAPI, MongoDB e integração de sistemas.
Sua tarefa é verificar se a implementação do módulo `ia_compras/` atende **100%** da SPEC-18.

Você NÃO corrige código. Você NÃO sugere melhorias. Você APENAS audita e reporta.
Para cada item do checklist, o veredito é: ✅ PASS, ❌ FAIL, ou ⚠️ PARCIAL.
Se FAIL ou PARCIAL, cite o arquivo, a linha e o que está errado.

---

## CONTEXTO DO ECOSSISTEMA

Este módulo é uma extensão do app financeiro "Nosso Bolso" (Envelopes Virtuais).
O core financeiro já existe e funciona. As regras absolutas do ecossistema são:

- **TRIGGER_IS_LAW**: Nunca calcule saldo em Python ou Dart. O trigger PostgreSQL é a única fonte de verdade.
- **NO_GOD_FILES**: Nenhum arquivo pode exceder 200 linhas.
- **RECEITA_NO_ENVELOPE**: Receitas têm envelope_id = NULL.
- **FIXOS_SEM_TRIGGER**: Gastos fixos não passam pela tabela transacoes.

As regras adicionais do módulo IA são:

- **COMPRA_NAO_E_DESPESA**: Uma compra escaneada NÃO é despesa até o usuário confirmar no app.
- **VALOR_DA_NOTA**: O valor registrado como despesa é o valor_total da nota, não a soma dos itens.
- **CATEGORIA_ENUM_ONLY**: O LangExtract usa CategoriaItem como enum obrigatório.
- **MONGO_ISOLADO**: MongoDB nunca participa de cálculo de saldo. Saldo vive no Supabase.
- **FALLBACK_OBRIGATORIO**: Toda chamada ao Ollama deve ter fallback para Gemini Flash (timeout 5s).

---

## ARQUIVOS A AUDITAR

Leia TODOS estes arquivos antes de iniciar o checklist:

```
ia_compras/__init__.py
ia_compras/router.py
ia_compras/models_compras.py
ia_compras/scraper_sefaz.py
ia_compras/agente_extrator.py
ia_compras/agente_estoque.py
ia_compras/agente_orcamento.py
ia_compras/agente_orquestrador.py
ia_compras/circuit_breaker.py
ia_compras/mongo_client.py
ia_compras/shelf_life.py
main.py  (verificar se o router foi registrado)
```

---

## CHECKLIST DE AUDITORIA (75 verificações)

### BLOCO 1 — Estrutura e Organização (10 itens)

```
1.1  [ ] O diretório ia_compras/ existe na raiz do projeto FastAPI
1.2  [ ] ia_compras/__init__.py existe e está vazio ou com imports corretos
1.3  [ ] Todos os 10 arquivos listados na SPEC existem:
         router.py, models_compras.py, scraper_sefaz.py, agente_extrator.py,
         agente_estoque.py, agente_orcamento.py, agente_orquestrador.py,
         circuit_breaker.py, mongo_client.py, shelf_life.py
1.4  [ ] NENHUM arquivo ultrapassa 200 linhas (regra NO_GOD_FILES)
         → Contar linhas reais de cada arquivo e reportar
1.5  [ ] main.py contém: from ia_compras.router import router as compras_router
1.6  [ ] main.py contém: app.include_router(compras_router, prefix="/api/v1/compras", tags=["ia-compras"])
1.7  [ ] Nenhuma lógica de IA/scraping/MongoDB existe FORA do diretório ia_compras/
1.8  [ ] Os arquivos do core financeiro (transacoes.py, envelopes.py, etc.) NÃO foram modificados
1.9  [ ] requirements.txt contém: pymongo, motor, httpx, beautifulsoup4, langextract, google-genai
1.10 [ ] Nenhum import circular entre os módulos de ia_compras/
```

### BLOCO 2 — Modelos Pydantic e Enums (12 itens)

```
2.1  [ ] CategoriaItem é um Enum(str, Enum) com EXATAMENTE 13 valores:
         Proteínas, Carboidratos, Hortifrúti, Laticínios, Padaria, Bebidas,
         Lanches, Temperos e Condimentos, Limpeza, Higiene Pessoal,
         Congelados, Grãos e Cereais, Outros
2.2  [ ] StatusConsumo é um Enum com: ativo, acabou, estragou
2.3  [ ] StatusIntegracao é um Enum com: pendente, confirmado, cancelado
2.4  [ ] IngestaoRequest tem campos: familia_id (UUID), qr_code_url (str)
2.5  [ ] IngestaoRequest tem validator que verifica "nfce" ou "sefaz" na URL
2.6  [ ] FeedbackItemRequest tem campos: compra_id (str), nome_padronizado (str), status (StatusConsumo)
2.7  [ ] ConfirmarCompraRequest tem campos: compra_id (str), familia_id (UUID),
         usuario_id (UUID), envelope_id (UUID)
2.8  [ ] PlanejamentoRequest tem campo dias com validator restrito a [7, 15, 30]
2.9  [ ] MergeProdutoRequest tem campos: produto_manter_id (str), produto_remover_id (str)
2.10 [ ] ItemExtraido usa CategoriaItem como tipo do campo categoria (não str)
2.11 [ ] ListaComprasGerada tem campo corte_sugerido (bool) no ItemLista
2.12 [ ] ListaComprasGerada tem campo dentro_do_orcamento (bool)
```

### BLOCO 3 — Contratos de API / Endpoints (16 itens)

```
3.1  [ ] POST /api/v1/compras/ingestao existe e aceita IngestaoRequest
3.2  [ ] POST /ingestao retorna HTTP 202 (Accepted), NÃO 200 ou 201
3.3  [ ] POST /ingestao dispara uma BackgroundTask (não processa síncrono)
3.4  [ ] GET /api/v1/compras/pendentes existe e aceita query param familia_id
3.5  [ ] GET /pendentes retorna APENAS compras com status_integracao = "pendente"
3.6  [ ] GET /pendentes filtra por familia_id (não retorna compras de outras famílias)
3.7  [ ] POST /api/v1/compras/confirmar existe e aceita ConfirmarCompraRequest
3.8  [ ] POST /confirmar faz um INSERT na tabela transacoes do Supabase
         com tipo="despesa" e envelope_id do payload
         → Verificar que usa o database.py existente (Supabase client)
3.9  [ ] POST /confirmar usa o VALOR_TOTAL da nota, não soma dos itens
         → Buscar o campo valor_total do documento MongoDB, não somar itens[].valor_total_item
3.10 [ ] POST /confirmar atualiza o MongoDB: status_integracao = "confirmado"
         e salva o transacao_supabase_id retornado
3.11 [ ] DELETE /api/v1/compras/{compra_id} existe
3.12 [ ] DELETE atualiza MongoDB: status_integracao = "cancelado" (NÃO deleta o documento)
3.13 [ ] PATCH /api/v1/compras/feedback existe e aceita FeedbackItemRequest
3.14 [ ] GET /api/v1/compras/feedback-pendente existe
3.15 [ ] GET /feedback-pendente filtra itens onde data_feedback_estimada ≤ now()
         AND status_consumo = "ativo"
3.16 [ ] GET /api/v1/compras/planejar existe e aceita familia_id + dias como query params
```

### BLOCO 4 — Regras de Negócio Críticas (12 itens)

```
4.1  [ ] COMPRA_NAO_E_DESPESA: O endpoint POST /ingestao NÃO faz INSERT na tabela
         transacoes do Supabase. Apenas salva no MongoDB com status "pendente".
         → Buscar qualquer chamada a db.table("transacoes") dentro do fluxo de ingestão.
         Se existir, é FAIL crítico.
4.2  [ ] TRIGGER_IS_LAW: Em NENHUM arquivo do módulo ia_compras/ existe código que faça:
         - UPDATE direto no saldo_atual de envelopes
         - UPDATE direto no valor_total_disponivel de saldo_geral
         - Qualquer cálculo tipo "saldo = saldo - valor"
         → Grep por: "saldo_atual", "valor_total_disponivel", "saldo_geral" em contexto de UPDATE
4.3  [ ] VALOR_DA_NOTA: No POST /confirmar, o campo "valor" enviado ao POST /transacoes
         vem do campo valor_total do documento MongoDB, NÃO de sum(itens.valor_total_item)
4.4  [ ] MONGO_ISOLADO: Nenhuma query no MongoDB é usada para derivar ou calcular saldos.
         MongoDB é leitura documental apenas. Saldo sempre vem do Supabase.
4.5  [ ] CATEGORIA_ENUM_ONLY: O campo categoria nos itens extraídos usa o tipo
         CategoriaItem (Enum), não str livre. Verificar no agente_extrator.py se o
         schema passado ao LangExtract contém o enum.
4.6  [ ] FALLBACK_OBRIGATORIO: agente_extrator.py chama circuit_breaker.py ao invés
         de chamar Ollama diretamente. Verificar que NÃO existe chamada direta
         a httpx/requests para o endpoint Ollama fora do circuit_breaker.
4.7  [ ] O circuit_breaker.py tem timeout de EXATAMENTE 5 segundos para Ollama
4.8  [ ] O circuit_breaker.py faz fallback para Gemini Flash (Google AI Studio)
         quando Ollama falha (timeout, connection error, ou HTTP error)
4.9  [ ] O DELETE de compra NÃO deleta documentos do MongoDB — apenas muda status
4.10 [ ] A descricao da transação enviada ao Supabase contém o nome do supermercado
         (ex: "Atacadão — 15 itens"), não um texto genérico
4.11 [ ] O POST /confirmar envia familia_id junto com a transação ao Supabase
4.12 [ ] O POST /confirmar envia usuario_id junto com a transação ao Supabase
```

### BLOCO 5 — MongoDB e Modelagem Documental (10 itens)

```
5.1  [ ] mongo_client.py implementa um singleton (não cria conexão a cada chamada)
5.2  [ ] A coleção historico_compras é usada com os campos obrigatórios:
         compra_id, familia_id, data_compra, supermercado, valor_total,
         qr_code_url, status_integracao, transacao_supabase_id, itens[]
5.3  [ ] Cada item no array itens[] tem os campos:
         nome_original, nome_padronizado, produto_ref_id, categoria,
         quantidade, unidade, valor_unitario, valor_total_item,
         status_consumo, data_feedback_estimada
5.4  [ ] data_feedback_estimada é calculado usando shelf_life.py
         (não é hardcoded ou arbitrário)
5.5  [ ] A coleção dicionario_produtos é utilizada no agente_extrator.py
         para buscar/criar entradas canônicas
5.6  [ ] O dicionario_produtos tem campos: nome_canonico, categoria,
         sinonimos_llm (array), preco_medio, unidade_padrao
5.7  [ ] Quando o extrator encontra um produto novo, ele cria uma entrada
         no dicionario_produtos (não apenas ignora)
5.8  [ ] Quando o extrator encontra um produto existente, ele atualiza
         preco_medio com o valor da nota mais recente
5.9  [ ] A coleção perfil_familia é lida pelo agente_orquestrador.py
         para injeção no prompt (NÃO via ChromaDB/vector DB)
5.10 [ ] Verificar que NÃO existe import ou referência a chromadb,
         chroma, milvus, pinecone ou qualquer vector DB em nenhum arquivo
```

### BLOCO 6 — Shelf Life e Feedback Loop (8 itens)

```
6.1  [ ] shelf_life.py contém o dicionário SHELF_LIFE mapeando CategoriaItem → timedelta
6.2  [ ] Os valores de timedelta são coerentes com a SPEC:
         Hortifrúti ≈ 5-7 dias, Padaria ≈ 5 dias, Laticínios ≈ 14 dias,
         Proteínas ≈ 7 dias, Congelados ≈ 45 dias, Grãos ≈ 45 dias
6.3  [ ] A função calcular_data_feedback(data_compra, categoria) existe
6.4  [ ] calcular_data_feedback é chamada durante a ingestão (agente_extrator
         ou router) para preencher data_feedback_estimada em cada item
6.5  [ ] GET /feedback-pendente faz query filtrando por data_feedback_estimada ≤ now()
6.6  [ ] GET /feedback-pendente filtra TAMBÉM por status_consumo = "ativo"
         (não retorna itens já marcados como "acabou" ou "estragou")
6.7  [ ] GET /feedback-pendente filtra por familia_id (isolamento multi-família)
6.8  [ ] PATCH /feedback atualiza o campo status_consumo do item correto
         dentro do array itens[] no MongoDB (não cria documento novo)
```

### BLOCO 7 — Pipeline Multi-Agente (7 itens)

```
7.1  [ ] agente_estoque.py consulta o MongoDB (historico_compras) para calcular
         quais itens estão "acabou" ou próximos de acabar
7.2  [ ] agente_orcamento.py consulta o Supabase (envelopes) para obter
         saldo_atual do envelope de mercado/supermercado
7.3  [ ] agente_orcamento.py usa o database.py existente (Supabase client),
         NÃO cria uma conexão Supabase própria
7.4  [ ] agente_orquestrador.py injeta o perfil_familia como contexto no prompt
         do Google AI Studio (não usa vector DB)
7.5  [ ] agente_orquestrador.py recebe output dos 3 agentes (estoque, orçamento,
         nutricionista) e gera a lista final
7.6  [ ] A lista gerada contém campo corte_sugerido: true em itens que
         excedem o orçamento disponível
7.7  [ ] A lista gerada contém campo dentro_do_orcamento (bool) comparando
         custo_estimado_total vs saldo_envelope
```

---

## FORMATO DO RELATÓRIO

Após auditar todos os 75 itens, gere o relatório neste formato exato:

```
# RELATÓRIO DE AUDITORIA — SPEC-18
Data: [data atual]
Commit/Branch: [se disponível]

## RESUMO
- Total de verificações: 75
- ✅ PASS: [N]
- ❌ FAIL: [N]
- ⚠️ PARCIAL: [N]
- Taxa de conformidade: [N]%

## FAILS CRÍTICOS (bloqueia deploy)
[Listar apenas os FAILs dos Blocos 4 e 3 — regras de negócio e API]

| # | Item | Arquivo | Linha | Problema |
|---|------|---------|-------|----------|
| 4.1 | COMPRA_NAO_E_DESPESA | router.py | 45 | POST /ingestao faz INSERT em transacoes |

## FAILS NÃO-CRÍTICOS
[Listar FAILs dos outros blocos]

| # | Item | Arquivo | Linha | Problema |
|---|------|---------|-------|----------|

## PARCIAIS
[Listar itens parcialmente atendidos]

| # | Item | Arquivo | O que falta |
|---|------|---------|-------------|

## PASSES (resumido)
[Apenas listar os números dos itens que passaram, agrupados por bloco]
Bloco 1: 1.1, 1.2, 1.3, ...
Bloco 2: 2.1, 2.2, ...

## VEREDITO FINAL
[ ] APROVADO PARA DEPLOY — 100% conformidade
[ ] REPROVADO — [N] fails críticos encontrados
[ ] APROVADO COM RESSALVAS — [N] itens parciais, nenhum fail crítico
```

---

## REGRAS PARA O AUDITOR

1. **Leia os arquivos antes de julgar.** Não assuma que algo existe — abra e verifique.
2. **Conte linhas reais.** `wc -l arquivo.py` para verificar NO_GOD_FILES.
3. **Grep é seu amigo.** Use `grep -rn "saldo_atual" ia_compras/` para verificar violações.
4. **Não invente passes.** Se um arquivo não existe, todos os itens relacionados são FAIL.
5. **Seja literal.** Se a SPEC diz "timeout de 5 segundos" e o código usa 10, é FAIL.
6. **Não sugira fixes.** Apenas reporte. O fix é responsabilidade do implementador.
7. **Separe opinião de fato.** Se algo funciona mas está diferente da SPEC, é FAIL na auditoria
   mesmo que a alternativa seja "melhor". A SPEC é o contrato.
