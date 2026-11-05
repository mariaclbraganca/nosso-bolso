/// Fatura do cartão: parcelas e assinaturas que caem em cada fatura (vence
/// dia 7) e a conta dos meses.
library;

double _n(Object? v) => (v as num?)?.toDouble() ?? 0;

/// 'YYYY-MM' + n meses.
String somarMeses(String mes, int n) {
  final total = int.parse(mes.substring(0, 4)) * 12 + int.parse(mes.substring(5, 7)) - 1 + n;
  return '${total ~/ 12}-${(total % 12 + 1).toString().padLeft(2, '0')}';
}

int mesesEntre(String de, String ate) =>
    (int.parse(ate.substring(0, 4)) - int.parse(de.substring(0, 4))) * 12 +
    int.parse(ate.substring(5, 7)) -
    int.parse(de.substring(5, 7));

/// Item do cartão que cai na fatura que vence em [mesFatura], com o número da
/// parcela daquele mês (null = assinatura). Null se não cai nessa fatura.
({String descricao, double valor, int? parcela, int? total})? itemNaFatura(
    Map<String, dynamic> c, String mesFatura) {
  final desloc = mesesEntre(c['mes_fatura'] as String, mesFatura);
  if (desloc < 0) return null;
  final atual = (c['parcela_atual'] as num?)?.toInt();
  final total = (c['total_parcelas'] as num?)?.toInt();
  if (atual != null && total != null && atual + desloc > total) return null;
  return (
    descricao: c['descricao'] as String? ?? '',
    valor: _n(c['valor']),
    parcela: atual == null ? null : atual + desloc,
    total: total,
  );
}

List<({String descricao, double valor, int? parcela, int? total})> itensDaFatura(
        List<Map<String, dynamic>> compromissos, String mesFatura) =>
    [
      for (final c in compromissos)
        if (itemNaFatura(c, mesFatura) case final item?) item,
    ];

double comprometidoNaFatura(List<Map<String, dynamic>> compromissos, String mesFatura) =>
    itensDaFatura(compromissos, mesFatura).fold(0.0, (s, i) => s + i.valor);

/// Parcelas 2..n de uma compra parcelada viram lançamentos futuros: a 1ª é
/// compra do mês; a 2ª cai na fatura de [mes]+2 (a fatura de [mes]+1 traz a 1ª).
Map<String, dynamic> compromissoDaParcelada({
  required String familiaId,
  required String descricao,
  required double valorTotal,
  required int parcelas,
  required String mes,
}) =>
    {
      'familia_id': familiaId,
      'descricao': descricao,
      'valor': valorParcela(valorTotal, parcelas),
      'mes_fatura': somarMeses(mes, 2),
      'parcela_atual': 2,
      'total_parcelas': parcelas,
    };

double valorParcela(double total, int parcelas) => (total / parcelas * 100).roundToDouble() / 100;

/// O ciclo da fatura vai do dia 30 do mês anterior ao dia 30 do mês das compras.
const diaFechaFatura = 30;

({String ini, String fim}) cicloDaFatura(String mesCompras) {
  String dia(String mes) {
    final ultimo = DateTime(int.parse(mes.substring(0, 4)), int.parse(mes.substring(5, 7)) + 1, 0).day;
    return '$mes-${(diaFechaFatura < ultimo ? diaFechaFatura : ultimo).toString().padLeft(2, '0')}';
  }

  return (ini: dia(somarMeses(mesCompras, -1)), fim: dia(mesCompras));
}

/// Compra no crédito já normalizada: data 'yyyy-MM-dd' e valor.
typedef CompraCredito = ({String data, double valor});

/// Fatura que vence (dia 7) em [mesVenc]: as compras no crédito do ciclo mais
/// as parcelas e assinaturas que caem nela. É o mesmo cálculo do fechamento.
double faturaQueVenceEm(String mesVenc, List<CompraCredito> compras, List<Map<String, dynamic>> compromissos) {
  final c = cicloDaFatura(somarMeses(mesVenc, -1));
  final doCiclo = compras
      .where((x) => x.data.compareTo(c.ini) >= 0 && x.data.compareTo(c.fim) <= 0)
      .fold(0.0, (s, x) => s + x.valor);
  return doCiclo + comprometidoNaFatura(compromissos, mesVenc);
}
