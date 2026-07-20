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
