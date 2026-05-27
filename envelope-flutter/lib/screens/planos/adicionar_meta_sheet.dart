import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/usuarios_provider.dart';
import '../../providers/metas_provider.dart';
import '../../services/financeiro_ext_service.dart';

class AdicionarMetaSheet extends ConsumerStatefulWidget {
  const AdicionarMetaSheet({super.key});

  @override
  ConsumerState<AdicionarMetaSheet> createState() => _AdicionarMetaSheetState();
}

class _AdicionarMetaSheetState extends ConsumerState<AdicionarMetaSheet> {
  final _nomeCtrl  = TextEditingController();
  final _valorCtrl = TextEditingController();
  String _emoji    = '🎯';
  String _cor      = '#60A5FA';
  bool _salvando   = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 20, left: 20, right: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(),
            const SizedBox(height: 12),
            const Text('Nova Meta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.tx)),
            const SizedBox(height: 16),
            _emojiPicker(),
            const SizedBox(height: 12),
            _field(_nomeCtrl, 'Nome da meta (ex: Viagem a Portugal)'),
            const SizedBox(height: 12),
            _field(_valorCtrl, 'Valor alvo (R\$)', numeric: true),
            const SizedBox(height: 12),
            _corPicker(),
            const SizedBox(height: 20),
            _saveButton(),
          ],
        ),
      ),
    );
  }

  Widget _handle() => Center(
    child: Container(
      width: 36, height: 4,
      decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2)),
    ),
  );

  Widget _field(TextEditingController ctrl, String hint, {bool numeric = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(color: AppColors.tx),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.mu),
        filled: true,
        fillColor: AppColors.surf,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.bord, width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.bord, width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.acc, width: 1)),
      ),
    );
  }

  Widget _emojiPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ícone', style: TextStyle(fontSize: 12, color: AppColors.mu)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: emojisMetaSugestao.map((e) {
            final sel = e['emoji'] == _emoji;
            return GestureDetector(
              onTap: () => setState(() => _emoji = e['emoji']!),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: sel ? AppColors.acc.withOpacity(0.2) : AppColors.surf,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? AppColors.acc : AppColors.bord, width: sel ? 1.5 : 0.5),
                ),
                child: Center(child: Text(e['emoji']!, style: const TextStyle(fontSize: 22))),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _corPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cor', style: TextStyle(fontSize: 12, color: AppColors.mu)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: coresMeta.map((c) {
            final hex = c['hex']!;
            final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
            final sel = hex == _cor;
            return GestureDetector(
              onTap: () => setState(() => _cor = hex),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: sel ? Colors.white : Colors.transparent,
                    width: sel ? 2.5 : 0,
                  ),
                  boxShadow: sel ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)] : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _salvando ? null : _salvar,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.acc,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: _salvando
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : const Icon(Icons.check_rounded),
        label: Text(_salvando ? 'Salvando...' : 'Criar Meta', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Future<void> _salvar() async {
    final nome  = _nomeCtrl.text.trim();
    final valor = double.tryParse(_valorCtrl.text.replaceAll(',', '.'));
    if (nome.isEmpty || valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o nome e o valor alvo'), backgroundColor: AppColors.red),
      );
      return;
    }

    final perfil    = ref.read(perfilUsuarioLogadoProvider).asData?.value;
    final familiaId = perfil?['familia_id'] as String? ?? '';
    if (familiaId.isEmpty) return;

    setState(() => _salvando = true);
    try {
      await FinanceiroExtService.criarMeta({
        'familia_id': familiaId,
        'nome':       nome,
        'emoji':      _emoji,
        'valor_meta': valor,
        'cor':        _cor,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
      );
    }
  }
}
