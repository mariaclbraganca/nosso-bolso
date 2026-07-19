# SPEC-07 — Exportar Relatorios (PDF e CSV)

**Prioridade:** Media (Semana 3)
**Esforco:** Medio
**Status:** Planejado

---

## Problema

Nao existe forma de compartilhar dados financeiros com contador, conjuge, ou para backup pessoal.

## Solucao

### 1. Exportar CSV (Backend)

**Endpoint:**
```
GET /transacoes/export?familia_id=<uuid>&mes=2026-04&format=csv
```

**Implementacao:**
```python
import csv, io
from fastapi.responses import StreamingResponse

@router.get("/export")
def exportar_transacoes(familia_id: str, mes: str = None, format: str = "csv"):
    db = get_supabase()
    query = db.table("transacoes") \
        .select("data, tipo, valor, descricao, usuarios(nome), envelopes(nome_envelope)") \
        .eq("familia_id", familia_id) \
        .order("data", desc=True)

    if mes:
        import calendar
        year, month = int(mes[:4]), int(mes[5:7])
        last_day = calendar.monthrange(year, month)[1]
        query = query.gte("data", f"{mes}-01").lte("data", f"{mes}-{last_day:02d}")

    txs = query.execute().data

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["Data", "Tipo", "Valor", "Descricao", "Usuario", "Envelope"])
    for t in txs:
        writer.writerow([
            t["data"], t["tipo"], t["valor"],
            t.get("descricao", ""),
            t["usuarios"]["nome"] if t.get("usuarios") else "",
            t["envelopes"]["nome_envelope"] if t.get("envelopes") else "",
        ])

    output.seek(0)
    filename = f"extrato_{mes or 'completo'}.csv"
    return StreamingResponse(
        output, media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )
```

### 2. Exportar PDF (Backend)

Usar biblioteca `reportlab` ou `weasyprint`:

```
GET /transacoes/export?familia_id=<uuid>&mes=2026-04&format=pdf
```

Conteudo do PDF:
- Cabecalho: "Extrato Financeiro — Abril 2026 — Familia Silva"
- Resumo: Total receitas, total despesas, saldo
- Tabela de transacoes com colunas formatadas
- Rodape com data de geracao

### 3. Flutter — Botao de exportar

**Na tela de Relatorios (`RelatoriosScreen`):**
- Botao "Exportar" no AppBar
- BottomSheet com opcoes: CSV / PDF
- Ao gerar, usar `share_plus` para compartilhar via WhatsApp, email, etc.

**Na tela de Extrato (`ExtratoScreen`):**
- Icone de download no AppBar
- Exporta o extrato filtrado atual

```dart
// Usando share_plus
final response = await http.get(Uri.parse('$BASE/transacoes/export?...&format=pdf'));
final tempDir = await getTemporaryDirectory();
final file = File('${tempDir.path}/extrato.pdf');
await file.writeAsBytes(response.bodyBytes);
Share.shareXFiles([XFile(file.path)], text: 'Extrato Abril 2026');
```

---

## Criterios de Aceite

- [ ] CSV gerado com encoding UTF-8 (acentos corretos)
- [ ] PDF formatado com cabecalho, resumo e tabela
- [ ] Filtro por mes funciona no export
- [ ] Compartilhamento via WhatsApp/email funciona no Flutter
- [ ] Arquivo nomeado com mes (ex: `extrato_2026-04.csv`)

---

## Dependencias

- `reportlab` ou `weasyprint` no requirements.txt (para PDF)
- `share_plus` no pubspec.yaml
- `path_provider` no pubspec.yaml

---

## Arquivos Afetados

| Arquivo | Alteracao |
|---------|-----------|
| `envelope-api/routes/transacoes.py` | Adicionar `GET /export` |
| `envelope-api/requirements.txt` | Adicionar reportlab |
| `envelope-flutter/pubspec.yaml` | Adicionar share_plus, path_provider |
| `envelope-flutter/lib/screens/relatorios_screen.dart` | Botao exportar |
| `envelope-flutter/lib/screens/extrato_screen.dart` | Icone download |
