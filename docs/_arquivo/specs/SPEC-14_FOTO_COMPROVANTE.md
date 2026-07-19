# SPEC-14 — Foto de Comprovante na Transacao

**Prioridade:** Baixa (Mes 3)
**Esforco:** Medio
**Status:** Planejado

---

## Problema

O usuario registra "Mercado R$350" mas nao tem como anexar a nota fiscal ou comprovante Pix.

## Solucao

### 1. Supabase Storage

Criar bucket `comprovantes` no Supabase Storage:
```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('comprovantes', 'comprovantes', false);
```

### 2. Novo campo na tabela transacoes

```sql
ALTER TABLE public.transacoes
ADD COLUMN comprovante_url text DEFAULT NULL;
```

### 3. Fluxo

1. No `FormGastoSheet`, adicionar botao "Anexar foto" (icone de camera)
2. Abrir camera ou galeria (`image_picker`)
3. Upload para Supabase Storage: `comprovantes/{familia_id}/{transacao_id}.jpg`
4. Salvar URL no campo `comprovante_url`
5. No extrato, mostrar icone de clipe nas transacoes com foto
6. Ao tocar, abrir visualizador fullscreen

### 4. Compressao

Comprimir imagem antes do upload (max 500KB):
```dart
final compressed = await FlutterImageCompress.compressWithFile(
    file.path, quality: 70, minWidth: 1024, minHeight: 1024,
);
```

---

## Dependencias

- `image_picker` no pubspec.yaml
- `flutter_image_compress` no pubspec.yaml
- Supabase Storage configurado

---

## Arquivos Afetados

| Arquivo | Alteracao |
|---------|-----------|
| Supabase | Criar bucket + ALTER TABLE |
| `envelope-flutter/pubspec.yaml` | image_picker, flutter_image_compress |
| `envelope-flutter/lib/screens/form_gasto_sheet.dart` | Botao de camera |
| `envelope-flutter/lib/widgets/transacao_item.dart` | Icone de clipe |
| Nova: `envelope-flutter/lib/screens/comprovante_viewer.dart` | Visualizador |
