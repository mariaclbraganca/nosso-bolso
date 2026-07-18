// ─── SQL para criar tabela no Supabase (executar no SQL Editor) ───────────────
// CREATE TABLE IF NOT EXISTS remanejamentos_log (
//   id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
//   familia_id uuid REFERENCES familias(id),
//   usuario_id uuid REFERENCES usuarios(id),
//   envelope_origem_id uuid REFERENCES envelopes(id),
//   envelope_destino_id uuid REFERENCES envelopes(id),
//   valor numeric NOT NULL,
//   descricao text,
//   created_at timestamptz DEFAULT now()
// );
// ALTER TABLE remanejamentos_log ENABLE ROW LEVEL SECURITY;
// CREATE POLICY "familia_acesso" ON remanejamentos_log
//   USING (familia_id = (SELECT familia_id FROM usuarios WHERE id = auth.uid()));
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/envelopes_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/api_service.dart';
import '../../constants.dart';

class RemanejSaldoSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> origem;

  const RemanejSaldoSheet({super.key, required this.origem});

  @override
  ConsumerState<RemanejSaldoSheet> createState() => _RemanejSaldoSheetState();
}

class _RemanejSaldoSheetState extends ConsumerState<RemanejSaldoSheet> {
  final _valorController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _destinoId;
  bool _carregando = false;

  static final _fmt = NumberFormat('R\$ #,##0.00', 'pt_BR');

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _transferir() async {
    if (!_formKey.currentState!.validate()) return;
    if (_destinoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selecione o envelope destino',
            style: AppTextStyles.bodySm,
          ),
          backgroundColor: AppColors.org,
        ),
      );
      return;
    }

    setState(() => _carregando = true);
    try {
      final perfil = ref.read(perfilUsuarioLogadoProvider).value;
      if (perfil == null) throw Exception('Usuário não autenticado');

      final rawValor = _valorController.text
          .replaceAll('.', '')
          .replaceAll(',', '.');
      final valor = double.parse(rawValor);
      final origemId = widget.origem['id'] as String;

      await ApiService.post('/remanejar/', {
        'origem_id': origemId,
        'destino_id': _destinoId,
        'valor': valor,
        'familia_id': perfil['familia_id'],
        'usuario_id': perfil['id'],
      });

      // Registra remanejamento para rastreabilidade origem→destino
      await supabase.from('remanejamentos_log').insert({
        'familia_id': perfil['familia_id'],
        'usuario_id': perfil['id'],
        'envelope_origem_id': origemId,
        'envelope_destino_id': _destinoId,
        'valor': valor,
        'descricao':
            'Remanejamento de ${widget.origem['nome_envelope']} para destino',
      });

      if (mounted) Navigator.of(context).pop(true);
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
    final envelopesAsync = ref.watch(envelopesProvider);
    final envelopes = envelopesAsync.value ?? [];
    final origemId = widget.origem['id'] as String;
    final destinos = envelopes.where((e) => e['id'] != origemId).toList();
    final origemNome = widget.origem['nome_envelope'] as String? ?? '—';
    final origemEmoji = widget.origem['emoji'] as String? ?? '📦';
    final saldoOrigem =
        (widget.origem['saldo_atual'] as num?)?.toDouble() ?? 0;

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

                // Titulo
                Text('Remanejar Saldo', style: AppTextStyles.title),
                const SizedBox(height: 16),

                // Info box origem
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.08),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusCard),
                    border: Border.all(
                      color: AppColors.gold.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        origemEmoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Removendo de $origemNome',
                              style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Saldo disponível: ${_fmt.format(saldoOrigem)}',
                              style: AppTextStyles.monoSm.copyWith(
                                color: AppColors.mu,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Dropdown destino
                Text(
                  'Destino',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surf,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusInput),
                    border: const Border.fromBorderSide(
                      BorderSide(color: AppColors.bord),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _destinoId,
                      isExpanded: true,
                      dropdownColor: AppColors.surf,
                      hint: Text(
                        'Selecione o envelope destino',
                        style:
                            AppTextStyles.body.copyWith(color: AppColors.mu),
                      ),
                      style: AppTextStyles.body,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.mu,
                      ),
                      items: destinos.map((env) {
                        final id = env['id'] as String;
                        final emoji = env['emoji'] as String? ?? '📦';
                        final nome =
                            env['nome_envelope'] as String? ?? '—';
                        return DropdownMenuItem(
                          value: id,
                          child: Row(
                            children: [
                              Text(
                                emoji,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Text(nome, style: AppTextStyles.body),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _destinoId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Campo valor grande centralizado
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surf,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusCard),
                    border: Border.all(
                      color: AppColors.gold.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'R\$',
                        style: AppTextStyles.titleSm.copyWith(
                          color: AppColors.gold.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _valorController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
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
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            filled: false,
                            border: InputBorder.none,
                            hintText: '0,00',
                            hintStyle: AppTextStyles.mono.copyWith(
                              fontSize: 44,
                              color: AppColors.gold.withOpacity(0.3),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Informe o valor';
                            }
                            final raw = v
                                .replaceAll('.', '')
                                .replaceAll(',', '.');
                            final n = double.tryParse(raw);
                            if (n == null || n <= 0) return 'Valor inválido';
                            if (n > saldoOrigem) {
                              return 'Excede o saldo disponível';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Botão transferir
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _carregando ? null : _transferir,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bg,
                      disabledBackgroundColor:
                          AppColors.gold.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusBtn,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: _carregando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.bg,
                            ),
                          )
                        : Text(
                            'Transferir Agora',
                            style: AppTextStyles.titleSm.copyWith(
                              color: AppColors.bg,
                              fontWeight: FontWeight.w700,
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
