import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/financeiro_ext_service.dart';
import '../services/notification_service.dart';
import 'usuarios_provider.dart';

final contasMesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, mes) async {
  final perfil    = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  final familiaId = perfil?['familia_id'] as String? ?? '';
  if (familiaId.isEmpty) return [];
  final contas = await FinanceiroExtService.getContas(familiaId, mes: mes);
  // Reagenda alertas de vencimento para todas as contas não pagas
  for (final c in contas) {
    if (c['pago'] == true) continue;
    final vencStr = c['data_vencimento'] as String?;
    // O id da conta é UUID (String). Deriva um int estável e não-negativo
    // para usar como ID da notificação local (que exige int).
    final idRaw = c['id'];
    final id = idRaw is int ? idRaw : (idRaw?.toString().hashCode ?? 0).abs() % 100000;
    final nome    = c['nome'] as String? ?? 'Conta';
    final valor   = (c['valor'] as num?)?.toDouble() ?? 0.0;
    if (vencStr == null || idRaw == null) continue;
    final venc = DateTime.tryParse(vencStr);
    if (venc == null) continue;
    await NotificationService.agendarAlertaConta(
      contaId:   id,
      nomeConta: nome,
      valor:     valor,
      vencimento: venc,
    );
  }
  return contas;
});

final resumoContasProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, mes) async {
  final perfil    = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  final familiaId = perfil?['familia_id'] as String? ?? '';
  if (familiaId.isEmpty) return {};
  return FinanceiroExtService.getResumoContas(familiaId, mes);
});

const List<Map<String, String>> categoriasContas = [
  {'id': 'aluguel',        'nome': 'Aluguel',         'emoji': '🏠'},
  {'id': 'energia',        'nome': 'Energia',          'emoji': '⚡'},
  {'id': 'agua',           'nome': 'Água',             'emoji': '💧'},
  {'id': 'internet',       'nome': 'Internet',         'emoji': '📡'},
  {'id': 'telefone',       'nome': 'Telefone',         'emoji': '📱'},
  {'id': 'cartao_credito', 'nome': 'Cartão',           'emoji': '💳'},
  {'id': 'saude',          'nome': 'Saúde',            'emoji': '🏥'},
  {'id': 'educacao',       'nome': 'Educação',         'emoji': '📚'},
  {'id': 'transporte',     'nome': 'Transporte',       'emoji': '🚗'},
  {'id': 'seguro',         'nome': 'Seguro',           'emoji': '🛡️'},
  {'id': 'streaming',      'nome': 'Streaming',        'emoji': '🎬'},
  {'id': 'academia',       'nome': 'Academia',         'emoji': '💪'},
  {'id': 'outro',          'nome': 'Outro',            'emoji': '📋'},
];

String emojiCategoria(String? cat) {
  return categoriasContas.firstWhere(
    (c) => c['id'] == cat,
    orElse: () => {'emoji': '📋'},
  )['emoji']!;
}
