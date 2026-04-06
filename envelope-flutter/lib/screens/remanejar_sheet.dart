import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../providers/envelopes_provider.dart';
import '../providers/usuarios_provider.dart';

class RemanejarSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> origem;

  const RemanejarSheet({super.key, required this.origem});

  @override
  ConsumerState<RemanejarSheet> createState() => _RemanejarSheetState();
}

class _RemanejarSheetState extends ConsumerState<RemanejarSheet> {
  final _valController = TextEditingController();
  Map<String, dynamic>? _destino;
  bool _isSaving = false;

  void _confirmar() async {
    final valor = double.tryParse(_valController.text.replaceAll(',', '.')) ?? 0;
    final perfil = ref.read(perfilUsuarioLogadoProvider).value;

    if (_destino == null || valor <= 0 || perfil == null) return;

    setState(() => _isSaving = true);
    try {
      await ApiService.post('/remanejar/', {
        'origem_id': widget.origem['id'],
        'destino_id': _destino!['id'],
        'valor': valor,
        'familia_id': perfil['familia_id'],
        'usuario_id': perfil['auth_id'],
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo transferido!'), backgroundColor: AppColors.grn),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final envelopes = ref.watch(envelopesProvider).value ?? [];
    final destinos = envelopes.where((e) => e['id'] != widget.origem['id']).toList();

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(bottom: 20)),
          const Text('Remanejar Saldo ↔️', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          _buildInfoRow(),
          const SizedBox(height: 20),
          
          DropdownButtonFormField<Map<String, dynamic>>(
            value: _destino,
            dropdownColor: AppColors.card,
            decoration: InputDecoration(
              labelText: 'DESTINO',
              labelStyle: const TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold),
              filled: true,
              fillColor: AppColors.surf,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            items: destinos.map((e) => DropdownMenuItem(value: e, child: Text('${e['emoji']} ${e['nome_envelope']}'))).toList(),
            onChanged: (v) => setState(() => _destino = v),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _valController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.acc),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'R\$ 0,00',
              labelText: 'VALOR A MOVER',
              labelStyle: const TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold),
              filled: true,
              fillColor: AppColors.surf,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _confirmar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.acc,
              minimumSize: const Size.fromHeight(55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSaving 
              ? const CircularProgressIndicator(color: AppColors.bg) 
              : const Text('Transferir Agora', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.bg)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: AppColors.org, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Removendo de ${widget.origem['nome_envelope']}\nSaldo disponível: R\$ ${widget.origem['saldo_atual']}',
            style: const TextStyle(fontSize: 12, color: AppColors.mu),
          ),
        ),
      ],
    ),
  );
}
