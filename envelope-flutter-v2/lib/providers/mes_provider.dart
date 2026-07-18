import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Provider global do mês selecionado.
/// Formato: 'yyyy-MM' (ex: '2026-04')
/// Inicia sempre no mês atual.
final mesAtualProvider = StateProvider<String>((ref) {
  return DateFormat('yyyy-MM').format(DateTime.now());
});

/// Label formatado para exibição (ex: 'ABR 2026')
String mesLabel(String mes) {
  final parts = mes.split('-');
  final year = parts[0];
  final month = int.parse(parts[1]);
  const nomes = ['', 'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];
  return '${nomes[month]} $year';
}

/// Label longo (ex: 'Abril 2026')
String mesLabelLongo(String mes) {
  final parts = mes.split('-');
  final year = parts[0];
  final month = int.parse(parts[1]);
  const nomes = ['', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
  return '${nomes[month]} $year';
}

/// Avança um mês
String mesProximo(String mes) {
  final parts = mes.split('-');
  var y = int.parse(parts[0]);
  var m = int.parse(parts[1]) + 1;
  if (m > 12) { m = 1; y++; }
  return '$y-${m.toString().padLeft(2, '0')}';
}

/// Volta um mês
String mesAnterior(String mes) {
  final parts = mes.split('-');
  var y = int.parse(parts[0]);
  var m = int.parse(parts[1]) - 1;
  if (m < 1) { m = 12; y--; }
  return '$y-${m.toString().padLeft(2, '0')}';
}
