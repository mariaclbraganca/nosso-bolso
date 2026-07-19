# SPEC-13 — Cores Dinamicas por Usuario

**Prioridade:** Baixa (Quick fix)
**Esforco:** Trivial
**Status:** Planejado

---

## Problema

Em `top_expenses_card.dart:23`, as cores dos usuarios estao hardcoded:
```dart
final userColors = {'Arua': Color(...), 'Alan': Color(...), 'Alanna': Color(...)};
```
Se um novo usuario entrar na familia, nao tera cor atribuida.

## Solucao

Gerar cor deterministicamente a partir do hash do nome:

```dart
Color corDoUsuario(String nome) {
    final hash = nome.hashCode;
    final hue = (hash % 360).abs().toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.5).toColor();
}
```

Ou usar paleta pre-definida com indice ciclico:

```dart
const _paleta = [
    Color(0xFF8DC65B), // verde
    Color(0xFF60A5FA), // azul
    Color(0xFFA78BFA), // roxo
    Color(0xFFFF9800), // laranja
    Color(0xFFEF4444), // vermelho
    Color(0xFF06B6D4), // ciano
    Color(0xFFF472B6), // rosa
];

Color corDoUsuario(String nome, List<String> todosNomes) {
    final index = todosNomes.indexOf(nome) % _paleta.length;
    return _paleta[index];
}
```

---

## Criterios de Aceite

- [ ] Qualquer usuario novo recebe cor automaticamente
- [ ] Cores sao consistentes entre telas (mesmo usuario = mesma cor)
- [ ] Remover mapa hardcoded

---

## Arquivos Afetados

| Arquivo | Alteracao |
|---------|-----------|
| `envelope-flutter/lib/widgets/relatorios/top_expenses_card.dart` | Remover hardcoded, usar funcao |
| `envelope-flutter/lib/widgets/relatorios/user_spending_bars.dart` | Usar mesma funcao |
| Nova ou em `app_theme.dart`: funcao `corDoUsuario()` | Logica reutilizavel |
