# SPEC-16 — Widget para Home Screen

**Prioridade:** Baixa (Mes 3)
**Esforco:** Medio
**Status:** Planejado

---

## Problema

Para ver o saldo, o usuario precisa abrir o app. Um widget na home screen mostraria informacoes rapidas.

## Solucao

### Android — `home_widget` package

Widget mostrando:
- Saldo geral disponivel
- Top 3 envelopes com saldo e barra de progresso
- Ultima transacao registrada
- Tap abre o app

### iOS — WidgetKit

Mesmo conteudo, usando `home_widget` que abstrai ambas plataformas.

### Atualizacao

- Atualizar a cada 30 minutos via background fetch
- Atualizar imediatamente apos registrar transacao

---

## Dependencias

- `home_widget` no pubspec.yaml
- Configuracao nativa Android (AppWidgetProvider) e iOS (WidgetKit)

---

## Arquivos Afetados

| Arquivo | Alteracao |
|---------|-----------|
| `envelope-flutter/pubspec.yaml` | Adicionar home_widget |
| `envelope-flutter/android/app/src/main/` | AppWidgetProvider XML + layout |
| `envelope-flutter/ios/` | WidgetKit extension |
| Nova: `envelope-flutter/lib/services/widget_service.dart` | Atualizar dados do widget |
