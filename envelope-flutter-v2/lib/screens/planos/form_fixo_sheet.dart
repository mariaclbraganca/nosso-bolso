import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/usuarios_provider.dart';
import '../../providers/mes_provider.dart';
import '../../constants.dart';

/// Bottom sheet para adicionar ou editar gasto fixo.
/// Persiste diretamente no Supabase (tabela gastos_fixos).
class FormFixoSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? fixo;
  const FormFixoSheet({super.key, this.fixo});

  @override
  ConsumerState<FormFixoSheet> createState() =>
      _FormFixoSheetState();
}

class _FormFixoSheetState extends ConsumerState<FormFixoSheet> {
  final _nomeCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  int? _diaVencimento;
  bool _recorrente = false;
  bool _salvando = false;

  bool get _isEditing => widget.fixo != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nomeCtrl.text = widget.fixo!['nome'] as String? ?? '';
      _valorCtrl.text = (widget.fixo!['valor'] as num?)?.toString() ?? '';
      _recorrente = widget.fixo!['recorrente'] as bool? ?? false;
      _diaVencimento = widget.fixo!['dia_vencimento'] as int?;
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nomeCtrl.text.trim();
    final valor =
        double.tryParse(_valorCtrl.text.replaceAll(',', '.')) ?? 0.0;

    if (nome.isEmpty || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha nome e valor'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    final perfil =
        ref.read(perfilUsuarioLogadoProvider).value;
    if (perfil == null || perfil['familia_id'] == null) return;

    setState(() => _salvando = true);
    try {
      if (_isEditing) {
        await supabase.from('gastos_fixos').update({
          'nome': nome,
          'valor': valor,
          'recorrente': _recorrente,
          'dia_vencimento': _diaVencimento,
        }).eq('id', widget.fixo!['id'] as String);
      } else {
        final mes = ref.read(mesAtualProvider);
        await supabase.from('gastos_fixos').insert({
          'nome': nome,
          'valor': valor,
          'mes': mes,
          'familia_id': perfil['familia_id'],
          'recorrente': _recorrente,
          'pago': false,
          'dia_vencimento': _diaVencimento,
        });

        if (_recorrente) {
          String mesAtual = mes;
          for (int i = 0; i < 11; i++) {
            mesAtual = mesProximo(mesAtual);
            await supabase.from('gastos_fixos').insert({
              'nome': nome,
              'valor': valor,
              'mes': mesAtual,
              'familia_id': perfil['familia_id'],
              'recorrente': true,
              'pago': false,
              'dia_vencimento': _diaVencimento,
            });
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            _isEditing
                ? 'Alterações salvas'
                : '🔒 $nome adicionado${_recorrente ? ' para todos os meses futuros' : ''}',
          ),
          backgroundColor: AppColors.acc,
          behavior: SnackBarBehavior.floating,
        ));
      }
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

  Future<void> _selecionarDia() async {
    final dias = List.generate(28, (i) => i + 1);
    final selecionado = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Dia de vencimento', style: AppTextStyles.titleSm),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: dias.length,
              itemBuilder: (_, i) {
                final dia = dias[i];
                final sel = dia == _diaVencimento;
                return GestureDetector(
                  onTap: () => Navigator.pop(context, dia),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? AppColors.acc : AppColors.surf,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$dia',
                      style: AppTextStyles.bodySm.copyWith(
                        color: sel ? AppColors.bg : AppColors.tx,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
    if (selecionado != null) setState(() => _diaVencimento = selecionado);
  }

  Future<void> _deletar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppSpacing.radiusCard),
        ),
        title: Text('Excluir fixo?',
            style: AppTextStyles.titleSm),
        content: Text(
          'Esta ação não pode ser desfeita.',
          style: AppTextStyles.bodySm
              .copyWith(color: AppColors.mu),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: TextStyle(color: AppColors.mu)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Excluir',
                style: TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _salvando = true);
    try {
      await supabase
          .from('gastos_fixos')
          .delete()
          .eq('id', widget.fixo!['id'] as String);
      if (mounted) Navigator.pop(context);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.bord,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Título
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing
                        ? 'Editar Gasto Fixo 🔒'
                        : 'Novo Gasto Fixo 🔒',
                    style: AppTextStyles.titleSm,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Será reservado automaticamente do saldo',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // Campo nome
          TextField(
            controller: _nomeCtrl,
            autofocus: true,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              labelText: 'NOME DO GASTO',
              hintText: 'Ex: Plano de Saúde',
              hintStyle: AppTextStyles.body
                  .copyWith(color: AppColors.mu),
              labelStyle:
                  AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
              filled: true,
              fillColor: AppColors.surf,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                    AppSpacing.radiusInput),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Campo valor
          TextField(
            controller: _valorCtrl,
            keyboardType: TextInputType.number,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              labelText: 'VALOR MENSAL (R\$)',
              hintText: '0,00',
              hintStyle: AppTextStyles.body
                  .copyWith(color: AppColors.mu),
              labelStyle:
                  AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
              filled: true,
              fillColor: AppColors.surf,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                    AppSpacing.radiusInput),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Dia de vencimento
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surf,
              borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_rounded, color: AppColors.mu, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _diaVencimento != null
                      ? 'Vence dia $_diaVencimento de cada mês'
                      : 'Dia de vencimento (opcional)',
                  style: AppTextStyles.body.copyWith(
                    color: _diaVencimento != null ? AppColors.tx : AppColors.mu,
                  ),
                ),
              ),
              if (_diaVencimento != null)
                GestureDetector(
                  onTap: () => setState(() => _diaVencimento = null),
                  child: const Icon(Icons.close_rounded, color: AppColors.mu, size: 18),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _selecionarDia,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.acc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _diaVencimento != null ? 'Alterar' : 'Definir',
                    style: AppTextStyles.caption.copyWith(color: AppColors.acc),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // Recorrente toggle
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surf,
              borderRadius: BorderRadius.circular(
                  AppSpacing.radiusInput),
            ),
            child: Row(children: [
              const Icon(Icons.repeat_rounded,
                  color: AppColors.mu, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Recorrente (todo mês)',
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

          // Aviso recorrente
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _recorrente
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.acc.withOpacity(0.08),
                borderRadius: BorderRadius.circular(
                    AppSpacing.radiusSm),
                border: Border.all(
                    color: AppColors.acc.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.acc),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Será criado para os próximos 12 meses automaticamente.',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.acc),
                  ),
                ),
              ]),
            ),
            secondChild: const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),

          // Botão salvar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _salvando ? null : _salvar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.acc,
                foregroundColor: AppColors.bg,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      AppSpacing.radiusBtn),
                ),
              ),
              child: _salvando
                  ? const CircularProgressIndicator(
                      color: AppColors.bg, strokeWidth: 2)
                  : Text(
                      _isEditing
                          ? 'Salvar alterações'
                          : 'Adicionar gasto fixo',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.bg,
                      ),
                    ),
            ),
          ),

          // Botão deletar (apenas ao editar)
          if (_isEditing) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: _salvando ? null : _deletar,
              child: Text(
                'EXCLUIR GASTO FIXO',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.red,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
