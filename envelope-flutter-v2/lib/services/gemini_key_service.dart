import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';

/// Centraliza leitura e rotação de chaves Gemini.
/// Mantém 3 slots (ia_gemini_key_1..3).
/// Em uma chamada POST, tenta cada chave em sequência;
/// se a resposta for 429 passa para a próxima.
class GeminiKeyService {
  static const _model = 'gemini-2.5-flash';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1/models/$_model:generateContent';

  static const _prefixos = [
    'ia_gemini_key_1',
    'ia_gemini_key_2',
    'ia_gemini_key_3',
  ];

  // Mantém compatibilidade com chave legada salva pela tela antiga
  static const _legacyKey = 'ia_gemini_api_key';

  // Armazenamento seguro (Keystore criptografado no Android). As chaves
  // Gemini são secretas — não devem ficar em SharedPreferences (texto plano).
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Migra chaves antigas do SharedPreferences (texto plano) para o
  /// secure storage, uma única vez. Depois apaga as antigas.
  static Future<void> _migrarSePreciso() async {
    try {
      final jaMigrou = await _secure.read(key: '_migrado_v1');
      if (jaMigrou == '1') return;
      final prefs = await SharedPreferences.getInstance();
      for (final k in [..._prefixos, _legacyKey]) {
        final v = prefs.getString(k);
        if (v != null && v.isNotEmpty) {
          await _secure.write(key: k, value: v);
          await prefs.remove(k); // remove do armazenamento inseguro
        }
      }
      await _secure.write(key: '_migrado_v1', value: '1');
    } catch (e) {
      debugPrint('GeminiKey: erro na migração p/ secure storage: $e');
    }
  }

  // ── Leitura de chaves ──────────────────────────────────────────────────────

  /// Retorna lista de chaves válidas (não vazias), combinando slots novos + legada.
  static Future<List<String>> buscarChaves() async {
    await _migrarSePreciso();
    final chaves = <String>[];

    try {
      // Slots numerados (fonte primária) — secure storage
      for (final k in _prefixos) {
        final v = await _secure.read(key: k) ?? '';
        if (v.isNotEmpty) chaves.add(v);
      }

      // Legada (compatibilidade — se não duplicada)
      if (chaves.isEmpty) {
        final v = await _secure.read(key: _legacyKey) ?? '';
        if (v.isNotEmpty) chaves.add(v);
      }
    } catch (e) {
      debugPrint('GeminiKey: erro secure storage: $e');
    }

    // Fallback: Supabase
    if (chaves.isEmpty) {
      chaves.addAll(await _buscarChavesSupabase());
    }

    debugPrint('GeminiKey: ${chaves.length} chave(s) disponível(is)');
    return chaves;
  }

  static Future<List<String>> _buscarChavesSupabase() async {
    final chaves = <String>[];
    try {
      // Formato novo: coluna gemini_api_key
      final rows = await supabase
          .from('configuracoes_app')
          .select('gemini_api_key, gemini_key_2, gemini_key_3')
          .limit(1);
      if (rows.isNotEmpty) {
        for (final col in ['gemini_api_key', 'gemini_key_2', 'gemini_key_3']) {
          final v = rows.first[col] as String?;
          if (v != null && v.isNotEmpty) chaves.add(v);
        }
      }
    } catch (_) {}
    if (chaves.isNotEmpty) return chaves;
    try {
      // Legado: chave/valor
      final rows = await supabase
          .from('configuracoes_app')
          .select('valor')
          .eq('chave', 'GEMINI_API_KEY')
          .limit(1);
      if (rows.isNotEmpty) {
        final v = rows.first['valor'] as String?;
        if (v != null && v.isNotEmpty) chaves.add(v);
      }
    } catch (_) {}
    return chaves;
  }

  // ── POST com rotação automática ────────────────────────────────────────────

  /// Faz um POST Gemini tentando cada chave em sequência.
  /// Lança [GeminiSemChaveException] se não houver chaves.
  /// Lança [GeminiCotaEsgotadaException] se todas retornarem 429.
  /// Lança [GeminiException] para outros erros HTTP.
  static Future<http.Response> post(
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final chaves = await buscarChaves();
    if (chaves.isEmpty) {
      throw GeminiSemChaveException();
    }

    http.Response? ultimaResposta;
    for (var i = 0; i < chaves.length; i++) {
      final chave = chaves[i];
      final uri = Uri.parse('$_baseUrl?key=$chave');

      try {
        final resp = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(timeout);

        if (resp.statusCode == 429) {
          debugPrint('GeminiKey: chave ${i + 1} com cota esgotada (429) — '
              '${i + 1 < chaves.length ? "tentando próxima" : "sem mais chaves"}');
          ultimaResposta = resp;
          continue; // tenta a próxima
        }

        return resp; // qualquer outro status (200, 400, 500…) encerra o loop
      } catch (e) {
        debugPrint('GeminiKey: erro na chave ${i + 1}: $e');
        rethrow;
      }
    }

    // Todas as chaves retornaram 429
    throw GeminiCotaEsgotadaException(ultimaResposta);
  }

  // ── Persistência de chaves ─────────────────────────────────────────────────

  static Future<void> salvarChaves(List<String> chaves) async {
    for (var i = 0; i < _prefixos.length; i++) {
      final v = i < chaves.length ? chaves[i].trim() : '';
      if (v.isNotEmpty) {
        await _secure.write(key: _prefixos[i], value: v);
      } else {
        await _secure.delete(key: _prefixos[i]);
      }
    }
    // Atualiza legada com a primeira chave para não quebrar integrações antigas
    if (chaves.isNotEmpty && chaves[0].trim().isNotEmpty) {
      await _secure.write(key: _legacyKey, value: chaves[0].trim());
    } else {
      await _secure.delete(key: _legacyKey);
    }
  }

  static Future<List<String>> carregarChavesSalvas() async {
    await _migrarSePreciso();
    final resultado = <String>[];
    for (final k in _prefixos) {
      resultado.add(await _secure.read(key: k) ?? '');
    }
    // Se todos os slots novos estão vazios, tenta a legada no slot 1
    if (resultado.every((v) => v.isEmpty)) {
      resultado[0] = await _secure.read(key: _legacyKey) ?? '';
    }
    return resultado;
  }
}

// ── Exceções ───────────────────────────────────────────────────────────────────

/// Extrai JSON puro de uma resposta que pode vir com markdown (```json ... ```)
String geminiExtrairJson(String text) {
  final t = text.trim();
  // Remove bloco markdown ```json ... ``` ou ``` ... ```
  final re = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
  final match = re.firstMatch(t);
  if (match != null) return match.group(1)!.trim();
  return t;
}

class GeminiSemChaveException implements Exception {
  @override
  String toString() =>
      'Chave Gemini não configurada. Configure em Configurações → IA.';
}

class GeminiCotaEsgotadaException implements Exception {
  final http.Response? ultimaResposta;
  const GeminiCotaEsgotadaException([this.ultimaResposta]);
  @override
  String toString() =>
      'Cota de todas as chaves Gemini esgotada. Tente novamente amanhã.';
}

class GeminiException implements Exception {
  final int statusCode;
  final String body;
  const GeminiException(this.statusCode, this.body);
  @override
  String toString() => 'Gemini HTTP $statusCode: $body';
}
