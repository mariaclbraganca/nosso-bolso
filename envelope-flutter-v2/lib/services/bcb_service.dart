import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TaxasBrasil {
  final double selicMensal;    // % a.m. ex: 1.15
  final double cdiMensal;      // % a.m. ex: 1.14
  final double ipcaAnual;      // % a.a. ex: 5.5
  final String dataReferencia; // ex: "jul/2026"

  const TaxasBrasil({
    required this.selicMensal,
    required this.cdiMensal,
    required this.ipcaAnual,
    required this.dataReferencia,
  });

  double get selicAnual => (pow1(1 + selicMensal / 100, 12) - 1) * 100;
  double get poupancaMensal => selicMensal * 0.7; // 70% da Selic
  double get ipcaMensal => ipcaAnual / 12;

  // Selic anual arredondada para exibição
  static double pow1(double base, int exp) {
    double result = 1.0;
    for (var i = 0; i < exp; i++) result *= base;
    return result;
  }
}

class BcbService {
  // Série 432 = Selic meta mensal | 433 = CDI mensal | 13522 = IPCA acumulado 12m
  static const _urlBase = 'https://api.bcb.gov.br/dados/serie/bcdata.sgs';
  static const _suffix = '/dados/ultimos/1?formato=json';

  static TaxasBrasil? _cache;
  static DateTime? _cacheTime;
  static const _cacheDuration = Duration(hours: 6);

  static Future<TaxasBrasil> buscar() async {
    // Cache por 6h — Selic muda no máximo a cada 45 dias
    if (_cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cache!;
    }

    try {
      final results = await Future.wait([
        _get('432'),   // Selic mensal
        _get('433'),   // CDI mensal
        _get('13522'), // IPCA 12m
      ]).timeout(const Duration(seconds: 8));

      final selicMensal = double.tryParse(results[0]) ?? 1.15;
      final cdiMensal   = double.tryParse(results[1]) ?? 1.14;
      final ipcaAnual   = double.tryParse(results[2]) ?? 5.5;

      final now = DateTime.now();
      final meses = ['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'];
      final dataRef = '${meses[now.month - 1]}/${now.year}';

      _cache = TaxasBrasil(
        selicMensal: selicMensal,
        cdiMensal: cdiMensal,
        ipcaAnual: ipcaAnual,
        dataReferencia: dataRef,
      );
      _cacheTime = DateTime.now();
      return _cache!;
    } catch (e) {
      debugPrint('BcbService: erro ao buscar taxas: $e — usando fallback');
      // Fallback seguro se API cair
      return const TaxasBrasil(
        selicMensal: 1.15,
        cdiMensal: 1.14,
        ipcaAnual: 5.5,
        dataReferencia: 'dados indisponíveis',
      );
    }
  }

  static Future<String> _get(String serie) async {
    final uri = Uri.parse('$_urlBase.$serie$_suffix');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) throw Exception('BCB HTTP ${resp.statusCode}');
    final list = jsonDecode(resp.body) as List;
    return (list.first as Map<String, dynamic>)['valor'] as String;
  }
}
