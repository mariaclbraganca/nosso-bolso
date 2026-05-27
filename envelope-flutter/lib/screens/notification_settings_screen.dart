import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _refeicoes    = true;
  bool _streak       = true;
  bool _hidratacao   = true;
  bool _financeiro   = true;
  bool _contas       = true;
  bool _loading      = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _refeicoes  = prefs.getBool('notif_refeicoes')  ?? true;
      _streak     = prefs.getBool('notif_streak')     ?? true;
      _hidratacao = prefs.getBool('notif_hidratacao') ?? true;
      _financeiro = prefs.getBool('notif_financeiro') ?? true;
      _contas     = prefs.getBool('notif_contas')     ?? true;
      _loading    = false;
    });
  }

  Future<void> _toggle(String key, bool value, VoidCallback onEnable, VoidCallback onDisable) async {
    await NotificationService.setEnabled(key, value);
    if (value) {
      onEnable();
    } else {
      onDisable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: const BackButton(color: AppColors.mu),
        title: const Text('Notificações', style: TextStyle(color: AppColors.tx, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.grn))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('SAÚDE & NUTRIÇÃO', [
                  _tile(
                    icon: Icons.restaurant_rounded,
                    color: AppColors.grn,
                    title: 'Lembretes de refeição',
                    subtitle: 'Café 7h30 · Almoço 12h · Lanche 15h30 · Jantar 19h',
                    value: _refeicoes,
                    onChanged: (v) {
                      setState(() => _refeicoes = v);
                      _toggle('notif_refeicoes', v,
                        NotificationService.agendarLembretesRefeicao,
                        NotificationService.cancelarLembretesRefeicao,
                      );
                    },
                  ),
                  _tile(
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.org,
                    title: 'Alerta de streak',
                    subtitle: 'Às 20h se você ainda não registrou nada hoje',
                    value: _streak,
                    onChanged: (v) {
                      setState(() => _streak = v);
                      _toggle('notif_streak', v,
                        NotificationService.agendarLembreteStreak,
                        () => NotificationService.cancelarLembretesRefeicao(),
                      );
                    },
                  ),
                  _tile(
                    icon: Icons.water_drop_rounded,
                    color: AppColors.acc,
                    title: 'Lembrete de hidratação',
                    subtitle: 'Quando você ainda não registrou água no dia',
                    value: _hidratacao,
                    onChanged: (v) => setState(() => _hidratacao = v),
                  ),
                ]),
                const SizedBox(height: 8),
                _section('FINANCEIRO', [
                  _tile(
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.acc,
                    title: 'Resumo semanal',
                    subtitle: 'Toda segunda-feira às 9h — como estão seus envelopes',
                    value: _financeiro,
                    onChanged: (v) {
                      setState(() => _financeiro = v);
                      _toggle('notif_financeiro', v,
                        NotificationService.agendarResumoFinanceiro,
                        () {},
                      );
                    },
                  ),
                  _tile(
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.red,
                    title: 'Contas a vencer',
                    subtitle: '2 dias antes do vencimento de cada conta',
                    value: _contas,
                    onChanged: (v) => setState(() => _contas = v),
                  ),
                ]),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bord, width: 0.5),
                  ),
                  child: Row(children: [
                    const Text('🦄', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'O Astrix também pode te mandar alertas quando seu envelope estiver no limite ou quando você bater uma meta!',
                        style: TextStyle(color: AppColors.mu, fontSize: 12, height: 1.5),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
    );
  }

  Widget _section(String titulo, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
          child: Text(titulo,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                  color: AppColors.mu, letterSpacing: 0.8)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.bord, width: 0.5),
          ),
          child: Column(children: tiles),
        ),
      ],
    );
  }

  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, color: AppColors.tx, fontWeight: FontWeight.w500)),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.mu)),
        ])),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.grn,
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? AppColors.grn.withOpacity(0.3) : AppColors.bord),
        ),
      ]),
    );
  }
}
