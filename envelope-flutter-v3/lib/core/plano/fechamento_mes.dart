/// O mês é sempre do dia 1 ao último dia, pela DATA do gasto. Um gasto de
/// novembro lançado em dezembro continua sendo de novembro. Depois de fechado,
/// se aparecer lançamento do mês criado depois do fechamento, o retrato está
/// desatualizado e o app oferece atualizar.
library;

/// Lançamentos do [mes] criados depois de [fechadoEm] (ISO). Ignora excluídos.
int lancamentosDepoisDoFechamento(String mes, String? fechadoEm, List<Map<String, dynamic>> transacoes) {
  final fechou = DateTime.tryParse(fechadoEm ?? '');
  if (fechou == null) return 0;
  var n = 0;
  for (final t in transacoes) {
    if (t['deleted_at'] != null) continue;
    if (!(t['data']?.toString() ?? '').startsWith(mes)) continue;
    final criado = DateTime.tryParse(t['created_at']?.toString() ?? '');
    if (criado != null && criado.isAfter(fechou)) n++;
  }
  return n;
}
