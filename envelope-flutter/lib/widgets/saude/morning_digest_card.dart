import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';

class MorningDigestCard extends StatefulWidget {
  final Map<String, dynamic>? digestData;

  const MorningDigestCard({super.key, required this.digestData});

  @override
  State<MorningDigestCard> createState() => _MorningDigestCardState();
}

class _MorningDigestCardState extends State<MorningDigestCard> {
  bool _dismissed = true; // start hidden until check completes
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _checkDismissed();
  }

  Future<void> _checkDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('digest_dismissed_${_today()}') ?? false;
    if (mounted) setState(() { _dismissed = dismissed; _loaded = true; });
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('digest_dismissed_${_today()}', true);
    setState(() => _dismissed = true);
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _dismissed || widget.digestData == null) return const SizedBox.shrink();

    final d = widget.digestData!;
    final mensagem = d['mensagem_principal'] as String?
        ?? d['resumo'] as String?
        ?? d['texto'] as String?
        ?? d['analise'] as String?
        ?? d['summary'] as String?;

    if (mensagem == null || mensagem.trim().isEmpty) return const SizedBox.shrink();

    final hour = DateTime.now().hour;
    final saudacao = hour < 12 ? 'Bom dia' : hour < 18 ? 'Boa tarde' : 'Boa noite';
    final emoji = hour < 12 ? '🌅' : hour < 18 ? '☀️' : '🌙';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.grn.withOpacity(0.1), AppColors.acc.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grn.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saudacao,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.grn,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  mensagem,
                  style: const TextStyle(fontSize: 13, color: AppColors.tx, height: 1.5),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _dismiss,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 0, 0),
              child: Icon(Icons.close, size: 14, color: AppColors.mu),
            ),
          ),
        ],
      ),
    );
  }
}
