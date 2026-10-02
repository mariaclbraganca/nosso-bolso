import 'dart:convert';

/// Mapeia categorias brutas para as categorias padronizadas do sistema.
String mapearCategoriaCompra(String cat) {
  const mapa = {
    'ALIMENTACAO': 'Outros',
    'LIMPEZA': 'Limpeza',
    'HIGIENE': 'Higiene Pessoal',
    'BEBIDAS': 'Bebidas',
    'OUTROS': 'Outros',
    'Proteínas': 'Proteínas',
    'Carboidratos': 'Carboidratos',
    'Hortifrúti': 'Hortifrúti',
    'Laticínios': 'Laticínios',
    'Padaria': 'Padaria',
    'Bebidas': 'Bebidas',
    'Lanches': 'Lanches',
    'Temperos e Condimentos': 'Temperos e Condimentos',
    'Limpeza': 'Limpeza',
    'Higiene Pessoal': 'Higiene Pessoal',
    'Congelados': 'Congelados',
    'Grãos e Cereais': 'Grãos e Cereais',
    'Outros': 'Outros',
  };
  return mapa[cat] ?? 'Outros';
}

/// Monta o body do POST /salvar_extraido a partir do JSON já extraído pelo
/// Gemini. Se [compraIdVinculo] for informado, o backend enriquece a compra
/// pendente existente em vez de criar uma nova.
Map<String, dynamic> montarBodyIngestao({
  required String familiaId,
  required String qrUrl,
  required Map<String, dynamic> extraido,
  String? compraIdVinculo,
}) {
  final body = <String, dynamic>{
    'familia_id': familiaId,
    'qr_code_url': qrUrl,
    'supermercado': extraido['supermercado'] ?? 'Desconhecido',
    'data_compra': extraido['data_compra'] ??
        DateTime.now().toIso8601String().substring(0, 10),
    'valor_total': (extraido['valor_total'] ?? 0.0).toDouble(),
    'itens': (extraido['itens'] as List? ?? [])
        .map((item) => {
              'nome_original':
                  item['nome_original'] ?? item['nome_padronizado'] ?? '',
              'nome_padronizado':
                  item['nome_padronizado'] ?? item['nome_original'] ?? '',
              'categoria':
                  mapearCategoriaCompra(item['categoria'] as String? ?? ''),
              'quantidade': (item['quantidade'] ?? 1).toDouble(),
              'unidade': item['unidade'] ?? 'un',
              'valor_unitario': (item['valor_unitario'] ?? 0.0).toDouble(),
              'valor_total_item': (item['valor_total_item'] ?? 0.0).toDouble(),
            })
        .toList(),
  };
  if (compraIdVinculo != null) {
    body['compra_id'] = compraIdVinculo;
  }
  return body;
}
