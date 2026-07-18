import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/jejum_provider.dart';
import '../../../services/jejum_api_service.dart';

class _NotifItem {
  final String emoji;
  final String titulo;
  final String subtitulo;
  final String chave;
  final bool defaultOn;

  const _NotifItem({
    required this.emoji,
    required this.titulo,
    required this.subtitulo,
    required this.chave,
    this.defaultOn = true,
  });
}

const _kNotifs = [
  _NotifItem(
    emoji: '🚀',
    titulo: 'Início do jejum',
    subtitulo: 'Seu jejum começou. Você consegue!',
    chave: 'inicio_jejum',
  ),
  _NotifItem(
    emoji: '💧',
    titulo: 'Hidratação (a cada 2h)',
    subtitulo: 'Lembrete para beber água durante o jejum',
    chave: 'hidratacao',
  ),
  _NotifItem(
    emoji: '🔥',
    titulo: 'Marco 12h',
    subtitulo: 'Queima de gordura ativada!',
    chave: 'marco_12h',
  ),
  _NotifItem(
    emoji: '✨',
    titulo: 'Marco 16h',
    subtitulo: 'Você chegou lá! Autofagia começando.',
    chave: 'marco_16h',
  ),
  _NotifItem(
    emoji: '🍽️',
    titulo: 'Janela abre em 30min',
    subtitulo: 'Aviso antes de poder comer',
    chave: 'janela_em_30min',
  ),
  _NotifItem(
    emoji: '⏰',
    titulo: 'Janela fechando',
    subtitulo: 'Última hora da sua janela alimentar',
    chave: 'janela_fechando',
  ),
  _NotifItem(
    emoji: '⚠️',
    titulo: 'Alerta de proteína',
    subtitulo: 'Se macro de proteína estiver baixo na janela',
    chave: 'alerta_proteina',
    defaultOn: false,
  ),
];

/// Tela de configuração de notificações push do jejum.
class JejumNotificacoesScreen extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;

  const JejumNotificacoesScreen({
    super.key,
    required this.membroId,
    required this.familiaId,
  });

  @override
  ConsumerState<JejumNotificacoesScreen> createState() =>
      _JejumNotificacoesScreenState();
}

class _JejumNotificacoesScreenState
    extends ConsumerState<JejumNotificacoesScreen> {
  late Map<String, bool> _prefs;
  bool _salvando = false;
  bool _inicializado = false;

  @override
  void initState() {
    super.initState();
    _prefs = {for (final n in _kNotifs) n.chave: n.defaultOn};
  }

  void _inicializarDaConfig(Map<String, dynamic> config) {
    if (_inicializado) return;
    _inicializado = true;
    final notifConfig =
        config['notificacoes_config'] as Map<String, dynamic>? ?? {};
    for (final n in _kNotifs) {
      if (notifConfig.containsKey(n.chave)) {
        _prefs[n.chave] = notifConfig[n.chave] as bool? ?? n.defaultOn;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(jejumConfigProvider(
        (membroId: widget.membroId, familiaId: widget.familiaId)));

    configAsync.whenData((config) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _inicializarDaConfig(config));
      });
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.mu),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notificações',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.tx,
              ),
            ),
            Text(
              'Configurar lembretes do jejum',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        actions: [
          if (_salvando)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: AppColors.acc,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _salvar,
              child: const Text(
                'Salvar',
                style: TextStyle(
                    color: AppColors.acc, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePad, 8, AppSpacing.pagePad, 40),
        children: [
          // Lista de toggles
          ...List.generate(_kNotifs.length, (i) {
            final n = _kNotifs[i];
            return _buildToggleRow(n);
          }),

          const SizedBox(height: 24),

          // Seção PREVIEW
          const Text(
            'PREVIEW',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.mu,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          _buildNotifPreview(
            emoji: '🔥',
            titulo: 'Marco: 12h de jejum atingidas!',
            corpo: 'Queima de gordura ativada 💪',
          ),
          const SizedBox(height: 8),
          _buildNotifPreview(
            emoji: '💧',
            titulo: 'Hora 10 do jejum',
            corpo: 'Beba 500ml agora. A fome vai ceder 😊',
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(_NotifItem n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
        border: Border.all(color: AppColors.bord, width: 0.8),
      ),
      child: Row(
        children: [
          Text(n.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.titulo,
                  style: AppTextStyles.bodySm
                      .copyWith(fontWeight: FontWeight.w600, color: AppColors.tx),
                ),
                Text(n.subtitulo, style: AppTextStyles.caption),
              ],
            ),
          ),
          Switch(
            value: _prefs[n.chave] ?? n.defaultOn,
            onChanged: (v) => setState(() => _prefs[n.chave] = v),
            activeColor: AppColors.acc,
            activeTrackColor: AppColors.acc.withOpacity(0.3),
            inactiveThumbColor: AppColors.mu,
            inactiveTrackColor: AppColors.bord,
          ),
        ],
      ),
    );
  }

  Widget _buildNotifPreview({
    required String emoji,
    required String titulo,
    required String corpo,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surf,
        borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
        border: Border.all(color: AppColors.bord, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nosso Bolso',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.mu,
                          fontWeight: FontWeight.bold,
                          fontSize: 10),
                    ),
                    Text(
                      'agora',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.mu, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  titulo,
                  style: AppTextStyles.bodySm.copyWith(
                      fontWeight: FontWeight.w600, color: AppColors.tx),
                ),
                Text(corpo, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await JejumApiService.salvarConfig(widget.membroId, {
        'familia_id': widget.familiaId,
        'notificacoes_config': _prefs,
      });
      ref.invalidate(jejumConfigProvider(
          (membroId: widget.membroId, familiaId: widget.familiaId)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notificações salvas!'),
            backgroundColor: AppColors.grn,
          ),
        );
      }
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
