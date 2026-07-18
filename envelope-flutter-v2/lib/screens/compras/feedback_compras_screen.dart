import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../providers/compras_provider.dart';
import '../../services/api_service.dart';

/// Tela de feedback de consumo — empurrada via Navigator.push de dentro do modal.
/// Mostra compras aguardando feedback do usuário em formato "swipe card".
class FeedbackComprasScreen extends ConsumerStatefulWidget {
  const FeedbackComprasScreen({super.key});

  @override
  ConsumerState<FeedbackComprasScreen> createState() =>
      _FeedbackComprasScreenState();
}

class _FeedbackComprasScreenState
    extends ConsumerState<FeedbackComprasScreen> {
  int _currentIndex = 0;
  double _dragX = 0;
  bool _enviando = false;

  @override
  Widget build(BuildContext context) {
    final feedbackAsync = ref.watch(feedbackPendenteProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.tx),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Feedback de Consumo',
          style: AppTextStyles.title,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: AppColors.bord),
        ),
      ),
      body: feedbackAsync.when(
        data: (itens) {
          if (itens.isEmpty || _currentIndex >= itens.length) {
            return _doneState();
          }
          final item = itens[_currentIndex];
          final total = itens.length;
          final restante = total - _currentIndex;

          return Column(
            children: [
              // Progresso
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePad),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$restante ${restante == 1 ? 'item aguarda' : 'itens aguardam'} feedback',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.mu),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.acc.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / $total',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.acc, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Barra de progresso
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePad),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _currentIndex / total,
                    backgroundColor: AppColors.bord,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.acc),
                    minHeight: 3,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card com swipe
              Expanded(
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) {
                    if (!_enviando) setState(() => _dragX += d.delta.dx);
                  },
                  onHorizontalDragEnd: (_) {
                    if (_enviando) return;
                    if (_dragX > 80) {
                      _registrarFeedback(item, 'acabou');
                    } else if (_dragX < -80) {
                      _registrarFeedback(item, 'estragou');
                    }
                    setState(() => _dragX = 0);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
                    transform: Matrix4.translationValues(_dragX, 0, 0)
                      ..rotateZ(_dragX * 0.003),
                    margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.pagePad),
                    child: _ItemCard(item: item, offsetX: _dragX),
                  ),
                ),
              ),

              // Botões de ação
              Padding(
                padding: EdgeInsets.fromLTRB(
                  40,
                  16,
                  40,
                  MediaQuery.of(context).padding.bottom + 24,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ActionButton(
                      icon: Icons.close_rounded,
                      color: AppColors.red,
                      label: 'Estragou',
                      enabled: !_enviando,
                      onTap: () => _registrarFeedback(item, 'estragou'),
                    ),
                    // Pular
                    GestureDetector(
                      onTap: _enviando
                          ? null
                          : () => setState(() {
                                if (_currentIndex < itens.length - 1) {
                                  _currentIndex++;
                                }
                              }),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.bord),
                            ),
                            child: const Icon(Icons.skip_next_rounded,
                                color: AppColors.mu, size: 22),
                          ),
                          const SizedBox(height: 4),
                          Text('Pular',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.mu)),
                        ],
                      ),
                    ),
                    _ActionButton(
                      icon: Icons.check_rounded,
                      color: AppColors.acc,
                      label: 'Acabou',
                      enabled: !_enviando,
                      onTap: () => _registrarFeedback(item, 'acabou'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.acc),
        ),
        error: (e, _) => Center(
          child: Text('Erro: $e',
              style: AppTextStyles.body.copyWith(color: AppColors.red)),
        ),
      ),
    );
  }

  Widget _doneState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.acc.withOpacity(0.12),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                size: 48, color: AppColors.acc),
          ),
          const SizedBox(height: 20),
          Text('Tudo em dia!', style: AppTextStyles.title),
          const SizedBox(height: 8),
          Text(
            'Nenhum feedback pendente',
            style: AppTextStyles.body.copyWith(color: AppColors.mu),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.bord),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusBtn)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
            ),
            child: Text('Voltar',
                style: AppTextStyles.body.copyWith(color: AppColors.mu)),
          ),
        ],
      ),
    );
  }

  Future<void> _registrarFeedback(
      Map<String, dynamic> item, String status) async {
    if (_enviando) return;
    setState(() => _enviando = true);
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/v1/compras/feedback');
      final resp = await http.patch(
        uri,
        headers: ApiService.authHeaders(json: true),
        body: jsonEncode({
          'compra_id': item['compra_id'],
          'nome_padronizado': item['nome_padronizado'],
          'status': status,
        }),
      );
      if (resp.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _currentIndex++;
          _enviando = false;
        });
        ref.invalidate(feedbackPendenteProvider);
      } else {
        throw Exception(resp.body);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enviando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro: $e'),
              backgroundColor: AppColors.red),
        );
      }
    }
  }
}

// ─── Card de item ─────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final double offsetX;
  const _ItemCard({required this.item, required this.offsetX});

  @override
  Widget build(BuildContext context) {
    final swipeGreen = offsetX > 40 ? (AppColors.acc.withOpacity(0.18)) : Colors.transparent;
    final swipeRed = offsetX < -40 ? (AppColors.red.withOpacity(0.18)) : Colors.transparent;
    final swipeColor = offsetX > 40 ? swipeGreen : swipeRed;

    final labelSwipe = offsetX > 40
        ? 'ACABOU'
        : offsetX < -40
            ? 'ESTRAGOU'
            : null;
    final labelColor =
        offsetX > 40 ? AppColors.acc : AppColors.red;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.bord),
        boxShadow: const [
          BoxShadow(
              color: Colors.black38, blurRadius: 16, offset: Offset(0, 6))
        ],
      ),
      child: Stack(
        children: [
          // Tint de swipe
          if (swipeColor != Colors.transparent)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: swipeColor,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusCard),
                ),
              ),
            ),

          // Label de swipe
          if (labelSwipe != null)
            Positioned(
              top: 24,
              left: offsetX > 40 ? null : 24,
              right: offsetX > 40 ? 24 : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: labelColor, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  labelSwipe,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),

          // Conteúdo principal
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Categoria chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.acc.withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusChip),
                  ),
                  child: Text(
                    item['categoria'] ?? 'Outros',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.acc),
                  ),
                ),
                const SizedBox(height: 24),

                // Nome do item
                Text(
                  item['nome_padronizado'] ?? '',
                  style: AppTextStyles.display,
                ),
                const SizedBox(height: 16),

                // Datas
                _InfoRow(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Comprado em',
                  value: _formatDate(item['data_compra'] as String? ?? ''),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.event_available_outlined,
                  label: 'Prazo estimado',
                  value: _formatDate(
                      item['data_feedback_estimada'] as String? ?? ''),
                  valueColor: AppColors.org,
                ),

                const Spacer(),

                // Dica de swipe
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 12, color: AppColors.red),
                        const SizedBox(width: 4),
                        Text('Estragou',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.red)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Acabou',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.acc)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 12, color: AppColors.acc),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    if (raw.length < 10) return raw;
    final parts = raw.substring(0, 10).split('-');
    if (parts.length < 3) return raw;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.mu),
        const SizedBox(width: 6),
        Text('$label: ',
            style: AppTextStyles.caption),
        Text(value,
            style: AppTextStyles.bodySm
                .copyWith(color: valueColor ?? AppColors.tx)),
      ],
    );
  }
}

// ─── Botão de ação ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon,
      required this.color,
      required this.label,
      required this.enabled,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
                color: color.withOpacity(0.08),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
