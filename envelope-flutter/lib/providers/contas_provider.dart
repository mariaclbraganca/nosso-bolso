import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/financeiro_ext_service.dart';
import 'usuarios_provider.dart';

final contasMesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, mes) async {
  final perfil    = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  final familiaId = perfil?['familia_id'] as String? ?? '';
  if (familiaId.isEmpty) return [];
  return FinanceiroExtService.getContas(familiaId, mes: mes);
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
