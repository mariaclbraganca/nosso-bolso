import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/usuarios_provider.dart';
import '../../providers/metas_provider.dart';
import '../../services/financeiro_ext_service.dart';

class AdicionarMetaSheet extends ConsumerStatefulWidget {
  const AdicionarMetaSheet({super.key});

  @override
  ConsumerState<AdicionarMetaSheet> createState() =>
      _AdicionarMetaSheetState();
}

class _AdicionarMetaSheetState
    extends ConsumerState<AdicionarMetaSheet> {
  final _nomeCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  String _emoji = '🎯';
  String _cor = '#9ED465';
  DateTime? _prazo;
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
            Text('Nova Meta', style: AppTextStyles.titleSm),
            const SizedBox(height: 4),
            Text(
              'Defina um objetivo financeiro',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 20),

            // Emoji picker
            Text(
              'Ícone',
              style: AppTextStyles.caption
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _emojiPicker(),
            const SizedBox(height: 16),

            // Nome
            _field(_nomeCtrl,
                'Nome da meta (ex: Viagem a Portugal)'),
            const SizedBox(height: 12),

            // Valor objetivo
            _field(
              _valorCtrl,
              'Valor objetivo (R\$)',
              numeric: true,
              prefix: Icons.savings_rounded,
            ),
            const SizedBox(height: 12),

            // Prazo (opcional)
            _prazoPicker(),
            const SizedBox(height: 16),

            // Cor
            Text(
              'Cor da meta',
              style: AppTextStyles.caption
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _corPicker(),
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
    String hint, {
    bool numeric = false,
    IconData? prefix,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            AppTextStyles.body.copyWith(color: AppColors.mu),
        prefixIcon: prefix != null
            ? Icon(prefix, color: AppColors.mu, size: 18)
            : null,
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

  Widget _emojiPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: emojisMetaSugestao.map((e) {
        final sel = e['emoji'] == _emoji;
        return GestureDetector(
          onTap: () => setState(() => _emoji = e['emoji']!),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: sel
                  ? AppColors.acc.withOpacity(0.2)
                  : AppColors.surf,
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(
                color: sel ? AppColors.acc : AppColors.bord,
                width: sel ? 1.5 : 0.5,
              ),
            ),
            child: Center(
              child: Text(e['emoji']!,
                  style: const TextStyle(fontSize: 22)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _prazoPicker() {
    final texto = _prazo == null
        ? 'Prazo (opcional)'
        : '${_prazo!.day.toString().padLeft(2, '0')}/${_prazo!.month.toString().padLeft(2, '0')}/${_prazo!.year}';

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate:
              DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now(),
          lastDate:
              DateTime.now().add(const Duration(days: 365 * 10)),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                  primary: AppColors.acc),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _prazo = picked);
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
          const Icon(Icons.event_rounded,
              color: AppColors.mu, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: AppTextStyles.body.copyWith(
                color: _prazo == null
                    ? AppColors.mu
                    : AppColors.tx,
              ),
            ),
          ),
          if (_prazo != null)
            GestureDetector(
              onTap: () => setState(() => _prazo = null),
              child: const Icon(Icons.close_rounded,
                  size: 16, color: AppColors.mu),
            ),
        ]),
      ),
    );
  }

  Widget _corPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: coresMeta.map((c) {
        final hex = c['hex']!;
        final color =
            Color(int.parse(hex.replaceFirst('#', '0xFF')));
        final sel = hex == _cor;
        return GestureDetector(
          onTap: () => setState(() => _cor = hex),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: sel ? Colors.white : Colors.transparent,
                width: sel ? 2.5 : 0,
              ),
              boxShadow: sel
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          ),
        );
      }).toList(),
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
          _salvando ? 'Salvando...' : 'Criar Meta',
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
    if (nome.isEmpty || valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Preencha o nome e o valor objetivo'),
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
      final payload = <String, dynamic>{
        'familia_id': familiaId,
        'nome': nome,
        'emoji': _emoji,
        'valor_meta': valor,
        'cor': _cor,
      };

      if (_prazo != null) {
        payload['prazo'] =
            '${_prazo!.year}-${_prazo!.month.toString().padLeft(2, '0')}-${_prazo!.day.toString().padLeft(2, '0')}';
      }

      await FinanceiroExtService.criarMeta(payload);
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
