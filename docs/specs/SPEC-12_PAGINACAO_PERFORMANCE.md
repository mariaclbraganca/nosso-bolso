# SPEC-12 — Paginacao e Performance

**Prioridade:** Alta (Semana 1)
**Esforco:** Baixo
**Status:** Planejado

---

## Problema

O extrato carrega todas as transacoes de uma vez na memoria via StreamProvider. Com 1.000+ transacoes, o app vai travar.

## Solucao

### 1. Scroll infinito no Extrato

O backend ja suporta `page` e `limit`. O Flutter precisa implementar scroll infinito:

```dart
class ExtratoScreen extends ConsumerStatefulWidget {
    // ScrollController que detecta quando chega ao final
    // Carrega proxima pagina automaticamente
    // Indicador de loading no final da lista
}
```

**Logica:**
```dart
final _scrollController = ScrollController();
int _currentPage = 1;
bool _hasMore = true;
List<Map> _transacoes = [];

@override
void initState() {
    super.initState();
    _scrollController.addListener(() {
        if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
            _loadMore();
        }
    });
}

Future<void> _loadMore() async {
    if (!_hasMore) return;
    _currentPage++;
    final novas = await _fetchPage(_currentPage);
    if (novas.length < 30) _hasMore = false;
    setState(() => _transacoes.addAll(novas));
}
```

### 2. Skeleton loading

Enquanto a primeira pagina carrega, mostrar skeleton placeholders:
- 5-6 retangulos cinza pulsando (shimmer effect)
- Usar package `shimmer`

### 3. Cache local

Usar `shared_preferences` ou `hive` para cachear a ultima pagina do extrato. Ao abrir o app, mostrar cache enquanto busca dados novos.

### 4. Lazy loading no Dashboard

O dashboard carrega todos os widgets simultaneamente. Priorizar:
1. Header + saldo (carregar primeiro)
2. Grid de envelopes (carregar segundo)
3. Cards de analytics (carregar por ultimo, com skeleton)

---

## Criterios de Aceite

- [ ] Extrato carrega 30 itens por vez
- [ ] Scroll infinito carrega proxima pagina automaticamente
- [ ] Skeleton loading visivel enquanto carrega
- [ ] App nao trava com 1.000+ transacoes
- [ ] Dashboard carrega progressivamente

---

## Arquivos Afetados

| Arquivo | Alteracao |
|---------|-----------|
| `envelope-flutter/lib/screens/extrato_screen.dart` | Scroll infinito + paginacao |
| `envelope-flutter/lib/screens/dashboard_screen.dart` | Lazy loading |
| `envelope-flutter/pubspec.yaml` | Adicionar shimmer (opcional) |
