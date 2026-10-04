import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/providers/plano_provider.dart';
import 'package:nosso_bolso_v3/core/providers/compras_provider.dart';
import 'package:nosso_bolso_v3/core/providers/contas_provider.dart';
import 'package:nosso_bolso_v3/core/providers/metas_provider.dart';
import 'package:nosso_bolso_v3/core/providers/patrimonio_provider.dart';
import 'package:nosso_bolso_v3/core/providers/usuarios_provider.dart';
import 'package:nosso_bolso_v3/core/providers/fixos_provider.dart';
import 'package:nosso_bolso_v3/core/providers/envelopes_provider.dart';
import 'package:nosso_bolso_v3/screens/shell/modulos_saude.dart';
import 'package:nosso_bolso_v3/screens/planos/contas_tab.dart';
import 'package:nosso_bolso_v3/screens/planos/futuro_screen.dart';
import 'package:nosso_bolso_v3/screens/planos/planos_screen.dart';

class _Perfil extends PerfilUsuarioNotifier {
  @override
  Future<Map<String, dynamic>?> build() async => {'id': 'u', 'familia_id': 'f', 'role': 'admin', 'nome': 'Fred'};
}

final compra = {
  'compra_id': 'c1', 'supermercado': 'Assaí Atacadista', 'valor_total': 287.45,
  'data_compra': '2026-10-02T10:00:00', 'fonte': 'nfce', 'status_integracao': 'pendente',
  'itens': [
    {'nome_original': 'ARROZ T1 5KG', 'nome_padronizado': 'Arroz tipo 1', 'categoria': 'mercearia',
     'quantidade': 2.0, 'unidade': 'un', 'valor_unitario': 27.9, 'valor_total_item': 55.8},
  ],
};

Future<void> abrirAbas(WidgetTester t, List<String> rotulos) async {
  for (final r in rotulos) {
    final f = find.textContaining(r);
    expect(f, findsWidgets, reason: 'aba $r não encontrada');
    await t.tap(f.first);
    await t.pump(const Duration(milliseconds: 400));
    final e = t.takeException();
    expect(e, isNull, reason: 'aba $r lançou exceção');
  }
}

void main() {
  final base = [
    perfilUsuarioLogadoProvider.overrideWith(_Perfil.new),
    envelopesProvider.overrideWith((ref) => Stream.value([{'id': 'e1', 'nome_envelope': 'Mercado', 'saldo_atual': 400, 'valor_planejado': 1200, 'natureza': 'consumo'}])),
  ];
  testWidgets('Despensa: lista de compras e estoque', (t) async {
    await t.pumpWidget(ProviderScope(overrides: [
      ...base,
      comprasPendentesProvider.overrideWith((ref) async => [compra]),
      feedbackPendenteProvider.overrideWith((ref) async => [
        {'compra_id': 'c1', 'nome_padronizado': 'Arroz tipo 1', 'categoria': 'mercearia', 'data_compra': '2026-09-20', 'data_feedback_estimada': '2026-10-01'}
      ]),
      listaComprasProvider.overrideWith((ref, dias) async => {
        'itens': [{'nome': 'Café', 'categoria': 'mercearia', 'quantidade_sugerida': 2, 'unidade': 'un', 'preco_estimado': 38.0, 'motivo': 'acaba em 5 dias'}],
        'custo_estimado_total': 38.0, 'saldo_envelope': 412.3, 'dentro_do_orcamento': true, 'dias_cobertura': 12,
      }),
      comprasFalhasProvider.overrideWith((ref) async => <Map<String, dynamic>>[]),
    ], child: MaterialApp(theme: nossoBolsoTheme(), home: const DespensaScreen())));
    await t.pump(const Duration(milliseconds: 500));
    expect(t.takeException(), isNull);
    expect(find.textContaining('Café'), findsWidgets); // lista de compras abre primeiro
    await abrirAbas(t, ['Estoque', 'Lista de compras']);
  });
  final planos = [
      ...base,
      fixosStreamProvider.overrideWith((ref) => Stream.value([{'id': 'x1', 'nome': 'Aluguel', 'valor': 1650.0, 'pago': false, 'dia_vencimento': 10, 'mes': '2026-10'}])),
      contasMesProvider.overrideWith((ref, mes) async => [{'_id': 'a1', 'nome': 'Luz', 'valor': 238.0, 'vencimento': '2026-10-15', 'pago': false, 'categoria': 'energia'}]),
      metasProvider.overrideWith((ref) async => [{'_id': 'm1', 'nome': 'Viagem', 'valor_meta': 6000.0, 'valor_atual': 3200.0, 'emoji': '✈️'}]),
      patrimonioProvider.overrideWith((ref) => Stream.value(<Map<String, dynamic>>[])),
      snapshotsPatrimonioProvider.overrideWith((ref) async => <Map<String, dynamic>>[]),
      entradasMesProvider.overrideWith((ref, mes) async => [{'id': 'e1', 'nome': 'Salário', 'valor': 5491.0, 'tipo': 'dinheiro'}]),
      compromissosCartaoProvider.overrideWith((ref) async => <Map<String, dynamic>>[]),
  ];
  testWidgets('Envelopes: todas as abas', (t) async {
    await t.pumpWidget(ProviderScope(overrides: planos, child: MaterialApp(theme: nossoBolsoTheme(), home: const PlanosScreen())));
    await t.pump(const Duration(milliseconds: 500));
    expect(t.takeException(), isNull);
    expect(find.text('Ver a conta ›'), findsOneWidget); // aba Orçamento abre primeiro
    await abrirAbas(t, ['Resumo']);
    expect(find.text('Salário'), findsWidgets); // na lista de receitas e no "de onde vem"
    await abrirAbas(t, ['Orçamento']);
    expect(find.text('Contas'), findsNothing); // Contas fica na barra de Finanças
    expect(find.text('Metas'), findsNothing); // Metas ficam em Patrimônio e reserva
  });
  testWidgets('Futuro: próximos meses, parcelas e simulações', (t) async {
    await t.pumpWidget(ProviderScope(overrides: planos, child: MaterialApp(theme: nossoBolsoTheme(), home: const FuturoScreen())));
    await t.pump(const Duration(milliseconds: 500));
    expect(t.takeException(), isNull);
    expect(find.text('VALOR DISPONÍVEL PARA OS ENVELOPES NOS PRÓXIMOS MESES'), findsOneWidget);
    await abrirAbas(t, ['Parcelas', 'Simulações']);
    expect(find.text('Simular um cenário'), findsOneWidget);
  });
  testWidgets('Contas: fixos e boletos na mesma lista', (t) async {
    await t.pumpWidget(ProviderScope(overrides: planos, child: MaterialApp(theme: nossoBolsoTheme(), home: const ContasScreen())));
    await t.pump(const Duration(milliseconds: 500));
    expect(t.takeException(), isNull);
    expect(find.textContaining('Aluguel'), findsWidgets);
    expect(find.textContaining('Luz'), findsWidgets);
  });
}
