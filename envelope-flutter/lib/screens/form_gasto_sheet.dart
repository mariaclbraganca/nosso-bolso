import '../providers/usuarios_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/envelopes_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../constants.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class FormGastoSheet extends ConsumerStatefulWidget {
  final String? initialEnvelopeId; 
  const FormGastoSheet({super.key, this.initialEnvelopeId});
  
  @override
  ConsumerState<FormGastoSheet> createState() => _FormGastoSheetState();
}

class _FormGastoSheetState extends ConsumerState<FormGastoSheet> {
  final _valController = TextEditingController();
  final _descController = TextEditingController();
  final _focusNode = FocusNode();
  String? _selectedEnvelopeId;
  bool _isSaving = false;
  XFile? _image;

  @override
  void initState() {
    super.initState();
    _selectedEnvelopeId = widget.initialEnvelopeId; // Inicializa com o parâmetro
    Future.delayed(const Duration(milliseconds: 100), () => _focusNode.requestFocus());
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (image != null) {
      setState(() => _image = image);
    }
  }

  void _confirmar() async {
    final valor = double.tryParse(_valController.text.replaceAll(',', '.')) ?? 0.0;
    if (valor <= 0 || _selectedEnvelopeId == null) return;

    setState(() => _isSaving = true);
    try {
      final perfil = ref.read(perfilUsuarioLogadoProvider).value;
      if (perfil == null || perfil['familia_id'] == null) throw 'Usuário sem família vinculada';

      String? imageUrl;
      if (_image != null) {
        final bytes = await _image!.readAsBytes();
        final fileExt = _image!.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = '${perfil['familia_id']}/$fileName';

        await supabase.storage.from('comprovantes').uploadBinary(filePath, bytes);
        imageUrl = supabase.storage.from('comprovantes').getPublicUrl(filePath);
      }

      await supabase.from('transacoes').insert({
        'valor': valor,
        'tipo': 'despesa',
        'envelope_id': _selectedEnvelopeId,
        'usuario_id': perfil['id'],
        'descricao': _descController.text.isEmpty ? 'Compra' : _descController.text,
        'familia_id': perfil['familia_id'],
        'comprovante_url': imageUrl,
      });

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
    final envelopes = ref.watch(envelopesProvider).value ?? [];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(bottom: 20)),
          const Text('Registrar gasto 💸', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('máx. 4 toques ⚡', style: TextStyle(fontSize: 12, color: AppColors.mu)),
          const SizedBox(height: 18),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(r'R$', style: TextStyle(fontSize: 20, color: AppColors.mu)),
              const SizedBox(width: 4),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _valController,
                  focusNode: _focusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.tx, letterSpacing: -1),
                  decoration: const InputDecoration(hintText: '0,00', hintStyle: TextStyle(color: AppColors.mu), border: InputBorder.none),
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.bord),
          const SizedBox(height: 16),

          const Align(alignment: Alignment.centerLeft, child: Text('ENVELOPE', style: TextStyle(fontSize: 11, color: AppColors.mu, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
          const SizedBox(height: 10),
          
          SizedBox(
            height: 160,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 7, crossAxisSpacing: 7, childAspectRatio: 4),
              itemCount: envelopes.length,
              itemBuilder: (ctx, i) {
                final e = envelopes[i];
                final isSelected = _selectedEnvelopeId == e['id'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedEnvelopeId = e['id']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.acc.withOpacity(0.1) : AppColors.surf,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppColors.acc : AppColors.bord, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Text(e['emoji'] ?? '📦', style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(e['nome_envelope'].split(' ')[0], style: TextStyle(fontSize: 12, color: AppColors.tx, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _descController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Descrição (opcional)',
                    hintStyle: const TextStyle(color: AppColors.mu),
                    filled: true,
                    fillColor: AppColors.surf,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.bord)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _pickImage,
                icon: Icon(Icons.camera_alt_outlined, color: _image != null ? AppColors.grn : AppColors.mu),
                style: IconButton.styleFrom(backgroundColor: AppColors.surf, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), minimumSize: const Size(48, 48)),
              ),
            ],
          ),
          if (_image != null) ...[
            const SizedBox(height: 10),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_image!.path), height: 80, width: 80, fit: BoxFit.cover),
                ),
                Positioned(
                  top: -5, right: -5,
                  child: IconButton(icon: const Icon(Icons.cancel, color: AppColors.red, size: 20), onPressed: () => setState(() => _image = null)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),

          ElevatedButton(
            onPressed: (_isSaving || _selectedEnvelopeId == null) ? null : _confirmar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              minimumSize: const Size.fromHeight(55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSaving 
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Registrar gasto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
