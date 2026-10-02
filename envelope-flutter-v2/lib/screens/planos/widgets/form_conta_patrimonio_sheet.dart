import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../constants.dart';
import '../../../providers/usuarios_provider.dart';
import '../../../utils/moeda.dart';
import 'form_conta_patrimonio_tipo_selector.dart';

/// Bottom sheet para adicionar ou editar uma conta de patrimônio/investimento
class FormContaPatrimonioSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? conta;
  const FormContaPatrimonioSheet({super.key, this.conta});

  @override
  ConsumerState<FormContaPatrimonioSheet> createState() => _FormContaPatrimonioSheetState();
}

class _FormContaPatrimonioSheetState extends ConsumerState<FormContaPatrimonioSheet> {
  final _nomeCtrl = TextEditingController();
  final _bancoCtrl = TextEditingController();
  final _saldoCtrl = TextEditingController();
  final _rendimentoCtrl = TextEditingController();
  final _metaCtrl = TextEditingController();

  String _tipo = 'conta_corrente';
  String _emoji = '🏦';
  bool _salvando = false;

  bool get _editando => widget.conta != null;

  @override
  void initState() {
    super.initState();
    final c = widget.conta;
    if (c != null) {
      _nomeCtrl.text = c['nome'] as String? ?? '';
      _bancoCtrl.text = c['banco'] as String? ?? '';
      final saldoVal = (c['saldo_atual'] as num?)?.toDouble() ?? 0;
      _saldoCtrl.text = saldoVal > 0 ? NumberFormat.currency(locale: 'pt_BR', symbol: '').format(saldoVal).trim() : '';
      _tipo = c['tipo'] as String? ?? 'conta_corrente';
      _emoji = c['emoji'] as String? ?? '🏦';
      final rend = c['rendimento_mensal'];
      if (rend != null) _rendimentoCtrl.text = rend.toString().replaceAll('.', ',');
      final meta = (c['meta_saldo'] as num?)?.toDouble();
      if (meta != null && meta > 0) {
        _metaCtrl.text = NumberFormat.currency(locale: 'pt_BR', symbol: '').format(meta).trim();
      }
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _bancoCtrl.dispose();
    _saldoCtrl.dispose();
    _rendimentoCtrl.dispose();
    _metaCtrl.dispose();
    super.dispose();
  }

  double _parse(String v) => parseMoeda(v);

  Future<void> _salvar() async {
    if (_nomeCtrl.text.trim().isEmpty) return;
    final perfil = ref.read(perfilUsuarioLogadoProvider).value;
    if (perfil == null) return;

    setState(() => _salvando = true);
    try {
      final rendText = _rendimentoCtrl.text.trim().replaceAll(',', '.');
      final data = {
        'nome': _nomeCtrl.text.trim(),
        'banco': _bancoCtrl.text.trim().isEmpty ? null : _bancoCtrl.text.trim(),
        'tipo': _tipo,
        'emoji': _emoji,
        'saldo_atual': _parse(_saldoCtrl.text),
        'rendimento_mensal': rendText.isEmpty ? null : double.tryParse(rendText),
        'meta_saldo': _metaCtrl.text.trim().isEmpty ? null : _parse(_metaCtrl.text),
        'familia_id': perfil['familia_id'],
      };

      if (_editando) {
        await supabase.from('contas_patrimonio').update(data).eq('id', widget.conta!['id'] as String);
      } else {
        await supabase.from('contas_patrimonio').insert(data);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red));
    }
  }

  Future<void> _deletar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
        title: Text('Excluir conta?', style: AppTextStyles.titleSm),
        content: Text('Esta ação não pode ser desfeita.', style: AppTextStyles.bodySm.copyWith(color: AppColors.mu)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: AppColors.mu))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _salvando = true);
    await supabase.from('contas_patrimonio').delete().eq('id', widget.conta!['id'] as String);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, top: 20, left: 20, right: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(_editando ? 'Editar conta' : 'Nova conta / investimento', style: AppTextStyles.titleSm),
            const SizedBox(height: 4),
            Text('Visível apenas para administradores', style: AppTextStyles.caption.copyWith(color: AppColors.org)),
            const SizedBox(height: 20),
            ContaTipoSelector(tipoSelecionado: _tipo, onSelect: (t, e) => setState(() { _tipo = t; _emoji = e; })),
            const SizedBox(height: 16),
            ContaCampoInput(ctrl: _nomeCtrl, label: 'NOME DA CONTA', hint: 'Ex: Nubank Principal'),
            const SizedBox(height: 12),
            ContaCampoInput(ctrl: _bancoCtrl, label: 'BANCO (opcional)', hint: 'Ex: Nubank, Itaú'),
            const SizedBox(height: 12),
            ContaCampoInput(ctrl: _saldoCtrl, label: 'SALDO ATUAL (R\$)', hint: '0,00', keyboard: TextInputType.number, isMoeda: true),
            const SizedBox(height: 12),
            ContaCampoInput(ctrl: _rendimentoCtrl, label: 'RENDIMENTO MENSAL % (opcional)', hint: '0,00', keyboard: TextInputType.number),
            const SizedBox(height: 12),
            ContaCampoInput(ctrl: _metaCtrl, label: 'META DE SALDO (opcional)', hint: '0,00', keyboard: TextInputType.number, isMoeda: true),
            const SizedBox(height: 24),
            _buildBotoes(),
          ],
        ),
      ),
    );
  }

  Widget _buildBotoes() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _salvando ? null : _salvar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.acc,
              foregroundColor: AppColors.bg,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
            ),
            child: _salvando
                ? const CircularProgressIndicator(color: AppColors.bg, strokeWidth: 2)
                : Text(_editando ? 'Salvar alterações' : 'Adicionar conta',
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.bg)),
          ),
        ),
        if (_editando) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _salvando ? null : _deletar,
              child: Text('EXCLUIR CONTA',
                style: AppTextStyles.caption.copyWith(color: AppColors.red, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
          ),
        ],
      ],
    );
  }
}
