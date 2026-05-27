import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/usuarios_provider.dart';
import '../../providers/contas_provider.dart';
import '../../services/financeiro_ext_service.dart';
import '../../services/notification_service.dart';

class AdicionarContaSheet extends ConsumerStatefulWidget {
  final String mes; // YYYY-MM
  const AdicionarContaSheet({super.key, required this.mes});

  @override
  ConsumerState<AdicionarContaSheet> createState() => _AdicionarContaSheetState();
}

class _AdicionarContaSheetState extends ConsumerState<AdicionarContaSheet> {
  final _nomeCtrl  = TextEditingController();
  final _valorCtrl = TextEditingController();
  DateTime? _vencimento;
  String _categoria = 'outro';
  bool _recorrente  = false;
  bool _salvando    = false;

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
            const Text('Nova Conta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.tx)),
            const SizedBox(height: 16),
            _field(_nomeCtrl, 'Nome da conta', Icons.receipt_long_rounded),
            const SizedBox(height: 12),
            _field(_valorCtrl, 'Valor (R\$)', Icons.attach_money_rounded, numeric: true),
            const SizedBox(height: 12),
            _datePicker(),
            const SizedBox(height: 12),
            _categoriaSelector(),
            const SizedBox(height: 12),
            _recorrenteTile(),
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

  Widget _field(TextEditingController ctrl, String hint, IconData icon, {bool numeric = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(color: AppColors.tx),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.mu),
        prefixIcon: Icon(icon, color: AppColors.mu, size: 18),
        filled: true,
        fillColor: AppColors.surf,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.bord, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.bord, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.blu, width: 1),
        ),
      ),
    );
  }

  Widget _datePicker() {
    final texto = _vencimento == null
        ? 'Vencimento'
        : '${_vencimento!.day.toString().padLeft(2, '0')}/${_vencimento!.month.toString().padLeft(2, '0')}/${_vencimento!.year}';

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: AppColors.acc),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _vencimento = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surf,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: AppColors.mu, size: 18),
            const SizedBox(width: 10),
            Text(texto, style: TextStyle(color: _vencimento == null ? AppColors.mu : AppColors.tx)),
          ],
        ),
      ),
    );
  }

  Widget _categoriaSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categoriasContas.map((cat) {
        final sel = cat['id'] == _categoria;
        return GestureDetector(
          onTap: () => setState(() => _categoria = cat['id']!),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? AppColors.blu.withOpacity(0.2) : AppColors.surf,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? AppColors.blu : AppColors.bord, width: sel ? 1.5 : 0.5),
            ),
            child: Text(
              '${cat['emoji']} ${cat['nome']}',
              style: TextStyle(fontSize: 12, color: sel ? AppColors.blu : AppColors.mu),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _recorrenteTile() {
    return GestureDetector(
      onTap: () => setState(() => _recorrente = !_recorrente),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surf,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.repeat_rounded, color: AppColors.mu, size: 18),
            const SizedBox(width: 10),
            const Expanded(child: Text('Conta recorrente (mensal)', style: TextStyle(color: AppColors.tx, fontSize: 14))),
            Switch(value: _recorrente, onChanged: (v) => setState(() => _recorrente = v), activeColor: AppColors.acc),
          ],
        ),
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _salvando ? null : _salvar,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blu,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: _salvando
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_rounded),
        label: Text(_salvando ? 'Salvando...' : 'Adicionar Conta', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Future<void> _salvar() async {
    final nome  = _nomeCtrl.text.trim();
    final valor = double.tryParse(_valorCtrl.text.replaceAll(',', '.'));
    if (nome.isEmpty || valor == null || _vencimento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha nome, valor e vencimento'), backgroundColor: AppColors.red),
      );
      return;
    }

    final perfil    = ref.read(perfilUsuarioLogadoProvider).asData?.value;
    final familiaId = perfil?['familia_id'] as String? ?? '';
    if (familiaId.isEmpty) return;

    setState(() => _salvando = true);
    try {
      final vencStr = '${_vencimento!.year}-${_vencimento!.month.toString().padLeft(2, '0')}-${_vencimento!.day.toString().padLeft(2, '0')}';
      final doc = await FinanceiroExtService.criarConta({
        'familia_id': familiaId,
        'nome':       nome,
        'valor':      valor,
        'vencimento': vencStr,
        'categoria':  _categoria,
        'recorrente': _recorrente,
      });

      // Agenda notificação 2 dias antes
      await NotificationService.agendarAlertaConta(
        contaId:   doc['_id'].hashCode,
        nomeConta: nome,
        valor:     valor,
        vencimento: _vencimento!,
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
      );
    }
  }
}
