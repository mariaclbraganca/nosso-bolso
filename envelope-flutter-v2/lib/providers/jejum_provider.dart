import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../services/jejum_api_service.dart';
import '../theme/app_theme.dart';

typedef JejumArgs = ({String membroId, String familiaId});

final jejumConfigProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, JejumArgs>((ref, args) async {
  return JejumApiService.getConfig(args.membroId, args.familiaId);
});

/// Registro em andamento via Realtime — alimenta o timer ao vivo.
/// Emite null quando não há jejum ativo.
final jejumAtivoProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, membroId) {
  return supabase
      .from('jejum_registros')
      .stream(primaryKey: ['id'])
      .eq('usuario_id', membroId)
      .map((rows) {
        for (final r in rows) {
          if (r['status'] == 'em_andamento') return r;
        }
        return null;
      });
});

final jejumHistoricoProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, membroId) async {
  return JejumApiService.getHistorico(membroId);
});

final jejumInsightsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, membroId) async {
  return JejumApiService.getInsights(membroId);
});

final jejumTogetherProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, JejumArgs>((ref, args) async {
  return JejumApiService.getTogether(args.membroId, args.familiaId);
});

/// Visão rica do Fast Together — timers de ambos + stats do mês.
final jejumTogetherDuplaProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, JejumArgs>((ref, args) async {
  return JejumApiService.getTogetherDupla(args.membroId, args.familiaId);
});

/// Sugestão IA de protocolo (TDEE → protocolo + % aderência + justificativa).
final jejumSugestaoProtocoloProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, membroId) async {
  return JejumApiService.getSugestaoProtocolo(membroId);
});

/// Sugestão IA de horário de janela para (membro, protocolo).
final jejumSugestaoJanelaProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String membroId, String protocolo})>(
        (ref, args) async {
  return JejumApiService.getSugestaoJanela(args.membroId, args.protocolo);
});

// ─── Fases metabólicas ────────────────────────────────────────────────────────

class FaseMetabolica {
  final String nome;
  final String emoji;
  final Color cor;
  final double inicioHoras;

  const FaseMetabolica(this.nome, this.emoji, this.cor, this.inicioHoras);

  static const fases = [
    FaseMetabolica('Digestão', '🍽️', AppColors.org, 0),
    FaseMetabolica('Glicose em queda', '📉', AppColors.gold, 4),
    FaseMetabolica('Queima de gordura', '🔥', AppColors.acc, 8),
    FaseMetabolica('Cetose leve', '⚡', AppColors.blu, 12),
    FaseMetabolica('Autofagia', '✨', AppColors.pur, 16),
    FaseMetabolica('Autofagia profunda', '🌙', AppColors.pur, 20),
  ];

  static FaseMetabolica atual(Duration decorrido) {
    final h = decorrido.inMinutes / 60.0;
    return fases.lastWhere((f) => h >= f.inicioHoras, orElse: () => fases.first);
  }

  /// Próxima fase ou null quando já está na última.
  static FaseMetabolica? proxima(Duration decorrido) {
    final h = decorrido.inMinutes / 60.0;
    for (final f in fases) {
      if (h < f.inicioHoras) return f;
    }
    return null;
  }
}

// ─── Protocolos disponíveis ───────────────────────────────────────────────────

class ProtocoloJejum {
  final String id;
  final String label;
  final String descricao;
  final double? horas; // null = personalizado

  const ProtocoloJejum(this.id, this.label, this.descricao, this.horas);

  static const todos = [
    ProtocoloJejum('16_8', '16:8', 'Popular · Iniciante friendly', 16),
    ProtocoloJejum('14_10', '14:10', 'Mais suave · Ótimo para começar', 14),
    ProtocoloJejum('18_6', '18:6', 'Intermediário · +autofagia', 18),
    ProtocoloJejum('omad', 'OMAD', '1 refeição/dia · Avançado', 23),
    ProtocoloJejum('5_2', '5:2', '5 dias normal · 2 dias restrito', 24),
    ProtocoloJejum('personalizado', 'Personalizado', 'Defina X horas de jejum livremente', null),
  ];

  static ProtocoloJejum? porId(String? id) {
    for (final p in todos) {
      if (p.id == id) return p;
    }
    return null;
  }
}
