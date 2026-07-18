import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/api_service.dart';
import 'abastecer_sheet.dart';

const _origens = [
  ('Salário', Icons.work_outline),
  ('Freelance', Icons.laptop_outlined),
  ('Investimento', Icons.trending_up_outlined),
  ('Presente', Icons.card_giftcard_outlined),
  ('Outros', Icons.more_horiz),
];

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

      final rawValor = _valorController.text
          .replaceAll('.', '')
          .replaceAll(',', '.');
      final valor = double.parse(rawValor);
      final obs = _obsController.text.trim();

      await ApiService.post('/transacoes/receita', {
        'valor': valor,
        'usuario_id': perfil['id'],
        'familia_id': perfil['familia_id'],
        'descricao': obs.isEmpty
            ? _origemSelecionada
            : '$_origemSelecionada - $obs',
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
      await _perguntarDistribuir();
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

  Future<void> _perguntarDistribuir() async {
    final ctx = context;
    final resposta = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: const BorderSide(color: AppColors.bord, width: 0.5),
        ),
        title: Text('Distribuir nos envelopes?', style: AppTextStyles.titleSm),
        content: Text(
          'Deseja distribuir essa receita nos seus envelopes agora?',
          style: AppTextStyles.body.copyWith(color: AppColors.mu),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text('Depois', style: AppTextStyles.body.copyWith(color: AppColors.mu)),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text('Sim, agora', style: AppTextStyles.body.copyWith(color: AppColors.acc)),
          ),
        ],
      ),
    );

    if (resposta == true && mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AbastecerSheet(),
      );
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
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pagePad,
            0,
            AppSpacing.pagePad,
            bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
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

                // Cabeçalho
                Text('Registrar receita 💰', style: AppTextStyles.title),
                const SizedBox(height: 4),
                Text(
                  'vai direto para o Saldo Geral ⚡',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 24),

                // Campo Valor
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surf,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    border: Border.all(
                      color: AppColors.grn.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'R\$',
                        style: AppTextStyles.titleSm.copyWith(
                          color: AppColors.grn.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _valorController,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[\d,.]'),
                            ),
                          ],
                          textAlign: TextAlign.center,
                          style: AppTextStyles.mono.copyWith(
                            fontSize: 44,
                            color: AppColors.grn,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            filled: false,
                            border: InputBorder.none,
                            hintText: '0,00',
                            hintStyle: AppTextStyles.mono.copyWith(
                              fontSize: 44,
                              color: AppColors.grn.withOpacity(0.3),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Informe o valor';
                            final raw = v.replaceAll('.', '').replaceAll(',', '.');
                            final n = double.tryParse(raw);
                            if (n == null || n <= 0) return 'Valor inválido';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Origem
                Text(
                  'Origem',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _origens.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final (label, icon) = _origens[i];
                      final sel = _origemSelecionada == label;
                      return GestureDetector(
                        onTap: () => setState(() => _origemSelecionada = label),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 0,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.grn.withOpacity(0.15)
                                : AppColors.surf,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusChip,
                            ),
                            border: Border.all(
                              color: sel ? AppColors.grn : AppColors.bord,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 15,
                                color: sel ? AppColors.grn : AppColors.mu,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: AppTextStyles.bodySm.copyWith(
                                  color: sel ? AppColors.grn : AppColors.tx,
                                  fontWeight: sel
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Observação
                TextFormField(
                  controller: _obsController,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: 'Observação (opcional)',
                    hintStyle: AppTextStyles.body.copyWith(color: AppColors.mu),
                  ),
                ),
                const SizedBox(height: 24),

                // Botão confirmar
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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.tx,
                            ),
                          )
                        : Text(
                            'Confirmar receita',
                            style: AppTextStyles.titleSm.copyWith(
                              color: AppColors.tx,
                            ),
                          ),
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
