import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../providers/usuarios_provider.dart';

/// Bottom sheet para adicionar ou editar gasto fixo com isolamento por família
class FormFixoSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? fixo;
  const FormFixoSheet({super.key, this.fixo});

  @override
  ConsumerState<FormFixoSheet> createState() => _FormFixoSheetState();
}

class _FormFixoSheetState extends ConsumerState<FormFixoSheet> {
  final _nomeController = TextEditingController();
  final _valorController = TextEditingController();
  final _diaController = TextEditingController();
  bool _isSaving = false;
  bool _recorrente = false;
  bool get _isEditing => widget.fixo != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nomeController.text = widget.fixo!['nome'];
      _valorController.text = widget.fixo!['valor'].toString();
      _recorrente = widget.fixo!['recorrente'] ?? false;
      _diaController.text = widget.fixo!['dia_vencimento']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _valorController.dispose();
    _diaController.dispose();
    super.dispose();
  }

  void _salvar() async {
    final nome = _nomeController.text.trim();
    final valor = double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0.0;
    final dia = int.tryParse(_diaController.text) ?? DateTime.now().day;
    
    final perfil = ref.read(perfilUsuarioLogadoProvider).value;
    if (perfil == null || perfil['familia_id'] == null) return;

    if (nome.isEmpty || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha nome e valor'), backgroundColor: AppColors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        'nome': nome,
        'valor': valor,
        'recorrente': _recorrente,
        'dia_vencimento': dia,
      };

      if (_isEditing) {
        await ApiService.patch('/fixos/${widget.fixo!['id']}', payload);
      } else {
        final now = DateTime.now();
        final mes = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        payload['mes'] = mes;
        payload['familia_id'] = perfil['familia_id'];
        await ApiService.post('/fixos/', payload);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Alterações salvas' : '🔒 $nome adicionado — R\$ ${valor.toStringAsFixed(2)} reservado'), 
            backgroundColor: AppColors.acc
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red));
      }
    }
  }

  void _deletar() async {
    final perfil = ref.read(perfilUsuarioLogadoProvider).value;
    if (perfil == null || perfil['familia_id'] == null) return;

    setState(() => _isSaving = true);
    try {
      await ApiService.delete('/fixos/${widget.fixo!['id']}', familiaId: perfil['familia_id']);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 24),
      decoration: const BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(bottom: 20)),
            Text(_isEditing ? 'Editar Gasto Fixo 🔒' : 'Novo Gasto Fixo 🔒', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Será reservado automaticamente do saldo', style: TextStyle(fontSize: 12, color: AppColors.mu)),
            const SizedBox(height: 20),

            TextField(
              controller: _nomeController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'NOME DO GASTO',
                hintText: 'Ex: Plano de Saúde',
                hintStyle: const TextStyle(color: AppColors.mu),
                labelStyle: const TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: AppColors.surf,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _valorController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: r'VALOR MENSAL (R$)',
                hintText: '0,00',
                hintStyle: const TextStyle(color: AppColors.mu),
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
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.surf, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('RECORRENTE?', style: TextStyle(fontSize: 12, color: AppColors.mu)),
                        Switch(
                          value: _recorrente, 
                          onChanged: (v) => setState(() => _recorrente = v),
                          activeColor: AppColors.acc,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _diaController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'DIA VENC.',
                      hintText: '1-31',
                      labelStyle: const TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: AppColors.surf,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
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
                  : Text(_isEditing ? 'Salvar alterações' : 'Adicionar gasto fixo', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.bg)),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSaving ? null : _deletar,
                child: const Text('EXCLUIR GASTO FIXO', style: TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
