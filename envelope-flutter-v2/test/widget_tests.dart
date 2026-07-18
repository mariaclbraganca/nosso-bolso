import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:envelope_flutter_v2/widgets/shared/error_state.dart';
import 'package:envelope_flutter_v2/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );

void main() {
  group('ErrorState', () {
    testWidgets('exibe mensagem padrão', (tester) async {
      await tester.pumpWidget(_wrap(const ErrorState()));
      expect(find.text('Algo deu errado. Tente novamente.'), findsOneWidget);
    });

    testWidgets('exibe mensagem customizada', (tester) async {
      await tester.pumpWidget(_wrap(
        const ErrorState(mensagem: 'Sem conexão'),
      ));
      expect(find.text('Sem conexão'), findsOneWidget);
    });

    testWidgets('sem onRetry não mostra botão', (tester) async {
      await tester.pumpWidget(_wrap(const ErrorState()));
      expect(find.text('TENTAR NOVAMENTE'), findsNothing);
    });

    testWidgets('com onRetry mostra botão e dispara callback', (tester) async {
      var chamado = false;
      await tester.pumpWidget(_wrap(
        ErrorState(onRetry: () => chamado = true),
      ));
      expect(find.text('TENTAR NOVAMENTE'), findsOneWidget);
      await tester.tap(find.text('TENTAR NOVAMENTE'));
      expect(chamado, isTrue);
    });

    testWidgets('sliver=true retorna SliverToBoxAdapter', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [const ErrorState(sliver: true)],
          ),
        ),
      ));
      expect(find.byType(SliverToBoxAdapter), findsOneWidget);
    });

    testWidgets('ícone wifi_off está presente', (tester) async {
      await tester.pumpWidget(_wrap(const ErrorState()));
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });
  });

  group('FAB heroTag', () {
    testWidgets('dois FABs com heroTags diferentes não causam exceção', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: const SizedBox(),
          floatingActionButton: Stack(
            children: [
              FloatingActionButton(
                heroTag: 'fab_main',
                onPressed: () {},
                child: const Icon(Icons.add),
              ),
              FloatingActionButton(
                heroTag: 'extrato_fab',
                onPressed: () {},
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('FAB com heroTag renderiza sem erro', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: const SizedBox(),
          floatingActionButton: FloatingActionButton(
            heroTag: 'fab_test',
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
        ),
      ));
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ErrorState sliver vs box', () {
    testWidgets('sliver=false não wraps em SliverToBoxAdapter', (tester) async {
      await tester.pumpWidget(_wrap(const ErrorState()));
      expect(find.byType(SliverToBoxAdapter), findsNothing);
    });
  });
}
