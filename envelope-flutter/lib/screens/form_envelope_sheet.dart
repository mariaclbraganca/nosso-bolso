import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../providers/usuarios_provider.dart';
import 'abastecer_sheet.dart';

class FormEnvelopeSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? envelope;
  const FormEnvelopeSheet({super.key, this.envelope});

  @override
  ConsumerState<FormEnvelopeSheet> createState() => _FormEnvelopeSheetState();
}

class _FormEnvelopeSheetState extends ConsumerState<FormEnvelopeSheet> {
  final _nomeController = TextEditingController();
  final _valorController = TextEditingController();
  final _objetivoController = TextEditingController();
  String _emoji = '📦';
  bool _isSaving = false;
  bool _isReserva = false;
  bool get _isEditing => widget.envelope != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nomeController.text = widget.envelope!['nome_envelope'];
      _valorController.text = widget.envelope!['valor_planejado'].toString();
      _emoji = widget.envelope!['emoji'] ?? '📦';
      _isReserva = widget.envelope!['is_reserva'] ?? false;
      _objetivoController.text = widget.envelope!['valor_objetivo']?.toString() ?? '';
    }
  }

  void _salvar() async {
    final nome = _nomeController.text.trim();
    final valorPlanejado = double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0.0;
    final valorObjetivo = double.tryParse(_objetivoController.text.replaceAll(',', '.')) ?? 0.0;
    
    final perfil = ref.read(perfilUsuarioLogadoProvider).value;
    if (perfil == null || perfil['familia_id'] == null) return;
    if (nome.isEmpty || valorPlanejado <= 0) return;

    setState(() => _isSaving = true);
    try {
      final data = {
        'nome_envelope': nome,
        'valor_planejado': valorPlanejado,
        'emoji': _emoji,
        'is_reserva': _isReserva,
        'valor_objetivo': _isReserva ? valorObjetivo : null,
      };

      if (_isEditing) {
        await ApiService.put('/envelopes/${widget.envelope!['id']}', data);
      } else {
        data['familia_id'] = perfil['familia_id'];
        await ApiService.post('/envelopes/', data);
      }

      if (mounted) {
        Navigator.pop(context);
        if (!_isEditing) _showAbastecerPrompt();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red));
      }
    }
  }

  void _deletar() async {
    setState(() => _isSaving = true);
    try {
      await ApiService.delete('/envelopes/${widget.envelope!['id']}');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red));
      }
    }
  }

  void _showAbastecerPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Envelope criado!'),
        backgroundColor: AppColors.card,
        content: const Text('Deseja abastecer este envelope agora com saldo do Saldo Geral?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Depois', style: TextStyle(color: AppColors.mu))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const AbastecerSheet(),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.acc),
            child: const Text('Abastecer agora', style: TextStyle(color: AppColors.bg)),
          ),
        ],
      ),
    );
  }

  Widget _buildReservaToggle() {
    return SwitchListTile(
      title: const Text('É Reserva?', style: TextStyle(color: Colors.white)),
      value: _isReserva,
      onChanged: (v) => setState(() => _isReserva = v),
      activeColor: AppColors.acc,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(bottom: 20)),
            Text(_isEditing ? 'Editar Envelope 📦' : 'Novo Envelope 📦', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            TextField(
              controller: _nomeController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'NOME DO ENVELOPE',
                labelStyle: const TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: AppColors.surf,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _valorController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: r'META MENSAL (R$)',
                      labelStyle: const TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: AppColors.surf,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 58,
                    decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Ícone:'),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _emoji,
                          dropdownColor: AppColors.card,
                          underline: const SizedBox(),
                          items: ['📦', '💊', '🍎', '🏠', '🚗', '🎮', '💡', '🧼'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setState(() => _emoji = v!),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            _buildReservaToggle(),
            
            if (_isReserva) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _objetivoController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'VALOR OBJETIVO (META TOTAL)',
                  hintText: 'R\$ 0,00',
                  labelStyle: const TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold),
                  filled: true,
                  fillColor: AppColors.surf,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _salvar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.acc,
                minimumSize: const Size.fromHeight(55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving 
                ? const CircularProgressIndicator(color: AppColors.bg)
                : Text(_isEditing ? 'Salvar alterações' : 'Criar envelope', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.bg)),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSaving ? null : _deletar,
                child: const Text('EXCLUIR ENVELOPE', style: TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
