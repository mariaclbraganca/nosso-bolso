# 📱 SPEC-16: Home Screen Widget (Protótipo)

O Widget de Tela Inicial permite ao usuário visualizar o saldo geral sem abrir o app e oferece um atalho "Atrito Zero" para o registro de gastos.

## 🏗️ Estrutura Técnica

### 1. Dependência Recomendada
Adicionar ao `pubspec.yaml`:
```yaml
home_widget: ^0.6.0
```

### 2. Provider de Sincronização (Dart)
Lógica para atualizar o widget sempre que o saldo geral mudar no App:

```dart
import 'package:home_widget/home_widget.dart';

class WidgetService {
  static Future<void> updateWidget(double saldo) async {
    await HomeWidget.saveWidgetData<String>('total_balance', 'R$ ${saldo.toStringAsFixed(2)}');
    await HomeWidget.updateWidget(
      name: 'NossoBolsoWidgetProvider',
      androidName: 'NossoBolsoWidgetProvider',
      iOSName: 'NossoBolsoWidget',
    );
  }
}
```

### 3. Interface Visual (Android XML - Prototype)
`res/layout/widget_layout.xml`

```xml
<LinearLayout ...>
    <TextView android:text="SALDO GERAL" />
    <TextView android:id="@+id/total_balance" android:text="R$ 0,00" />
    <Button android:id="@+id/btn_gastei" android:text="+ GASTEI" />
</LinearLayout>
```

### 4. Interface Visual (iOS SwiftUI - Prototype)
`NossoBolsoWidget.swift`

```swift
struct NossoBolsoWidgetEntryView : View {
    var entry: Provider.Entry
    var body: some View {
        VStack {
            Text("SALDO GERAL").font(.caption)
            Text(entry.balance).font(.title).bold()
            Button("+ GASTEI") {
                // Abre o app direto no FormGastoSheet
                Link(destination: URL(string: "nossobolso://gastei")!)
            }
        }.padding()
    }
}
```

## ⚡ Fluxo de Atalho
Ao clicar em "+ GASTEI" no Widget:
1. O App abre via **Deep Link** (`nossobolso://gastei`).
2. O `MainNavigationScreen` detecta o link.
3. Abre automaticamente o `FormGastoSheet` com autofocus no valor.

---
**Status SPEC-16**: Arquitetura pronta para implementação nativa final.
 Riverside
