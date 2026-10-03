import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/compras_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/services/gemini_nfce_service.dart';
import '../../core/services/nfce_scraper.dart';
import '../sheets/comum.dart';

const _categorias = {
  'ALIMENTACAO': 'Outros', 'LIMPEZA': 'Limpeza', 'HIGIENE': 'Higiene Pessoal', 'BEBIDAS': 'Bebidas',
  'OUTROS': 'Outros', 'Proteínas': 'Proteínas', 'Carboidratos': 'Carboidratos', 'Hortifrúti': 'Hortifrúti',
  'Laticínios': 'Laticínios', 'Padaria': 'Padaria', 'Bebidas': 'Bebidas', 'Lanches': 'Lanches',
  'Temperos e Condimentos': 'Temperos e Condimentos', 'Limpeza': 'Limpeza', 'Higiene Pessoal': 'Higiene Pessoal',
  'Congelados': 'Congelados', 'Grãos e Cereais': 'Grãos e Cereais', 'Outros': 'Outros',
};

double _d(dynamic v, [double padrao = 0]) => (v as num?)?.toDouble() ?? padrao;

/// Corpo do POST /salvar_extraido a partir do JSON do Gemini. Com
/// [compraIdVinculo], o backend completa a compra pendente (ex.: do Nubank)
/// em vez de criar outra.
Map<String, dynamic> montarBodyIngestao({
  required String familiaId,
  required String qrUrl,
  required Map<String, dynamic> extraido,
  String? compraIdVinculo,
}) =>
    {
      'familia_id': familiaId,
      'qr_code_url': qrUrl,
      'supermercado': extraido['supermercado'] ?? 'Desconhecido',
      'data_compra': extraido['data_compra'] ?? DateTime.now().toIso8601String().substring(0, 10),
      'valor_total': _d(extraido['valor_total']),
      'itens': [
        for (final item in (extraido['itens'] as List? ?? const []))
          {
            'nome_original': item['nome_original'] ?? item['nome_padronizado'] ?? '',
            'nome_padronizado': item['nome_padronizado'] ?? item['nome_original'] ?? '',
            'categoria': _categorias[item['categoria'] as String? ?? ''] ?? 'Outros',
            'quantidade': _d(item['quantidade'], 1),
            'unidade': item['unidade'] ?? 'un',
            'valor_unitario': _d(item['valor_unitario']),
            'valor_total_item': _d(item['valor_total_item']),
          },
      ],
      if (compraIdVinculo != null) 'compra_id': compraIdVinculo,
    };

/// Caminho comprovado da v2: o servidor baixa a nota na SEFAZ (/scrape), o
/// Gemini extrai os itens no celular e o resultado vai para /salvar_extraido.
Future<bool> processarNota(
  WidgetRef ref,
  String url, {
  String? compraIdVinculo,
  ValueChanged<String>? onEtapa,
}) async {
  try {
    final p = perfilOuErro(ref);
    onEtapa?.call('Buscando a nota na SEFAZ…');
    final texto = await NfceScraper.raspar(url);
    onEtapa?.call('A IA está separando os itens…');
    final extraido = await GeminiNfceService.extrairDaNota(texto);
    onEtapa?.call('Salvando a compra…');
    await ApiService.post(
      '/api/v1/compras/salvar_extraido',
      montarBodyIngestao(
        familiaId: p['familia_id'] as String,
        qrUrl: url,
        extraido: extraido,
        compraIdVinculo: compraIdVinculo,
      ),
    );
    ref.invalidate(comprasPendentesProvider);
    ref.invalidate(comprasFalhasProvider);
    avisar(compraIdVinculo == null
        ? 'Nota lida. Escolha o envelope para confirmar.'
        : 'Cupom vinculado: os itens entraram na compra.');
    return true;
  } catch (e) {
    avisar(mensagemErro(e), erro: true);
    return false;
  } finally {
    onEtapa?.call('');
  }
}
