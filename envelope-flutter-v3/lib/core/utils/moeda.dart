import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Parsing robusto de valores monetários digitados pelo usuário.
///
/// O teclado do usuário pode usar vírgula (pt-BR: "1.050,00") ou ponto
/// (teclado americano: "10.50"). A heurística: o ÚLTIMO separador (vírgula ou
/// ponto) é o decimal; todos os outros são separadores de milhar e somem.
///
/// Exemplos:
///   "1.050,00" → 1050.00   "10,50" → 10.50   "10.50" → 10.50
///   "1,050.00" → 1050.00   "1050"  → 1050.0  "R$ 1.234,56" → 1234.56
double parseMoeda(String texto) {
  var s = texto.trim();
  if (s.isEmpty) return 0;

  // Remove tudo que não for dígito, vírgula, ponto ou sinal.
  s = s.replaceAll(RegExp(r'[^\d,.\-]'), '');
  // Remove separadores soltos nas bordas (ex: "0,01." → "0,01"), que quebrariam
  // a heurística de decimal. Um separador só é decimal se tiver dígitos depois.
  s = s.replaceAll(RegExp(r'^[.,]+'), '').replaceAll(RegExp(r'[.,]+$'), '');
  if (s.isEmpty || s == '-') return 0;

  final ultimaVirgula = s.lastIndexOf(',');
  final ultimoPonto = s.lastIndexOf('.');

  String normalizado;
  if (ultimaVirgula == -1 && ultimoPonto == -1) {
    normalizado = s; // só dígitos
  } else if (ultimaVirgula > ultimoPonto) {
    // vírgula é o decimal → remove pontos (milhar), vírgula vira ponto
    normalizado = s.replaceAll('.', '').replaceAll(',', '.');
  } else {
    // ponto é o decimal → remove vírgulas (milhar)
    normalizado = s.replaceAll(',', '');
  }

  return double.tryParse(normalizado) ?? 0;
}

/// Formatter para campos de entrada monetária em tempo real (estilo centavos).
class MoedaInputFormatter extends TextInputFormatter {
  final int maxDigitos;
  final bool incluirSimbolo;

  MoedaInputFormatter({this.maxDigitos = 11, this.incluirSimbolo = false});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String apenasDigitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (apenasDigitos.isEmpty) {
      return newValue.copyWith(text: '');
    }

    if (apenasDigitos.length > maxDigitos) {
      apenasDigitos = apenasDigitos.substring(0, maxDigitos);
    }

    final double valor = double.parse(apenasDigitos) / 100.0;
    final formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: incluirSimbolo ? 'R\$ ' : '',
      decimalDigits: 2,
    );

    final novoTexto = formatter.format(valor).trim();

    return TextEditingValue(
      text: novoTexto,
      selection: TextSelection.collapsed(offset: novoTexto.length),
    );
  }
}



/// Campo de valor em reais: digitar 60 é R$ 60,00; centavos depois da vírgula
/// (60,50). O ponto digitado vira vírgula; no máximo 2 casas decimais.
class ReaisInputFormatter extends TextInputFormatter {
  ReaisInputFormatter({this.maxInteiros = 9});
  final int maxInteiros;

  static String normalizar(String texto) {
    var s = texto.replaceAll(RegExp(r'[^\d,.]'), '');
    if (s.contains(',')) {
      s = s.replaceAll('.', ''); // valor já formatado (1.300,00): pontos são milhar
    } else if (s.contains('.')) {
      final i = s.lastIndexOf('.'); // teclado com ponto: o último é o decimal
      s = '${s.substring(0, i).replaceAll('.', '')},${s.substring(i + 1).replaceAll('.', '')}';
    }
    final virgula = s.indexOf(',');
    var inteiros = virgula < 0 ? s : s.substring(0, virgula);
    var decimais = virgula < 0 ? null : s.substring(virgula + 1).replaceAll(',', '');
    inteiros = inteiros.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (decimais != null && decimais.length > 2) decimais = decimais.substring(0, 2);
    if (decimais != null && inteiros.isEmpty) inteiros = '0';
    return decimais == null ? inteiros : '$inteiros,$decimais';
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var texto = normalizar(newValue.text);
    final inteiros = texto.split(',').first;
    if (inteiros.length > maxInteiros) return oldValue;
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}
