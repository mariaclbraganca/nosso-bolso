import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Memória permanente das notificações financeiras já enviadas ao servidor.
///
/// O app relê a bandeja do Android toda vez que abre ou volta ao primeiro
/// plano; sem lembrar o que já enviou, cada leitura criaria a mesma compra de
/// novo. A identidade de uma notificação é o horário em que o Android a postou
/// mais o texto: a mesma notificação relida tem exatamente a mesma chave, e duas
/// compras iguais (dois lanches de R$ 4,00) têm horários diferentes.
class NotificacaoVistaService {
  static const _key = 'notificacoes_vistas_v1';
  static const _validadeDias = 30;
  static const _maxItens = 800;

  /// Chave estável: segundo em que a notificação foi postada + texto resumido.
  static String chave(String texto, DateTime postado) =>
      '${postado.millisecondsSinceEpoch ~/ 1000}|${_hash(_normalizar(texto))}';

  /// true se a notificação já foi vista; se não, registra e devolve false.
  static Future<bool> jaVista(String chave, {DateTime? agora}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // O isolate de background e o app guardam cópias separadas: relê do disco.
      await prefs.reload();
      final hoje = agora ?? DateTime.now();
      final corte = hoje.subtract(const Duration(days: _validadeDias)).millisecondsSinceEpoch;
      final vistas = <String, int>{};
      for (final linha in prefs.getStringList(_key) ?? const <String>[]) {
        final i = linha.indexOf(';');
        if (i < 0) continue;
        final quando = int.tryParse(linha.substring(0, i)) ?? 0;
        if (quando >= corte) vistas[linha.substring(i + 1)] = quando;
      }
      if (vistas.containsKey(chave)) return true;
      vistas[chave] = hoje.millisecondsSinceEpoch;
      var lista = vistas.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
      if (lista.length > _maxItens) lista = lista.sublist(lista.length - _maxItens);
      await prefs.setStringList(_key, [for (final e in lista) '${e.value};${e.key}']);
      return false;
    } catch (e) {
      debugPrint('[NotifVista] erro: $e'); // na dúvida, deixa o servidor decidir
      return false;
    }
  }

  static String _normalizar(String t) => t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// FNV-1a de 32 bits: igual em qualquer execução (hashCode do Dart não é).
  static String _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16);
  }
}
