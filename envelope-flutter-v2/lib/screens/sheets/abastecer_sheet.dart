import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/envelopes_provider.dart';
import '../../providers/fixos_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/api_service.dart';

const double _kToleranciaCentavo = 0.005;

class AbastecerSheet extends ConsumerStatefulWidget {
  const AbastecerSheet({super.key});

  @override
  ConsumerState<AbastecerSheet> createState() => _AbastecerSheetState();
}

class _AbastecerSheetState extends ConsumerState<AbastecerSheet> {
  final Map<String, TextEditingController> _controllers = {};
  bool _carregando = false;

  static final _fmt = NumberFormat('R\$ #,##0.00', 'pt_BR');

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlFor(String id) {
    return _controllers.putIfAbsent(id, () => TextEditingController());
  }

  double _parseCampo(String text) {
    if (text.trim().isEmpty) return 0;
    final raw = text.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(raw) ?? 0;
  }

  double _totalDigitado(List<Map<String, dynamic>> envelopes) {
    double total = 0;
    for (final env in envelopes) {
      final id = env['id'] as String;
      final ctrl = _controllers[id];
      if (ctrl != null) total += _parseCampo(ctrl.text);
    }
    return total;
  }

  Future<void> _confirmar(
    List<Map<String, dynamic>> envelopes,
    double saldoLivre,
    Map<String, dynamic> perfil,
  ) async {
    final total = _totalDigitado(envelopes);
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Informe ao menos um valor', style: AppTextStyles.bodySm),
          backgroundColor: AppColors.org,
        ),
      );
      return;
    }

    setState(() => _carregando = true);
    try {
      for (final env in envelopes) {
        final id = env['id'] as String;
        final ctrl = _controllers[id];
        if (ctrl == null) continue;
        final valor = _parseCampo(ctrl.text);
        if (valor <= 0) continue;

        await ApiService.post('/abastecer/', {
          'valor': valor,
          'envelope_id': id,
          'usuario_id': perfil['id'],
          'familia_id': perfil['familia_id'],
        });
      }

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
    final reservado = ref.watch(totalReservadoProvider);
    final perfilAsync = ref.watch(perfilUsuarioLogadoProvider);

    final envelopes = envelopesAsync.value ?? [];
    final saldoLivre = ref.watch(saldoLivreProvider);
    final saldoGeral = ref.watch(saldoGeralProvider).value ?? 0.0;
    final perfil = perfilAsync.value;

    final bottom = MediaQuery.of(context).viewInsets.bottom + 20;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
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

            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.pagePad,
                  16,
                  AppSpacing.pagePad,
                  bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text('Distribuir saldo ⚡', style: AppTextStyles.title),
                    const SizedBox(height: 16),

                    // Card de saldo
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surf,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusCard),
                        border: const Border.fromBorderSide(
                          BorderSide(color: AppColors.bord, width: 0.5),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _SaldoRow(
                            label: 'Saldo geral',
                            valor: saldoGeral,
                            cor: AppColors.acc,
                          ),
                          const SizedBox(height: 8),
                          _SaldoRow(
                            label: 'Reservado (fixos)',
                            valor: reservado,
                            cor: AppColors.org,
                            prefixo: '− ',
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1),
                          ),
                          _SaldoRow(
                            label: 'Livre para envelopes',
                            valor: saldoLivre,
                            cor: saldoLivre >= 0 ? AppColors.grn : AppColors.red,
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dica de uso
                    Row(
                      children: [
                        const Icon(Icons.touch_app_rounded,
                            size: 15, color: AppColors.mu),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Toque no campo de cada envelope e digite quanto colocar.',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.mu),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Lista de envelopes
                    if (envelopes.isEmpty)
                      Center(
                        child: Text(
                          'Nenhum envelope encontrado',
                          style: AppTextStyles.caption,
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: envelopes.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.cardGap),
                        itemBuilder: (context, index) {
                          final env = envelopes[index];
                          final id = env['id'] as String;
                          final emoji = env['emoji'] as String? ?? '📦';
                          final nome = env['nome_envelope'] as String? ?? '—';
                          final saldoAtual =
                              (env['saldo_atual'] as num?)?.toDouble() ?? 0;
                          final ctrl = _ctrlFor(id);

                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.surf,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusCard,
                              ),
                              border: const Border.fromBorderSide(
                                BorderSide(color: AppColors.bord, width: 0.5),
                              ),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Emoji + info
                                Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(nome, style: AppTextStyles.bodySm),
                                      Text(
                                        _fmt.format(saldoAtual),
                                        style: AppTextStyles.monoSm.copyWith(
                                          color: AppColors.mu,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Campo valor
                                // Campo de valor — visível como caixa clicável
                                Container(
                                  width: 120,
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: ctrl.text.isNotEmpty
                                          ? AppColors.acc.withOpacity(0.6)
                                          : AppColors.bord,
                                      width: 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 2),
                                  child: TextField(
                                    controller: ctrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[\d,.]'),
                                      ),
                                    ],
                                    textAlign: TextAlign.right,
                                    style: AppTextStyles.mono.copyWith(
                                      fontSize: 16,
                                      color: AppColors.acc,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      hintText: '0,00',
                                      hintStyle: AppTextStyles.mono.copyWith(
                                        fontSize: 16,
                                        color: AppColors.mu,
                                      ),
                                      prefixText: '+ R\$ ',
                                      prefixStyle: AppTextStyles.bodySm
                                          .copyWith(color: AppColors.acc),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 20),

                    // Summary rodapé
                    StatefulBuilder(
                      builder: (context, setSummary) {
                        final total = _totalDigitado(envelopes);
                        final excede = total > saldoLivre + _kToleranciaCentavo;
                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: excede
                                    ? AppColors.red.withOpacity(0.08)
                                    : AppColors.acc.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusCard,
                                ),
                                border: Border.all(
                                  color: excede
                                      ? AppColors.red.withOpacity(0.3)
                                      : AppColors.acc.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    excede
                                        ? Icons.warning_amber_rounded
                                        : Icons.check_circle_outline,
                                    color: excede
                                        ? AppColors.red
                                        : AppColors.acc,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      excede
                                          ? 'Excede o saldo livre em ${_fmt.format(total - saldoLivre)}'
                                          : 'Total a distribuir: ${_fmt.format(total)}',
                                      style: AppTextStyles.bodySm.copyWith(
                                        color: excede
                                            ? AppColors.red
                                            : AppColors.acc,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed:
                                    (_carregando || excede || perfil == null)
                                        ? null
                                        : () => _confirmar(
                                              envelopes,
                                              saldoLivre,
                                              perfil,
                                            ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.acc,
                                  foregroundColor: AppColors.bg,
                                  disabledBackgroundColor:
                                      AppColors.acc.withOpacity(0.3),
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
                                        'Confirmar abastecimento',
                                        style: AppTextStyles.titleSm.copyWith(
                                          color: AppColors.bg,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaldoRow extends StatelessWidget {
  final String label;
  final double valor;
  final Color cor;
  final String prefixo;
  final bool bold;

  static final _fmt = NumberFormat('R\$ #,##0.00', 'pt_BR');

  const _SaldoRow({
    required this.label,
    required this.valor,
    required this.cor,
    this.prefixo = '',
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: bold
              ? AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600)
              : AppTextStyles.bodySm.copyWith(color: AppColors.mu),
        ),
        Text(
          '$prefixo${_fmt.format(valor)}',
          style: AppTextStyles.mono.copyWith(
            color: cor,
            fontSize: bold ? 17 : 15,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
