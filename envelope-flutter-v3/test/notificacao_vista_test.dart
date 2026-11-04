import 'package:flutter_test/flutter_test.dart';
import 'package:nosso_bolso_v3/core/services/notificacao_vista_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final postado = DateTime(2026, 10, 19, 10, 30, 0);
  const texto = 'Compra de R\$ 190,00 aprovada em Pet Colosso para o cartão final 1234';

  test('a mesma notificação relida (app aberto de novo) é reconhecida', () async {
    final k = NotificacaoVistaService.chave(texto, postado);
    expect(await NotificacaoVistaService.jaVista(k), isFalse); // 1ª leitura: envia
    expect(await NotificacaoVistaService.jaVista(k), isTrue); // relida: ignora
    // outra execução do app (memória nova, mesmo disco)
    expect(await NotificacaoVistaService.jaVista(NotificacaoVistaService.chave(texto, postado)), isTrue);
  });

  test('duas compras iguais de verdade (horários diferentes) não se confundem', () async {
    final a = NotificacaoVistaService.chave('Compra de R\$ 4,00 aprovada em Sabor Prime Lanches', postado);
    final b = NotificacaoVistaService.chave(
        'Compra de R\$ 4,00 aprovada em Sabor Prime Lanches', postado.add(const Duration(hours: 5)));
    expect(a, isNot(b));
    expect(await NotificacaoVistaService.jaVista(a), isFalse);
    expect(await NotificacaoVistaService.jaVista(b), isFalse);
  });

  test('o texto conta: outra compra no mesmo segundo não é a mesma', () async {
    final a = NotificacaoVistaService.chave(texto, postado);
    final b = NotificacaoVistaService.chave('Compra de R\$ 59,31 aprovada em Supermercado Leve', postado);
    expect(a, isNot(b));
  });

  test('a chave não muda entre execuções e ignora espaços e pontuação', () {
    expect(NotificacaoVistaService.chave(texto, postado), NotificacaoVistaService.chave(' $texto ', postado));
    expect(NotificacaoVistaService.chave('Compra, de R\$ 1', postado),
        NotificacaoVistaService.chave('compra de r\$ 1', postado));
  });

  test('esquece depois de 30 dias e não cresce sem limite', () async {
    final k = NotificacaoVistaService.chave(texto, postado);
    expect(await NotificacaoVistaService.jaVista(k, agora: DateTime(2026, 10, 19)), isFalse);
    expect(await NotificacaoVistaService.jaVista(k, agora: DateTime(2026, 11, 5)), isTrue);
    expect(await NotificacaoVistaService.jaVista(k, agora: DateTime(2026, 12, 20)), isFalse); // passou de 30 dias
    for (var i = 0; i < 900; i++) {
      await NotificacaoVistaService.jaVista('chave-$i', agora: DateTime(2026, 12, 21));
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('notificacoes_vistas_v1')!.length, lessThanOrEqualTo(800));
  });
}
