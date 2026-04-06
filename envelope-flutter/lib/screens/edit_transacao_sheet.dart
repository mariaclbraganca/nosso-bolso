import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../providers/mes_provider.dart';
import '../providers/transacoes_provider.dart';

class EditTransacaoSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> transacao;

  const EditTransacaoSheet({super.key, required this.transacao});

  @override
  ConsumerState<EditTransacaoSheet> createState() => _EditTransacaoSheetState();
}

class _EditTransacaoSheetState extends ConsumerState<EditTransacaoSheet> {
  late TextEditingController _valController;
  late TextEditingController _obsController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _valController = TextEditingController(text: widget.transacao['valor'].toString());
    _obsController = TextEditingController(text: widget.transacao['descricao'] ?? '');
  }

  @override
  void dispose() {
    _valController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  void _salvar() async {
    final valor = double.tryParse(_valController.text.replaceAll(',', '.')) ?? 0;
    if (valor <= 0 || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await ApiService.put('/transacoes/${widget.transacao['id']}', {
        'valor': valor,
        'descricao': _obsController.text,
      });

      if (!mounted) return;
      // REGRA REALTIME_ONLY: O stream do Supabase atualizará a UI automaticamente.
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transação atualizada!'), backgroundColor: AppColors.grn),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDespesa = widget.transacao['tipo'] == 'despesa';
    final cor = isDespesa ? AppColors.red : AppColors.grn;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(bottom: 20)),
          Text('Editar ${isDespesa ? 'Despesa' : 'Receita'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildValorInput(cor),
          const SizedBox(height: 24),
          _buildObsInput(),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _salvar,
            style: ElevatedButton.styleFrom(
              backgroundColor: cor,
              minimumSize: const Size.fromHeight(55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSaving 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text('Salvar Alterações', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildValorInput(Color cor) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text('R\$', style: TextStyle(fontSize: 20, color: cor.withOpacity(0.5))),
      const SizedBox(width: 8),
      SizedBox(
        width: 150,
        child: TextField(
          controller: _valController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: cor),
          decoration: const InputDecoration(border: InputBorder.none, hintText: '0.00'),
        ),
      ),
    ],
  );

  Widget _buildObsInput() => TextField(
    controller: _obsController,
    style: const TextStyle(fontSize: 15),
    decoration: InputDecoration(
      hintText: 'Descrição',
      filled: true,
      fillColor: AppColors.surf,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
  );
}
