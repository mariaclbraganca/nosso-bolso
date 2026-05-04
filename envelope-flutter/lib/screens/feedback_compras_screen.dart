import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../providers/compras_provider.dart';
import '../services/api_service.dart';

class FeedbackComprasScreen extends ConsumerStatefulWidget {
  const FeedbackComprasScreen({super.key});

  @override
  ConsumerState<FeedbackComprasScreen> createState() =>
      _FeedbackComprasScreenState();
}

class _FeedbackComprasScreenState extends ConsumerState<FeedbackComprasScreen> {
  int _currentIndex = 0;
  double _dragX = 0;

  @override
  Widget build(BuildContext context) {
    final feedbackAsync = ref.watch(feedbackPendenteProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Feedback de Consumo')),
      body: feedbackAsync.when(
        data: (itens) {
          if (_currentIndex >= itens.length) {
            return _doneState();
          }
          final item = itens[_currentIndex];
          return Column(children: [
            const SizedBox(height: 12),
            Text(
              '${itens.length - _currentIndex} itens aguardando feedback',
              style: const TextStyle(color: AppColors.mu, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GestureDetector(
                onHorizontalDragUpdate: (d) =>
                    setState(() => _dragX += d.delta.dx),
                onHorizontalDragEnd: (_) {
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
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ItemCard(item: item, offsetX: _dragX),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ActionButton(
                      icon: Icons.close,
                      color: AppColors.red,
                      label: 'Estragou',
                      onTap: () => _registrarFeedback(item, 'estragou'),
                    ),
                    _ActionButton(
                      icon: Icons.check,
                      color: AppColors.acc,
                      label: 'Acabou',
                      onTap: () => _registrarFeedback(item, 'acabou'),
                    ),
                  ]),
            ),
          ]);
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.acc)),
        error: (e, _) => Center(
          child: Text('Erro: $e', style: const TextStyle(color: AppColors.red)),
        ),
      ),
    );
  }

  Widget _doneState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.check_circle_outline, size: 64, color: AppColors.acc),
        const SizedBox(height: 12),
        const Text('Tudo em dia!',
            style: TextStyle(color: AppColors.tx, fontSize: 20)),
        const SizedBox(height: 6),
        const Text('Nenhum feedback pendente',
            style: TextStyle(color: AppColors.mu)),
      ]),
    );
  }

  Future<void> _registrarFeedback(
      Map<String, dynamic> item, String status) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/v1/compras/feedback');
      final resp = await http.patch(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'compra_id': item['compra_id'],
            'nome_padronizado': item['nome_padronizado'],
            'status': status,
          }));
      if (resp.statusCode == 200) {
        setState(() => _currentIndex++);
        ref.refresh(feedbackPendenteProvider);
      } else {
        throw Exception(resp.body);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }
}

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final double offsetX;
  const _ItemCard({required this.item, required this.offsetX});

  @override
  Widget build(BuildContext context) {
    final swipeColor = offsetX > 40
        ? AppColors.acc.withAlpha(76)
        : offsetX < -40
            ? AppColors.red.withAlpha(76)
            : Colors.transparent;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.bord),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
      ),
      child: Stack(children: [
        if (swipeColor != Colors.transparent)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: swipeColor,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.acc.withAlpha(38),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(item['categoria'] ?? '',
                      style: const TextStyle(
                          color: AppColors.acc, fontSize: 12)),
                ),
                const SizedBox(height: 20),
                Text(
                  item['nome_padronizado'] ?? '',
                  style: const TextStyle(
                      color: AppColors.tx,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('Compra: ${item['data_compra'] as String}',
                    style:
                        const TextStyle(color: AppColors.mu, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                    'Prazo: ${item['data_feedback_estimada'] as String}',
                    style: const TextStyle(
                        color: AppColors.org, fontSize: 13)),
                const Spacer(),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('← Estragou',
                        style: TextStyle(color: AppColors.red, fontSize: 13)),
                    Text('Acabou →',
                        style: TextStyle(color: AppColors.acc, fontSize: 13)),
                  ],
                ),
              ]),
        ),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon,
      required this.color,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ]),
    );
  }
}
