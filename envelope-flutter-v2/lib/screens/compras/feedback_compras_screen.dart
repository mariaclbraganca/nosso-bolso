import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../providers/compras_provider.dart';
import '../../services/api_service.dart';
import 'widgets/feedback_card.dart';

/// Tela de feedback de consumo em formato "swipe card".
class FeedbackComprasScreen extends ConsumerStatefulWidget {
  const FeedbackComprasScreen({super.key});

  @override
  ConsumerState<FeedbackComprasScreen> createState() => _FeedbackComprasScreenState();
}

class _FeedbackComprasScreenState extends ConsumerState<FeedbackComprasScreen> {
  int _currentIndex = 0;
  double _dragX = 0;
  bool _enviando = false;

  Future<void> _registrarFeedback(Map<String, dynamic> item, String status) async {
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
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
        );
      }
    }
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
            child: const Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.acc),
          ),
          const SizedBox(height: 20),
          Text('Tudo em dia!', style: AppTextStyles.title),
          const SizedBox(height: 8),
          Text('Nenhum feedback pendente', style: AppTextStyles.body.copyWith(color: AppColors.mu)),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.bord),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            child: Text('Voltar', style: AppTextStyles.body.copyWith(color: AppColors.mu)),
          ),
        ],
      ),
    );
  }

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
        title: Text('Feedback de Consumo', style: AppTextStyles.title),
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
                        style: AppTextStyles.caption.copyWith(color: AppColors.acc, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePad),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _currentIndex / total,
                    backgroundColor: AppColors.bord,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.acc),
                    minHeight: 3,
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                    transform: Matrix4.translationValues(_dragX, 0, 0)..rotateZ(_dragX * 0.003),
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePad),
                    child: FeedbackItemCard(item: item, offsetX: _dragX),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FeedbackActionButton(
                      icon: Icons.close_rounded,
                      color: AppColors.red,
                      label: 'Estragou',
                      enabled: !_enviando,
                      onTap: () => _registrarFeedback(item, 'estragou'),
                    ),
                    FeedbackActionButton(
                      icon: Icons.more_time_rounded,
                      color: AppColors.gold,
                      label: 'Ainda tem (+7d)',
                      enabled: !_enviando,
                      onTap: () => _registrarFeedback(item, 'em_consumo'),
                    ),
                    FeedbackActionButton(
                      icon: Icons.skip_next_rounded,
                      color: AppColors.mu,
                      label: 'Pular',
                      enabled: !_enviando,
                      onTap: () => setState(() {
                        if (_currentIndex < itens.length - 1) _currentIndex++;
                      }),
                    ),
                    FeedbackActionButton(
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
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.acc)),
        error: (e, _) => Center(child: Text('Erro: $e', style: AppTextStyles.body.copyWith(color: AppColors.red))),
      ),
    );
  }
}
