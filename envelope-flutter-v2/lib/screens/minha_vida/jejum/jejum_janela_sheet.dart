import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/jejum_provider.dart';
import '../../../services/jejum_api_service.dart';
import '../../../widgets/unicorn/unicorn_system.dart';

/// Sheet "Configurar horário da janela alimentar" — aparece após escolha do protocolo.
class JejumJanelaSheet extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;
  final String protocolo;

  const JejumJanelaSheet({
    super.key,
    required this.membroId,
    required this.familiaId,
    required this.protocolo,
  });

  @override
  ConsumerState<JejumJanelaSheet> createState() => _JejumJanelaSheetState();
}

class _JejumJanelaSheetState extends ConsumerState<JejumJanelaSheet> {
  TimeOfDay _horaInicio = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _horaFim    = const TimeOfDay(hour: 20, minute: 0);
  bool _jokerDay         = true;
  bool _fastTogether     = false;
  bool _salvando         = false;

  String get _protocoloLabel {
    final p = ProtocoloJejum.todos.firstWhere(
      (x) => x.id == widget.protocolo,
      orElse: () => ProtocoloJejum.todos.first,
    );
    return p.label;
  }

  int get _horasJanela {
    final inicioMin = _horaInicio.hour * 60 + _horaInicio.minute;
    final fimMin    = _horaFim.hour   * 60 + _horaFim.minute;
    final diff = fimMin >= inicioMin
        ? fimMin - inicioMin
        : (1440 - inicioMin) + fimMin;
    return (diff / 60).round().clamp(1, 23);
  }

  int get _horasJejum => 24 - _horasJanela;

  bool _sugestaoAplicada = false;

  TimeOfDay? _parseHora(String? s) {
    if (s == null || !s.contains(':')) return null;
    final p = s.split(':');
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  // Card "Happy sugere: 12h às 20h" com dados reais da IA.
  Widget _cardSugestaoJanela() {
    final sugAsync = ref.watch(jejumSugestaoJanelaProvider(
        (membroId: widget.membroId, protocolo: widget.protocolo)));

    return sugAsync.when(
      loading: () => _wrapSugestao(
        'Analisando sua rotina para sugerir o melhor horário…', null, null),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) {
        final ini = s['janela_inicio'] as String?;
        final fim = s['janela_fim'] as String?;
        final just = s['justificativa'] as String? ??
            'Alta chance de aderência nesse período.';
        // Aplica a sugestão uma única vez ao carregar
        if (!_sugestaoAplicada) {
          final ti = _parseHora(ini);
          final tf = _parseHora(fim);
          if (ti != null && tf != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_sugestaoAplicada) {
                setState(() {
                  _horaInicio = ti;
                  _horaFim = tf;
                  _sugestaoAplicada = true;
                });
              }
            });
          } else {
            _sugestaoAplicada = true;
          }
        }
        final titulo = (ini != null && fim != null)
            ? 'Happy sugere: ${ini}h às ${fim}h'
            : 'Happy tem uma sugestão pra você';
        return _wrapSugestao(just, titulo, ini);
      },
    );
  }

  Widget _wrapSugestao(String texto, String? titulo, String? _) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.acc.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.acc.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const UnicornWidget(type: UnicornType.happy, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo ?? 'Sugestão',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.acc,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(texto, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final togetherAsync = ref.watch(jejumTogetherProvider(
        (membroId: widget.membroId, familiaId: widget.familiaId)));
    final parceiroNome =
        togetherAsync.asData?.value?['parceiro_nome'] as String? ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePad,
        12,
        AppSpacing.pagePad,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.bord,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Text(
              '$_protocoloLabel selecionado',
              style: AppTextStyles.caption.copyWith(color: AppColors.mu),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Quando você quer comer?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.tx,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Card sugestão IA (Happy sugere horário)
            _cardSugestaoJanela(),
            const SizedBox(height: 20),

            // Label seção
            const Text(
              'JANELA ALIMENTAR',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.mu,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            // Boxes início / fim
            Row(
              children: [
                Expanded(child: _buildTimeBox(isInicio: true)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '→',
                    style: AppTextStyles.title.copyWith(color: AppColors.mu),
                  ),
                ),
                Expanded(child: _buildTimeBox(isInicio: false)),
              ],
            ),
            const SizedBox(height: 20),

            // Timeline 24h
            _buildTimeline(),
            const SizedBox(height: 10),

            // Legenda
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '🌙 ${_horasJejum}h de jejum',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(width: 20),
                Text(
                  '🍽️ ${_horasJanela}h janela',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Toggle Joker Day
            _buildToggleRow(
              emoji: '🃏',
              titulo: 'Joker Day',
              subtitulo: '1x/semana sem quebrar streak',
              valor: _jokerDay,
              onChanged: (v) => setState(() => _jokerDay = v),
            ),
            const SizedBox(height: 10),

            // Toggle Fast Together
            _buildToggleRow(
              emoji: '👭',
              titulo: 'Fast Together',
              subtitulo: parceiroNome.isNotEmpty
                  ? 'Jejuando com $parceiroNome'
                  : 'Jejuar com um parceiro',
              valor: _fastTogether,
              onChanged: (v) => setState(() => _fastTogether = v),
            ),
            const SizedBox(height: 24),

            // Botão principal
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.acc,
                  foregroundColor: AppColors.bg,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                  ),
                ),
                child: _salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.bg,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Ativar jejum $_protocoloLabel',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBox({required bool isInicio}) {
    final hora  = isInicio ? _horaInicio : _horaFim;
    final ativo = isInicio;
    return GestureDetector(
      onTap: () => _selecionarHora(isInicio),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
          border: Border.all(
            color: ativo ? AppColors.acc.withOpacity(0.6) : AppColors.bord,
            width: ativo ? 1.2 : 0.8,
          ),
        ),
        child: Column(
          children: [
            Text(
              isInicio ? 'INÍCIO' : 'FIM',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mu,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: ativo ? AppColors.acc : AppColors.tx,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    final inicioMin = _horaInicio.hour * 60 + _horaInicio.minute;
    final fimMin    = _horaFim.hour   * 60 + _horaFim.minute;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final inicioFrac = inicioMin / 1440.0;
        final fimFrac    = fimMin    / 1440.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 14,
                child: Stack(
                  children: [
                    // Base (jejum)
                    Container(color: AppColors.surf),
                    // Janela alimentar
                    if (fimFrac > inicioFrac)
                      Positioned(
                        left: w * inicioFrac,
                        width: w * (fimFrac - inicioFrac),
                        top: 0,
                        bottom: 0,
                        child: Container(color: AppColors.acc.withOpacity(0.7)),
                      )
                    else ...[
                      Positioned(
                        left: w * inicioFrac,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(color: AppColors.acc.withOpacity(0.7)),
                      ),
                      Positioned(
                        left: 0,
                        width: w * fimFrac,
                        top: 0,
                        bottom: 0,
                        child: Container(color: AppColors.acc.withOpacity(0.7)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('00h', style: TextStyle(fontSize: 9, color: AppColors.mu)),
                Text('06h', style: TextStyle(fontSize: 9, color: AppColors.mu)),
                Text('12h', style: TextStyle(fontSize: 9, color: AppColors.mu)),
                Text('18h', style: TextStyle(fontSize: 9, color: AppColors.mu)),
                Text('24h', style: TextStyle(fontSize: 9, color: AppColors.mu)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildToggleRow({
    required String emoji,
    required String titulo,
    required String subtitulo,
    required bool valor,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
        border: Border.all(color: AppColors.bord, width: 0.8),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: AppTextStyles.bodySm
                      .copyWith(fontWeight: FontWeight.w600, color: AppColors.tx),
                ),
                Text(subtitulo, style: AppTextStyles.caption),
              ],
            ),
          ),
          Switch(
            value: valor,
            onChanged: onChanged,
            activeColor: AppColors.acc,
            activeTrackColor: AppColors.acc.withOpacity(0.3),
            inactiveThumbColor: AppColors.mu,
            inactiveTrackColor: AppColors.bord,
          ),
        ],
      ),
    );
  }

  Future<void> _selecionarHora(bool isInicio) async {
    HapticFeedback.selectionClick();
    final atual = isInicio ? _horaInicio : _horaFim;
    final selecionado = await showTimePicker(
      context: context,
      initialTime: atual,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.acc,
            surface: AppColors.card,
          ),
        ),
        child: child!,
      ),
    );
    if (selecionado == null) return;
    setState(() {
      if (isInicio) {
        _horaInicio = selecionado;
      } else {
        _horaFim = selecionado;
      }
    });
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      final inicioStr =
          '${_horaInicio.hour.toString().padLeft(2, '0')}:${_horaInicio.minute.toString().padLeft(2, '0')}';
      final fimStr =
          '${_horaFim.hour.toString().padLeft(2, '0')}:${_horaFim.minute.toString().padLeft(2, '0')}';

      await JejumApiService.salvarConfig(widget.membroId, {
        'familia_id': widget.familiaId,
        'protocolo': widget.protocolo,
        'hora_inicio_janela': inicioStr,
        'hora_fim_janela': fimStr,
        'joker_day_ativo': _jokerDay,
        'fast_together_ativo': _fastTogether,
      });

      ref.invalidate(jejumConfigProvider(
          (membroId: widget.membroId, familiaId: widget.familiaId)));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }
}
