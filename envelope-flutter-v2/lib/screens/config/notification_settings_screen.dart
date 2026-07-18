import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/notification_service.dart';
import '../../services/ifood_notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // Saúde
  bool _cafe      = true;
  bool _almoco    = true;
  bool _lanche    = true;
  bool _jantar    = true;
  bool _streak    = true;
  bool _hidra     = true;
  // Financeiro
  bool _resumo    = true;
  bool _contas    = true;

  bool _ifoodPermissao = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cafe    = prefs.getBool('notif_cafe')      ?? true;
      _almoco  = prefs.getBool('notif_almoco')    ?? true;
      _lanche  = prefs.getBool('notif_lanche')    ?? true;
      _jantar  = prefs.getBool('notif_jantar')    ?? true;
      _streak  = prefs.getBool('notif_streak')    ?? true;
      _hidra   = prefs.getBool('notif_hidratacao') ?? true;
      _resumo  = prefs.getBool('notif_financeiro') ?? true;
      _contas  = prefs.getBool('notif_contas')    ?? true;
      _loading = false;
    });
    final temPermissao = await IfoodNotificationService.temPermissao();
    if (mounted) setState(() => _ifoodPermissao = temPermissao);
  }

  Future<void> _toggle(
    String key,
    bool value,
    VoidCallback? onEnable,
    VoidCallback? onDisable,
  ) async {
    await NotificationService.setEnabled(key, value);
    if (value) {
      onEnable?.call();
    } else {
      onDisable?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.mu, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Notificações', style: AppTextStyles.titleSm),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.acc))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.pagePad),
              children: [
                // ── Saúde & Nutrição ──────────────────────────────────────────
                _SectionHeader(label: 'SAÚDE & NUTRIÇÃO'),
                const SizedBox(height: 8),
                _SectionCard(children: [
                  _Tile(
                    icon: Icons.free_breakfast_rounded,
                    color: AppColors.org,
                    title: 'Café da manhã',
                    subtitle: 'Lembrete às 7h30',
                    value: _cafe,
                    onChanged: (v) {
                      setState(() => _cafe = v);
                      _toggle(
                        'notif_cafe',
                        v,
                        v ? NotificationService.agendarLembretesRefeicao : null,
                        v ? null : NotificationService.cancelarLembretesRefeicao,
                      );
                    },
                  ),
                  const _Divider(),
                  _Tile(
                    icon: Icons.restaurant_rounded,
                    color: AppColors.grn,
                    title: 'Almoço',
                    subtitle: 'Lembrete às 12h00',
                    value: _almoco,
                    onChanged: (v) {
                      setState(() => _almoco = v);
                      _toggle(
                        'notif_almoco',
                        v,
                        v ? NotificationService.agendarLembretesRefeicao : null,
                        v ? null : NotificationService.cancelarLembretesRefeicao,
                      );
                    },
                  ),
                  const _Divider(),
                  _Tile(
                    icon: Icons.apple_rounded,
                    color: AppColors.acc,
                    title: 'Lanche da tarde',
                    subtitle: 'Lembrete às 15h30',
                    value: _lanche,
                    onChanged: (v) {
                      setState(() => _lanche = v);
                      _toggle(
                        'notif_lanche',
                        v,
                        v ? NotificationService.agendarLembretesRefeicao : null,
                        v ? null : NotificationService.cancelarLembretesRefeicao,
                      );
                    },
                  ),
                  const _Divider(),
                  _Tile(
                    icon: Icons.nights_stay_rounded,
                    color: AppColors.pur,
                    title: 'Jantar',
                    subtitle: 'Lembrete às 19h00',
                    value: _jantar,
                    onChanged: (v) {
                      setState(() => _jantar = v);
                      _toggle(
                        'notif_jantar',
                        v,
                        v ? NotificationService.agendarLembretesRefeicao : null,
                        v ? null : NotificationService.cancelarLembretesRefeicao,
                      );
                    },
                  ),
                  const _Divider(),
                  _Tile(
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.red,
                    title: 'Alerta de streak',
                    subtitle: 'Às 20h se ainda não registrou hoje',
                    value: _streak,
                    onChanged: (v) {
                      setState(() => _streak = v);
                      _toggle(
                        'notif_streak',
                        v,
                        v ? NotificationService.agendarLembreteStreak : null,
                        v ? null : NotificationService.cancelarLembreteStreak,
                      );
                    },
                  ),
                  const _Divider(),
                  _Tile(
                    icon: Icons.water_drop_rounded,
                    color: AppColors.blu,
                    title: 'Hidratação',
                    subtitle: 'Quando ainda não registrou água no dia',
                    value: _hidra,
                    onChanged: (v) {
                      setState(() => _hidra = v);
                      _toggle('notif_hidratacao', v, null, null);
                    },
                  ),
                ]),

                const SizedBox(height: AppSpacing.sectionGap),

                // ── Financeiro ────────────────────────────────────────────────
                _SectionHeader(label: 'FINANCEIRO'),
                const SizedBox(height: 8),
                _SectionCard(children: [
                  _Tile(
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.acc,
                    title: 'Resumo semanal',
                    subtitle:
                        'Toda segunda-feira às 9h — como estão seus envelopes',
                    value: _resumo,
                    onChanged: (v) {
                      setState(() => _resumo = v);
                      _toggle(
                        'notif_financeiro',
                        v,
                        v ? NotificationService.agendarResumoFinanceiro : null,
                        null,
                      );
                    },
                  ),
                  const _Divider(),
                  _Tile(
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.red,
                    title: 'Contas a vencer',
                    subtitle: '2 dias antes do vencimento de cada conta',
                    value: _contas,
                    onChanged: (v) {
                      setState(() => _contas = v);
                      _toggle('notif_contas', v, null, null);
                    },
                  ),
                ]),

                const SizedBox(height: AppSpacing.sectionGap),

                // ── Captura Automática ────────────────────────────────────────
                _SectionHeader(label: 'CAPTURA AUTOMÁTICA'),
                const SizedBox(height: 8),
                _SectionCard(children: [
                  _CapturaItem(
                    emoji: '🟣',
                    emojiColor: const Color(0xFF820AD1),
                    titulo: 'Nubank',
                    subtitulo: 'Captura compras e Pix automaticamente',
                    ativo: _ifoodPermissao,
                  ),
                  const _Divider(),
                  _CapturaItem(
                    emoji: '🍔',
                    emojiColor: AppColors.red,
                    titulo: 'iFood Benefícios',
                    subtitulo: 'Captura compras aprovadas automaticamente',
                    ativo: _ifoodPermissao,
                  ),
                ]),
                if (!_ifoodPermissao) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.org.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      border: Border.all(color: AppColors.org.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.org, size: 18),
                          const SizedBox(width: 8),
                          Text('Permissão necessária',
                              style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.org, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                          'Para capturar transações do Nubank e iFood automaticamente, o app precisa de acesso às notificações.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.mu, height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              await IfoodNotificationService.solicitarPermissao();
                              final ok = await IfoodNotificationService.temPermissao();
                              if (mounted) setState(() => _ifoodPermissao = ok);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.acc,
                              foregroundColor: AppColors.bg,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                              minimumSize: const Size.fromHeight(42),
                            ),
                            child: Text('Conceder permissão',
                                style: AppTextStyles.bodySm.copyWith(
                                    fontWeight: FontWeight.w700, color: AppColors.bg)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.sectionGap),

                // ── Card Astrix ───────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusCard),
                    border: Border.all(color: AppColors.bord, width: 0.5),
                  ),
                  child: Row(children: [
                    const Text('🦄', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Astrix te avisa!',
                              style: AppTextStyles.bodySm
                                  .copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          const Text(
                            'O Astrix também envia alertas quando seu envelope '
                            'estiver no limite ou quando você bater uma meta.',
                            style: TextStyle(
                                color: AppColors.mu,
                                fontSize: 12,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.mu,
            letterSpacing: 0.8,
          ),
        ),
      );
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Column(children: children),
      );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Divider(
      height: 1, thickness: 0.5, indent: 60, endIndent: 14);
}

class _CapturaItem extends StatelessWidget {
  final String emoji;
  final Color emojiColor;
  final String titulo;
  final String subtitulo;
  final bool ativo;

  const _CapturaItem({
    required this.emoji,
    required this.emojiColor,
    required this.titulo,
    required this.subtitulo,
    required this.ativo,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: emojiColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitulo, style: AppTextStyles.caption),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (ativo ? AppColors.grn : AppColors.org).withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
            ),
            child: Text(
              ativo ? 'Ativo' : 'Inativo',
              style: AppTextStyles.caption.copyWith(
                color: ativo ? AppColors.grn : AppColors.org,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ]),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.bodySm
                        .copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.grn,
            trackColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected)
                    ? AppColors.grn.withOpacity(0.3)
                    : AppColors.bord),
          ),
        ]),
      );
}
