import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/financeiro_ext_service.dart';
import 'usuarios_provider.dart';

final metasProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final perfil    = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  final familiaId = perfil?['familia_id'] as String? ?? '';
  if (familiaId.isEmpty) return [];
  return FinanceiroExtService.getMetas(familiaId);
});

const List<Map<String, String>> emojisMetaSugestao = [
  {'emoji': '✈️', 'nome': 'Viagem'},
  {'emoji': '🏠', 'nome': 'Casa'},
  {'emoji': '🚗', 'nome': 'Carro'},
  {'emoji': '📱', 'nome': 'Eletrônico'},
  {'emoji': '🎓', 'nome': 'Educação'},
  {'emoji': '💍', 'nome': 'Casamento'},
  {'emoji': '🏖️', 'nome': 'Férias'},
  {'emoji': '🏋️', 'nome': 'Saúde'},
  {'emoji': '🎯', 'nome': 'Meta'},
  {'emoji': '💰', 'nome': 'Reserva'},
];

const List<Map<String, String>> coresMeta = [
  {'hex': '#60A5FA', 'nome': 'Azul'},
  {'hex': '#4CAF50', 'nome': 'Verde'},
  {'hex': '#FF9800', 'nome': 'Laranja'},
  {'hex': '#A78BFA', 'nome': 'Roxo'},
  {'hex': '#EF4444', 'nome': 'Vermelho'},
  {'hex': '#EC4899', 'nome': 'Rosa'},
  {'hex': '#14B8A6', 'nome': 'Teal'},
  {'hex': '#F59E0B', 'nome': 'Amarelo'},
];
