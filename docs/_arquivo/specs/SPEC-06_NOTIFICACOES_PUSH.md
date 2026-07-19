# SPEC-06 — Notificacoes Push e Alertas

**Prioridade:** Media (Mes 2)
**Esforco:** Alto
**Status:** Planejado

---

## Problema

O `AlertBanner` so aparece quando o app esta aberto. O usuario nao sabe que estourou um envelope ate abrir o app. Gastos fixos vencem sem aviso.

## Solucao

### 1. Infraestrutura

- **Firebase Cloud Messaging (FCM)** para push notifications
- **Supabase Edge Functions** ou **cron job** para disparar alertas
- Armazenar token FCM na tabela `usuarios`

```sql
ALTER TABLE public.usuarios
ADD COLUMN fcm_token text;
```

### 2. Tipos de notificacao

| Gatilho | Mensagem | Quando |
|---------|----------|--------|
| Envelope < 20% | "Seu envelope Mercado esta com R$80 (10% do planejado)" | Apos cada despesa |
| Envelope negativo | "Envelope Lazer ficou negativo: -R$30" | Apos cada despesa |
| Gasto fixo proximo | "Aluguel vence em 2 dias (dia 10)" | 2 dias antes do vencimento |
| Gasto grande | "Alan registrou R$800 em Alimentacao" | Apos despesa > 30% do envelope |
| Receita recebida | "Alanna registrou receita de R$2.000" | Apos cada receita |

### 3. Backend — Servico de notificacao

```python
# notifications.py
import firebase_admin
from firebase_admin import messaging

def notificar_familia(familia_id: str, titulo: str, corpo: str):
    db = get_supabase()
    usuarios = db.table("usuarios").select("fcm_token") \
        .eq("familia_id", familia_id) \
        .not_.is_("fcm_token", "null").execute().data

    tokens = [u["fcm_token"] for u in usuarios]
    if not tokens:
        return

    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=titulo, body=corpo),
        tokens=tokens,
    )
    messaging.send_each_for_multicast(message)
```

### 4. Flutter — Receber notificacoes

```dart
// Em main.dart ou provider dedicado
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  // Mostrar notificacao local
});

// Salvar token no banco
final token = await FirebaseMessaging.instance.getToken();
supabase.from('usuarios').update({'fcm_token': token}).eq('id', userId);
```

### 5. Cron para vencimentos de fixos

**Supabase Edge Function** executada diariamente:
1. Buscar fixos com `pago = false` e `dia_vencimento` dentro de 2 dias
2. Enviar push para os membros da familia

### 6. Preferencias do usuario

Futuramente, adicionar tela de configuracoes com toggles:
- Notificacoes de envelope baixo: on/off
- Notificacoes de gastos da familia: on/off
- Lembrete de fixos: on/off

---

## Criterios de Aceite

- [ ] Push notification recebida quando envelope fica abaixo de 20%
- [ ] Push notification recebida quando gasto fixo vence em 2 dias
- [ ] Notificacao aparece mesmo com app fechado
- [ ] Token FCM salvo no banco ao fazer login
- [ ] Notificacoes enviadas para todos os membros da familia

---

## Dependencias

- Firebase project configurado (Android + iOS)
- `firebase_messaging` no pubspec.yaml
- `firebase-admin` no requirements.txt
- Supabase Edge Functions ou cron externo

---

## Arquivos Afetados

| Arquivo | Alteracao |
|---------|-----------|
| Supabase SQL | ALTER TABLE usuarios + fcm_token |
| `envelope-api/requirements.txt` | Adicionar firebase-admin |
| Nova: `envelope-api/notifications.py` | Servico de push |
| `envelope-api/routes/transacoes.py` | Chamar notificacao apos insert |
| `envelope-flutter/pubspec.yaml` | Adicionar firebase_messaging |
| `envelope-flutter/lib/main.dart` | Inicializar Firebase + salvar token |
| Nova: `envelope-flutter/lib/providers/notification_provider.dart` | Gerenciar estado |
