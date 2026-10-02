import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/api_service.dart';
import '../../utils/moeda.dart';
import 'abastecer_sheet.dart';
import 'widgets/form_receita_widgets.dart';

class FormReceitaSheet extends ConsumerStatefulWidget {
  const FormReceitaSheet({super.key});

  @override
  ConsumerState<FormReceitaSheet> createState() => _FormReceitaSheetState();
}

class _FormReceitaSheetState extends ConsumerState<FormReceitaSheet> {
  final _valorController = TextEditingController();
  final _obsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _origemSelecionada = 'Salário';
  bool _carregando = false;

  @override
  void dispose() {
    _valorController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      final perfil = ref.read(perfilUsuarioLogadoProvider).value;
      if (perfil == null) throw Exception('Usuário não autenticado');

      final valor = parseMoeda(_valorController.text);
      final obs = _obsController.text.trim();

      await ApiService.post('/transacoes/receita', {
        'valor': valor,
        'usuario_id': perfil['id'],
        'familia_id': perfil['familia_id'],
        'descricao': obs.isEmpty ? _origemSelecionada : '$_origemSelecionada - $obs',
      });

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Receita de R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')} registrada no Saldo Geral!'),
            ],
          ),
          backgroundColor: AppColors.grn,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      await perguntarDistribuirReceita(context, const AbastecerSheet());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e', style: AppTextStyles.bodySm),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom + 20;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.pagePad, 0, AppSpacing.pagePad, bottom),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 20),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.mu.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Text('Registrar receita 💰', style: AppTextStyles.title),
                const SizedBox(height: 4),
                Text('vai direto para o Saldo Geral ⚡', style: AppTextStyles.caption),
                const SizedBox(height: 24),
                ReceitaValorInput(controller: _valorController),
                const SizedBox(height: 20),
                Text('Origem', style: AppTextStyles.bodySm.copyWith(color: AppColors.mu)),
                const SizedBox(height: 8),
                ReceitaOrigemChips(
                  origemSelecionada: _origemSelecionada,
                  onSelect: (origem) => setState(() => _origemSelecionada = origem),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _obsController,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: 'Observação (opcional)',
                    hintStyle: AppTextStyles.body.copyWith(color: AppColors.mu),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _carregando ? null : _confirmar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.grn,
                      foregroundColor: AppColors.tx,
                      disabledBackgroundColor: AppColors.grn.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                      ),
                      elevation: 0,
                    ),
                    child: _carregando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.tx),
                          )
                        : Text('Confirmar receita', style: AppTextStyles.titleSm.copyWith(color: AppColors.tx)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
