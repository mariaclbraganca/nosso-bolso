# SPEC-10 — Wizard de Onboarding Completo

**Prioridade:** Media (Mes 2)
**Esforco:** Medio
**Status:** Planejado

---

## Problema

Apos criar a familia, o usuario cai no dashboard vazio sem orientacao. Nao sabe por onde comecar.

## Solucao

### Fluxo de 4 passos apos criar/entrar na familia

**Passo 1 — "Crie seus envelopes"**
- Sugestoes pre-definidas com emoji: Alimentacao 🍎, Transporte 🚗, Lazer 🎬, Saude 🩺, Educacao 📚
- Usuario marca quais quer criar
- Campo de valor planejado para cada um
- Botao "Adicionar personalizado"

**Passo 2 — "Registre sua primeira receita"**
- Campo de valor e descricao
- Sugestoes: "Salario", "Freelance", "Mesada"
- Explicacao: "Receita e o dinheiro que entra na sua conta"

**Passo 3 — "Distribua entre os envelopes"**
- Slider para cada envelope criado no passo 1
- Total disponivel = receita do passo 2
- Barra de progresso: "R$X de R$Y distribuido"

**Passo 4 — "Pronto!"**
- Resumo do que foi configurado
- Dicas de uso: "Toque no + para registrar gastos", "Swipe para deletar"
- Botao "Ir para o Dashboard"

### Flutter — `OnboardingWizardScreen`

```dart
class OnboardingWizardScreen extends ConsumerStatefulWidget {
    // PageView com 4 paginas
    // PageController para navegacao
    // Indicador de progresso (dots)
    // Botoes "Voltar" e "Proximo"
    // Ultimo passo: "Concluir"
}
```

### Quando mostrar

- Flag `onboarding_completo` na tabela `usuarios` (boolean, default false)
- Se `false`: redirecionar para wizard antes do dashboard
- Ao concluir: marcar como `true`

```sql
ALTER TABLE public.usuarios
ADD COLUMN onboarding_completo boolean DEFAULT false;
```

---

## Criterios de Aceite

- [ ] Wizard aparece automaticamente apos primeiro login
- [ ] Envelopes sugeridos criados corretamente
- [ ] Receita registrada no passo 2 atualiza saldo_geral
- [ ] Distribuicao no passo 3 abastece os envelopes
- [ ] Nao aparece novamente apos conclusao
- [ ] Botao "Pular" disponivel em cada passo

---

## Arquivos Afetados

| Arquivo | Alteracao |
|---------|-----------|
| Supabase SQL | ALTER TABLE usuarios + onboarding_completo |
| Nova: `envelope-flutter/lib/screens/onboarding_wizard_screen.dart` | Wizard 4 passos |
| `envelope-flutter/lib/main.dart` | Redirecionar para wizard se nao completo |
| `envelope-flutter/lib/providers/auth_provider.dart` | Verificar flag |
