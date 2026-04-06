import 'package:envelope_flutter/providers/usuarios_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/forms/origin_selector.dart';
import '../constants.dart';
import 'abastecer_sheet.dart';

class FormReceitaScreen extends ConsumerStatefulWidget {
  const FormReceitaScreen({super.key});
  @override
  ConsumerState<FormReceitaScreen> createState() => _FormReceitaScreenState();
}

class _FormReceitaScreenState extends ConsumerState<FormReceitaScreen> {
  final _valController = TextEditingController();
  final _obsController = TextEditingController();
  final _focusNode = FocusNode();
  String _origem = 'Salário';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () => _focusNode.requestFocus());
  }

  void _salvar() async {
    final valor = double.tryParse(_valController.text.replaceAll(',', '.')) ?? 0;
    if (valor <= 0 || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final perfil = ref.read(perfilUsuarioLogadoProvider).value;
      if (perfil == null || perfil['familia_id'] == null) throw 'Usuário sem família vinculada';
      final usuarioId = perfil['id'];

      await supabase.from('transacoes').insert({
        'valor': valor,
        'tipo': 'receita',
        'usuario_id': usuarioId,
        'envelope_id': null,
        'descricao': '$_origem${_obsController.text.isNotEmpty ? ' - ${_obsController.text}' : ''}',
        'familia_id': perfil['familia_id'],
      });

      if (!mounted) return;
      Navigator.pop(context);
      _mostrarPromptDistribuicao(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _mostrarPromptDistribuicao(BuildContext context) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Receita Registrada! 💰', style: TextStyle(color: AppColors.grn)),
        content: const Text('Dinheiro adicionado ao Saldo Geral. Deseja distribuir nos envelopes agora?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('DEPOIS', style: TextStyle(color: AppColors.mu))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const AbastecerSheet());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.grn),
            child: const Text('SIM, DISTRIBUIR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          const Text('Registrar receita 💰', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('vai direto para o Saldo Geral ⚡', style: TextStyle(fontSize: 12, color: AppColors.mu)),
          const SizedBox(height: 18),
          _buildValorInput(),
          const Divider(color: AppColors.bord),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          _buildLabel('ORIGEM'),
          OriginSelector(selected: _origem, onSelected: (l, e) => setState(() { _origem = l; })),
          const SizedBox(height: 16),
          _buildObsInput(),
          const SizedBox(height: 14),
          _buildSubmitButton(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildHandle() => Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(bottom: 20));
  Widget _buildLabel(String text) => Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.mu, fontWeight: FontWeight.bold, letterSpacing: 0.5))));
  
  Widget _buildValorInput() => Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
    const Text(r'R$', style: TextStyle(fontSize: 20, color: AppColors.mu)),
    const SizedBox(width: 4),
    SizedBox(width: 200, child: TextField(controller: _valController, focusNode: _focusNode, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.grn, letterSpacing: -1), decoration: const InputDecoration(hintText: '0,00', hintStyle: TextStyle(color: AppColors.mu), border: InputBorder.none))),
  ]);

  Widget _buildObsInput() => TextField(controller: _obsController, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: 'Observação (opcional)', hintStyle: const TextStyle(color: AppColors.mu), filled: true, fillColor: AppColors.surf, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.bord))));

  Widget _buildSubmitButton() => ElevatedButton(onPressed: _isSaving ? null : _salvar, style: ElevatedButton.styleFrom(backgroundColor: AppColors.grn, minimumSize: const Size.fromHeight(55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirmar receita', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)));
}
