import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../providers/transacoes_provider.dart';
import '../providers/usuarios_provider.dart';
import '../theme/app_theme.dart';

class LixeiraScreen extends ConsumerStatefulWidget {
  const LixeiraScreen({super.key});

  @override
  ConsumerState<LixeiraScreen> createState() => _LixeiraScreenState();
}

class _LixeiraScreenState extends ConsumerState<LixeiraScreen> {
  bool _isLoading = true;
  List<dynamic> _itens = [];

  @override
  void initState() {
    super.initState();
    _carregarLixeira();
  }

  Future<void> _carregarLixeira() async {
    setState(() => _isLoading = true);
    try {
      final perfil = ref.read(perfilUsuarioLogadoProvider).value;
      if (perfil == null) return;
      
      final res = await ApiService.get('/transacoes/lixeira', perfil['familia_id']);
      setState(() {
        _itens = res;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      setState(() => _isLoading = false);
    }
  }

  void _restaurar(String id) async {
    try {
      final perfil = ref.read(perfilUsuarioLogadoProvider).value;
      await ApiService.post('/transacoes/$id/restaurar?familia_id=${perfil?['familia_id']}', {});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transação restaurada!')));
        _carregarLixeira();
        ref.invalidate(pagedTransacoesProvider);
        ref.invalidate(statsPorMesProvider);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LIXEIRA', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _carregarLixeira),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _itens.isEmpty 
          ? const Center(child: Text('A lixeira está vazia', style: TextStyle(color: AppColors.mu)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _itens.length,
              itemBuilder: (context, index) {
                final t = _itens[index];
                final valor = (t['valor'] as num).toDouble();
                final isDespesa = t['tipo'] == 'despesa';
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.surf,
                      child: Text(t['envelopes']?['emoji'] ?? '📦'),
                    ),
                    title: Text(t['descricao'] ?? 'Sem descrição', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(t['deleted_at']))),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          NumberFormat.simpleCurrency(locale: 'pt_BR').format(valor),
                          style: TextStyle(
                            color: isDespesa ? AppColors.red : AppColors.grn,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.restore, color: AppColors.acc),
                          onPressed: () => _restaurar(t['id']),
                          tooltip: 'Restaurar',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
