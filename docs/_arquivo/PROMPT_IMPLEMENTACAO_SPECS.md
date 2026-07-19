# PROMPT MESTRE — IMPLEMENTACAO DE TODAS AS SPECS

---

Voce e um engenheiro fullstack senior. Sua missao e implementar **todas as 17 specs** do app "Nosso Bolso" (Envelope Financial App), na ordem de prioridade definida abaixo.

---

## CONTEXTO DO SISTEMA

Antes de comecar, leia estes arquivos obrigatoriamente:

1. `AGENTS.md` — Regras absolutas (TRIGGER_IS_LAW, FAMILIA_REQUIRED, etc.)
2. `docs/ARQUITETURA.md` — Visao geral da stack, modelo de dados, triggers
3. `docs/ROADMAP.md` — Indice de todas as specs com prioridades
4. `ENVELOPE_APP_GUIDE_v2.md` — Guia tecnico completo do estado atual

**Stack:**
- Backend: FastAPI + Python 3.12 (`envelope-api/`)
- Frontend: Flutter + Riverpod (`envelope-flutter/lib/`)
- Banco: Supabase PostgreSQL (triggers, RLS, Realtime)
- Auth: Supabase Auth (email/senha + Google OAuth)

**Regras inviolaveis:**
- Nunca calcule saldo em Python ou Dart — apenas insira em `transacoes`, o trigger cuida do resto
- Toda query deve filtrar por `familia_id` (o backend usa service role key, bypassa RLS)
- Nenhum arquivo pode exceder 200 linhas — quebre em modulos
- `usuario_id` obrigatorio em toda transacao
- Receita nunca tem `envelope_id`
- Gastos fixos nunca passam pela tabela `transacoes`
- Use `StreamProvider` para dados reativos, nunca `setState` para saldos
- Use `calendar.monthrange()` para ultimo dia do mes, nunca hardcode dia 31

---

## ORDEM DE EXECUCAO

Execute na sequencia abaixo. Cada fase depende da anterior. Ao concluir cada spec, marque como concluida e siga para a proxima.

---

### FASE 0 — PREPARACAO (antes de tudo)

**0.1 Ler e entender o estado atual:**
- Ler todos os arquivos em `envelope-api/routes/` (transacoes.py, envelopes.py, dashboard.py, abastecer.py, fixos.py)
- Ler `envelope-api/models.py`
- Ler todos os providers em `envelope-flutter/lib/providers/`
- Ler todas as telas em `envelope-flutter/lib/screens/`
- Ler todos os widgets em `envelope-flutter/lib/widgets/`

**0.2 Remover debug prints:**
- Em `envelope-flutter/lib/main.dart`, remover linhas com `print('DEBUG:...')`

**0.3 Validar que o servidor inicia:**
```bash
cd envelope-api && uvicorn main:app --port 8000
curl http://localhost:8000/  # deve retornar {"status":"ok"}
```

---

### FASE 1 — ESSENCIAIS (implementar primeiro)

---

#### SPEC-02: Isolamento API por Familia
**Arquivo de spec:** `docs/specs/SPEC-02_ISOLAMENTO_API_FAMILIA.md`

**O que fazer:**
1. Em `envelope-api/routes/envelopes.py`:
   - `GET /` — adicionar parametro obrigatorio `familia_id: str`, filtrar com `.eq("familia_id", familia_id)`
   - `POST /` — incluir `familia_id` no payload do insert (receber via body ou query)

2. Em `envelope-api/routes/transacoes.py`:
   - `GET /extrato` — adicionar parametro `familia_id: str`, filtrar com `.eq("familia_id", familia_id)`

3. Em `envelope-api/routes/fixos.py`:
   - `GET /` — adicionar parametro `familia_id: str`
   - `POST /` — garantir que `familia_id` esta no insert

4. Verificar `envelope-api/routes/abastecer.py` — o trigger ja injeta `familia_id`, mas confirmar

**Teste:**
```bash
# Sem familia_id deve retornar 422
curl http://localhost:8000/envelopes/
# Com familia_id deve retornar apenas envelopes da familia
curl "http://localhost:8000/envelopes/?familia_id=798bfc69-a6e9-4173-a156-cffa8fcb76c3"
```

---

#### SPEC-01: Editar Transacoes, Envelopes e Fixos
**Arquivo de spec:** `docs/specs/SPEC-01_EDITAR_TRANSACOES_ENVELOPES.md`

**O que fazer — Backend:**

1. Em `envelope-api/models.py`, adicionar:
```python
class TransacaoUpdate(BaseModel):
    valor: Optional[float] = None
    descricao: Optional[str] = None
    envelope_id: Optional[UUID] = None

    @field_validator('valor')
    @classmethod
    def valor_positivo(cls, v):
        if v is not None and v <= 0:
            raise ValueError('valor deve ser maior que zero')
        return v

class EnvelopeUpdate(BaseModel):
    nome_envelope: Optional[str] = None
    valor_planejado: Optional[float] = None
    emoji: Optional[str] = None
    cor: Optional[str] = None

    @field_validator('valor_planejado')
    @classmethod
    def valor_positivo(cls, v):
        if v is not None and v <= 0:
            raise ValueError('valor_planejado deve ser maior que zero')
        return v
```

2. Em `envelope-api/routes/transacoes.py`, adicionar:
```python
@router.put("/{transacao_id}")
def editar_transacao(transacao_id: str, payload: TransacaoUpdate):
    db = get_supabase()
    data = {k: v for k, v in payload.model_dump().items() if v is not None}
    if 'envelope_id' in data:
        data['envelope_id'] = str(data['envelope_id'])
    result = db.table("transacoes").update(data).eq("id", transacao_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Transacao nao encontrada")
    return result.data[0]
```

3. Em `envelope-api/routes/envelopes.py`, adicionar:
```python
@router.put("/{envelope_id}")
def editar_envelope(envelope_id: str, payload: EnvelopeUpdate):
    # Atualizar apenas campos nao-nulos
    # NAO atualizar saldo_atual

@router.delete("/{envelope_id}")
def deletar_envelope(envelope_id: str):
    # Verificar se tem transacoes vinculadas
    # Se sim: 409 Conflict
    # Se nao: deletar
```

4. Em `envelope-api/routes/fixos.py`, expandir o PATCH para aceitar `nome` e `valor` alem de `pago`:
```python
class GastoFixoUpdate(BaseModel):
    pago: Optional[bool] = None
    nome: Optional[str] = None
    valor: Optional[float] = None
```

**O que fazer — Flutter:**

5. Criar `envelope-flutter/lib/screens/edit_transacao_sheet.dart`:
   - Campos pre-preenchidos com valores atuais
   - Salvar via `PUT /transacoes/{id}`

6. Modificar `envelope-flutter/lib/screens/form_envelope_sheet.dart`:
   - Aceitar parametro opcional `envelope` para modo edicao
   - Se envelope != null: pre-preencher campos, trocar titulo para "Editar Envelope"
   - Salvar via `PUT /envelopes/{id}` em vez de `POST`

7. Modificar `envelope-flutter/lib/screens/form_fixo_sheet.dart`:
   - Mesmo padrao: aceitar modo edicao

8. Em `extrato_screen.dart`: ao tocar na transacao, abrir `EditTransacaoSheet`
9. Em `envelope_detail_sheet.dart`: adicionar botao "Editar" que abre `FormEnvelopeSheet` em modo edicao
10. Em `fixos_screen.dart`: ao tocar no fixo, abrir `FormFixoSheet` em modo edicao

**Teste:**
```bash
# Editar transacao
curl -X PUT http://localhost:8000/transacoes/{id} -H "Content-Type: application/json" -d '{"valor": 150, "descricao": "Corrigido"}'
# Editar envelope
curl -X PUT http://localhost:8000/envelopes/{id} -H "Content-Type: application/json" -d '{"valor_planejado": 1000}'
# Deletar envelope sem transacoes
curl -X DELETE http://localhost:8000/envelopes/{id}  # 200
# Deletar envelope com transacoes
curl -X DELETE http://localhost:8000/envelopes/{id}  # 409
```

---

#### SPEC-03: Busca e Filtros Avancados
**Arquivo de spec:** `docs/specs/SPEC-03_BUSCA_TRANSACOES.md`

**O que fazer — Backend:**

1. Em `envelope-api/routes/transacoes.py`, no endpoint `GET /extrato`, adicionar parametros:
   - `q: str = None` — busca por descricao (ilike)
   - `valor_min: float = None` — filtro valor minimo
   - `valor_max: float = None` — filtro valor maximo
   - `data_inicio: str = None` — filtro data inicio
   - `data_fim: str = None` — filtro data fim

```python
if q:           query = query.ilike("descricao", f"%{q}%")
if valor_min:   query = query.gte("valor", valor_min)
if valor_max:   query = query.lte("valor", valor_max)
if data_inicio: query = query.gte("data", data_inicio)
if data_fim:    query = query.lte("data", data_fim)
```

Manter compatibilidade com `mes` (se `mes` vier, calcular `data_inicio` e `data_fim` automaticamente).

**O que fazer — Flutter:**

2. Em `extrato_screen.dart`: adicionar `SearchBar` no topo com debounce de 500ms
3. Criar `envelope-flutter/lib/widgets/filter_panel.dart`: painel com chips de tipo, dropdown de usuario/envelope, range slider de valor, date range picker

**Teste:**
```bash
curl "http://localhost:8000/transacoes/extrato?familia_id=XXX&q=mercado&valor_min=50&valor_max=500"
```

---

#### SPEC-12: Paginacao e Performance
**Arquivo de spec:** `docs/specs/SPEC-12_PAGINACAO_PERFORMANCE.md`

**O que fazer — Flutter:**

1. Em `extrato_screen.dart`: implementar scroll infinito com `ScrollController`
   - Carregar 30 itens por pagina
   - Ao chegar perto do final (200px), carregar proxima pagina
   - Mostrar `CircularProgressIndicator` no final enquanto carrega
   - Variavel `_hasMore` para parar quando acabar

2. O backend ja suporta `page` e `limit` — apenas usar no Flutter

---

#### SPEC-13: Cores Dinamicas
**Arquivo de spec:** `docs/specs/SPEC-13_CORES_DINAMICAS_USUARIOS.md`

**O que fazer:**

1. Em `envelope-flutter/lib/theme/app_theme.dart` (ou arquivo dedicado), criar funcao:
```dart
Color corDoUsuario(String nome, List<String> todosNomes) {
    const paleta = [
        Color(0xFF8DC65B), Color(0xFF60A5FA), Color(0xFFA78BFA),
        Color(0xFFFF9800), Color(0xFFEF4444), Color(0xFF06B6D4), Color(0xFFF472B6),
    ];
    final index = todosNomes.indexOf(nome) % paleta.length;
    return paleta[index];
}
```

2. Em `widgets/relatorios/top_expenses_card.dart`: remover mapa hardcoded, usar `corDoUsuario()`
3. Em `widgets/relatorios/user_spending_bars.dart`: usar mesma funcao

---

### FASE 2 — FUNCIONALIDADES (implementar depois da Fase 1)

---

#### SPEC-04: Gastos Fixos Recorrentes
**Arquivo de spec:** `docs/specs/SPEC-04_FIXOS_RECORRENTES.md`

**O que fazer:**

1. **SQL no Supabase:**
```sql
ALTER TABLE public.gastos_fixos
ADD COLUMN recorrente boolean DEFAULT false,
ADD COLUMN dia_vencimento integer DEFAULT 1 CHECK (dia_vencimento BETWEEN 1 AND 31);
```

2. **Backend:** Atualizar `GastoFixoCreate` com campos `recorrente` e `dia_vencimento`. Adicionar endpoint `POST /fixos/recorrer` que clona fixos recorrentes do mes anterior.

3. **Flutter:** No `form_fixo_sheet.dart`, adicionar toggle "Repetir todo mes" e campo "Dia do vencimento". No `fixos_screen.dart`, ao navegar para mes vazio, mostrar dialog oferecendo clonar fixos recorrentes.

---

#### SPEC-05: Transferencia entre Envelopes
**Arquivo de spec:** `docs/specs/SPEC-05_TRANSFERENCIA_ENTRE_ENVELOPES.md`

**O que fazer:**

1. **Backend:** Em `envelope-api/routes/envelopes.py`, adicionar `POST /transferir`. Criar modelo `TransferenciaEnvelope` com `origem_id`, `destino_id`, `valor`, `usuario_id`. Implementar debito na origem e credito no destino SEM afetar `saldo_geral`.

2. **Flutter:** Criar `transferir_sheet.dart` com dropdowns de origem/destino, campo de valor. Adicionar como 4a opcao no `speed_dial_fab.dart` ou botao dentro de `envelope_detail_sheet.dart`.

---

#### SPEC-07: Exportar PDF/CSV
**Arquivo de spec:** `docs/specs/SPEC-07_EXPORTAR_PDF_CSV.md`

**O que fazer:**

1. **Backend:** Em `transacoes.py`, adicionar `GET /export` com `format=csv` ou `format=pdf`. CSV via modulo `csv` nativo. PDF via `reportlab`. Retornar `StreamingResponse` com header de download.

2. **Flutter:** Adicionar `share_plus` e `path_provider` no pubspec.yaml. Botao "Exportar" no AppBar de `relatorios_screen.dart` e `extrato_screen.dart`. Baixar arquivo e abrir sheet de compartilhamento nativo.

---

#### SPEC-09: Historico Comparativo
**Arquivo de spec:** `docs/specs/SPEC-09_HISTORICO_COMPARATIVO.md`

**O que fazer:**

1. **Backend:** Em `dashboard.py`, adicionar `GET /historico?familia_id=&meses=6` (agregado mensal) e `GET /comparacao-envelopes?familia_id=&mes1=&mes2=` (comparacao lado a lado).

2. **Flutter:** Em `relatorios_screen.dart`, adicionar graficos de evolucao mensal (barras empilhadas) e card de comparacao entre meses. Usar `fl_chart` `BarChart`.

---

### FASE 3 — EXPERIENCIA (implementar depois da Fase 2)

---

#### SPEC-06: Notificacoes Push
**Arquivo de spec:** `docs/specs/SPEC-06_NOTIFICACOES_PUSH.md`

**O que fazer:**
1. SQL: `ALTER TABLE usuarios ADD COLUMN fcm_token text`
2. Backend: Criar `notifications.py` com Firebase Admin SDK. Chamar apos inserir transacao que coloca envelope abaixo de 20%.
3. Flutter: Adicionar `firebase_messaging` no pubspec.yaml. Salvar token no banco ao logar. Configurar handlers para foreground/background.

---

#### SPEC-08: Metas de Economia
**Arquivo de spec:** `docs/specs/SPEC-08_METAS_ECONOMIA.md`

**O que fazer:**
1. SQL: Criar tabela `metas` (id, nome, valor_alvo, valor_atual, emoji, cor, prazo, familia_id)
2. Backend: Criar `routes/metas.py` com CRUD + `POST /{id}/contribuir`
3. Flutter: Criar `metas_screen.dart`, `form_meta_sheet.dart`, `metas_provider.dart`. Card resumo no dashboard.

---

#### SPEC-10: Wizard de Onboarding
**Arquivo de spec:** `docs/specs/SPEC-10_ONBOARDING_WIZARD.md`

**O que fazer:**
1. SQL: `ALTER TABLE usuarios ADD COLUMN onboarding_completo boolean DEFAULT false`
2. Flutter: Criar `onboarding_wizard_screen.dart` com PageView de 4 passos (criar envelopes → registrar receita → distribuir → pronto). Redirecionar para wizard se flag for false.

---

#### SPEC-11: Soft Delete com Lixeira
**Arquivo de spec:** `docs/specs/SPEC-11_SOFT_DELETE_LIXEIRA.md`

**O que fazer:**
1. SQL: `ALTER TABLE transacoes ADD COLUMN deleted_at timestamptz DEFAULT NULL`
2. Backend: Alterar DELETE para fazer UPDATE de `deleted_at`. Adicionar `GET /lixeira` e `POST /{id}/restaurar`. Filtrar `deleted_at IS NULL` em todas as queries.
3. Flutter: Criar `lixeira_screen.dart`. Acessivel via menu no extrato.

---

### FASE 4 — DIFERENCIADORES (implementar por ultimo)

---

#### SPEC-14: Foto de Comprovante
**Arquivo de spec:** `docs/specs/SPEC-14_FOTO_COMPROVANTE.md`

Criar bucket `comprovantes` no Supabase Storage. Adicionar campo `comprovante_url` na tabela `transacoes`. No Flutter, usar `image_picker` para capturar foto, comprimir com `flutter_image_compress`, fazer upload, salvar URL. Mostrar icone de clipe nas transacoes com foto.

---

#### SPEC-15: Permissoes por Membro
**Arquivo de spec:** `docs/specs/SPEC-15_PERMISSOES_FAMILIA.md`

Adicionar campo `role` (admin/membro/visualizador) em `usuarios`. Criar middleware de verificacao no backend. Esconder/mostrar botoes no Flutter baseado no role.

---

#### SPEC-16: Widget Home Screen
**Arquivo de spec:** `docs/specs/SPEC-16_WIDGET_HOME_SCREEN.md`

Usar package `home_widget` para criar widget Android/iOS mostrando saldo geral e top 3 envelopes.

---

#### SPEC-17: Orcamento Inteligente (IA)
**Arquivo de spec:** `docs/specs/SPEC-17_IA_ORCAMENTO_INTELIGENTE.md`

Criar `GET /dashboard/insights` com sugestao de orcamento (media 3 meses), previsao de fim de mes (regressao linear), e deteccao de anomalias (gastos > 3x media). Calculos em Python puro, sem APIs externas.

---

## REGRAS DE IMPLEMENTACAO

### Ao implementar cada spec:

1. **Leia a spec completa** antes de comecar (`docs/specs/SPEC-XX_*.md`)
2. **Leia os arquivos afetados** listados na tabela de cada spec
3. **Implemente backend primeiro**, teste com curl, depois implemente frontend
4. **Nao quebre funcionalidades existentes** — rode os testes apos cada mudanca
5. **Maximo 200 linhas por arquivo** — quebre em modulos se necessario
6. **Nao adicione features extras** alem do que a spec pede
7. **Use os nomes de funcoes/classes exatamente como definidos** na spec

### Ao concluir cada spec:

1. Testar todos os endpoints novos/modificados com curl
2. Verificar que os endpoints existentes continuam funcionando
3. Confirmar que nenhum arquivo ultrapassou 200 linhas
4. Confirmar que `familia_id` esta sendo filtrado em todas as queries

### Teste de sanidade entre fases:

```bash
# Deve continuar funcionando apos cada fase:
curl http://localhost:8000/                                    # health check
curl "http://localhost:8000/envelopes/?familia_id=XXX"         # listar envelopes
curl -X POST http://localhost:8000/transacoes/ -H "..." -d '...' # criar despesa
curl "http://localhost:8000/transacoes/extrato?familia_id=XXX" # extrato
curl "http://localhost:8000/dashboard/stats?familia_id=XXX"    # dashboard
curl "http://localhost:8000/fixos/?familia_id=XXX&mes=2026-04" # fixos
```

---

## CHECKLIST FINAL

Ao terminar todas as 17 specs, verificar:

- [ ] Todos os endpoints filtram por `familia_id`
- [ ] Nenhum arquivo ultrapassa 200 linhas
- [ ] Nenhum calculo de saldo fora do trigger
- [ ] Todos os novos modelos Pydantic tem validacao
- [ ] Todos os DELETE retornam 404 para IDs inexistentes
- [ ] Nenhum `print('DEBUG')` restante no Flutter
- [ ] Todos os novos providers usam `StreamProvider` ou `FutureProvider`
- [ ] Todos os novos endpoints tem testes via curl documentados
- [ ] `docs/ROADMAP.md` atualizado com status de cada spec

---

## DADOS PARA TESTES

```
FAMILIA_ID = "798bfc69-a6e9-4173-a156-cffa8fcb76c3"
USR_A (Alan) = "c8648c09-53d3-46cb-94d9-c8a4c819b827"
USR_B (Alanna) = "238f37f6-747e-472e-a518-ac59eb63607d"
ENV_LAZER = "22a27aa1-d868-40cd-b041-ebd59ec4fd54"
ENV_SAUDE = "7f719cfb-68e6-40b0-a067-f78d4184a298"
ENV_ALIMENTACAO = "4a8107c1-b154-4896-bba2-d95ff2c9e535"
BASE_URL = "http://localhost:8000"
```
