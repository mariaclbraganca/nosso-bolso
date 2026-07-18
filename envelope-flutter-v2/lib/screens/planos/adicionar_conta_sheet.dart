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
  ConsumerState<AdicionarContaSheet> createState() =>
      _AdicionarContaSheetState();
}

class _AdicionarContaSheetState
    extends ConsumerState<AdicionarContaSheet> {
  final _nomeCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  DateTime? _vencimento;
  String _categoria = 'outro';
  bool _recorrente = false;
  bool _salvando = false;

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
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 20,
        left: AppSpacing.pagePad,
        right: AppSpacing.pagePad,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(),
            const SizedBox(height: 16),
            Text('Nova Conta', style: AppTextStyles.titleSm),
            const SizedBox(height: 4),
            Text(
              'Adicione contas a pagar deste mês',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 20),
            _field(_nomeCtrl, 'Nome da conta',
                Icons.receipt_long_rounded),
            const SizedBox(height: 12),
            _field(_valorCtrl, 'Valor (R\$)',
                Icons.attach_money_rounded,
                numeric: true),
            const SizedBox(height: 12),
            _datePicker(),
            const SizedBox(height: 16),
            Text('Categoria',
                style: AppTextStyles.caption
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _categoriaSelector(),
            const SizedBox(height: 12),
            _recorrenteTile(),
            const SizedBox(height: 24),
            _saveButton(),
          ],
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.bord,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool numeric = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.mu),
        prefixIcon: Icon(icon, color: AppColors.mu, size: 18),
        filled: true,
        fillColor: AppColors.surf,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppSpacing.radiusInput),
          borderSide:
              const BorderSide(color: AppColors.bord, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppSpacing.radiusInput),
          borderSide:
              const BorderSide(color: AppColors.bord, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(AppSpacing.radiusInput),
          borderSide:
              const BorderSide(color: AppColors.acc, width: 1.5),
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
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate:
              DateTime.now().add(const Duration(days: 365 * 2)),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                  primary: AppColors.acc),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _vencimento = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surf,
          borderRadius:
              BorderRadius.circular(AppSpacing.radiusInput),
          border:
              Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded,
              color: AppColors.mu, size: 18),
          const SizedBox(width: 10),
          Text(
            texto,
            style: AppTextStyles.body.copyWith(
              color: _vencimento == null
                  ? AppColors.mu
                  : AppColors.tx,
            ),
          ),
        ]),
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
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: sel
                  ? AppColors.acc.withOpacity(0.2)
                  : AppColors.surf,
              borderRadius: BorderRadius.circular(
                  AppSpacing.radiusChip),
              border: Border.all(
                color: sel ? AppColors.acc : AppColors.bord,
                width: sel ? 1.5 : 0.5,
              ),
            ),
            child: Text(
              '${cat['emoji']} ${cat['nome']}',
              style: AppTextStyles.caption.copyWith(
                color: sel ? AppColors.acc : AppColors.mu,
                fontWeight: sel
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _recorrenteTile() {
    return GestureDetector(
      onTap: () =>
          setState(() => _recorrente = !_recorrente),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surf,
          borderRadius:
              BorderRadius.circular(AppSpacing.radiusInput),
          border:
              Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Row(children: [
          const Icon(Icons.repeat_rounded,
              color: AppColors.mu, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Conta recorrente (mensal)',
              style: AppTextStyles.body,
            ),
          ),
          Switch(
            value: _recorrente,
            onChanged: (v) =>
                setState(() => _recorrente = v),
            activeColor: AppColors.acc,
          ),
        ]),
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _salvando ? null : _salvar,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.acc,
          foregroundColor: AppColors.bg,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppSpacing.radiusBtn),
          ),
        ),
        icon: _salvando
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.bg))
            : const Icon(Icons.check_rounded),
        label: Text(
          _salvando ? 'Salvando...' : 'Adicionar Conta',
          style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.bg),
        ),
      ),
    );
  }

  Future<void> _salvar() async {
    final nome = _nomeCtrl.text.trim();
    final valor =
        double.tryParse(_valorCtrl.text.replaceAll(',', '.'));
    if (nome.isEmpty || valor == null || _vencimento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha nome, valor e vencimento'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    final perfil =
        ref.read(perfilUsuarioLogadoProvider).asData?.value;
    final familiaId =
        perfil?['familia_id'] as String? ?? '';
    if (familiaId.isEmpty) return;

    setState(() => _salvando = true);
    try {
      final vencStr =
          '${_vencimento!.year}-${_vencimento!.month.toString().padLeft(2, '0')}-${_vencimento!.day.toString().padLeft(2, '0')}';

      final doc = await FinanceiroExtService.criarConta({
        'familia_id': familiaId,
        'nome': nome,
        'valor': valor,
        'vencimento': vencStr,
        'categoria': _categoria,
        'recorrente': _recorrente,
      });

      // Agenda notificação 2 dias antes
      await NotificationService.agendarAlertaConta(
        contaId: doc['_id'].hashCode.abs(),
        nomeConta: nome,
        valor: valor,
        vencimento: _vencimento!,
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}
