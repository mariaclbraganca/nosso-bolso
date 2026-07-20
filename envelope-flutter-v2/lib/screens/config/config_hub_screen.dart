import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../providers/usuarios_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pin_provider.dart';
import 'perfil_familia_screen.dart';
import 'configuracao_ia_screen.dart';
import 'notification_settings_screen.dart';
import 'insights_screen.dart';
import 'pin_screen.dart';
import 'simulador_gastos_screen.dart';

class ConfigHubScreen extends ConsumerWidget {
  const ConfigHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(perfilUsuarioLogadoProvider);
    final perfil = perfilAsync.asData?.value;
    final nome = (perfil?['nome'] as String? ?? 'você').split(' ').first;
    final email = perfil?['email'] as String? ?? '';
    final familia = perfil?['familias'] as Map<String, dynamic>?;
    final nomeFamilia = familia?['nome'] as String? ?? 'Família';

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
        title: Text('Configurações', style: AppTextStyles.titleSm),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePad),
        children: [
          // ── Header do usuário ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.acc.withOpacity(0.10),
                  AppColors.surf,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(
                  color: AppColors.acc.withOpacity(0.2), width: 0.8),
            ),
            child: Row(children: [
              _AvatarGrande(nome: nome),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(email, style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.group_rounded,
                          color: AppColors.acc, size: 12),
                      const SizedBox(width: 4),
                      Text(nomeFamilia,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.acc)),
                    ]),
                  ],
                ),
              ),
            ]),
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          // ── Seção Principal ───────────────────────────────────────────────
          _SectionLabel(label: 'CONTA & FAMÍLIA'),
          const SizedBox(height: 8),
          _MenuCard(children: [
            _MenuItem(
              emoji: '👨‍👩‍👧',
              label: 'Perfil da Família',
              subtitle: 'Membros, código de acesso e conta',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PerfilFamiliaScreen()),
              ),
            ),
          ]),

          const SizedBox(height: AppSpacing.cardGap),

          _SectionLabel(label: 'INTELIGÊNCIA'),
          const SizedBox(height: 8),
          _MenuCard(children: [
            _MenuItem(
              emoji: '🔮',
              label: 'Insights IA',
              subtitle: 'Relatório semanal do Astrix sobre suas finanças',
              badge: 'Novo',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const InsightsScreen()),
              ),
            ),
            const _Divider(),
            _MenuItem(
              emoji: '🤖',
              label: 'Configuração de IA',
              subtitle: 'Chave Gemini para NFC-e e análises avançadas',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ConfiguracaoIAScreen()),
              ),
            ),
            const _Divider(),
            _MenuItem(
              emoji: '🔮',
              label: 'Simulador de gastos',
              subtitle: 'Planeje um cenário futuro (ex: mudança de cidade)',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SimuladorGastosScreen()),
              ),
            ),
          ]),

          const SizedBox(height: AppSpacing.cardGap),

          _SectionLabel(label: 'PREFERÊNCIAS'),
          const SizedBox(height: 8),
          _MenuCard(children: [
            _MenuItem(
              emoji: '🔔',
              label: 'Notificações',
              subtitle: 'Lembretes de refeição, streak, resumo semanal',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen()),
              ),
            ),
            const _Divider(),
            _MenuItem(
              emoji: '📊',
              label: 'Exportar dados',
              subtitle: 'Baixar relatório em PDF',
              showChevron: false,
              trailing: const Icon(Icons.open_in_new,
                  color: AppColors.mu, size: 16),
              onTap: () => launchUrl(
                Uri.parse('https://enqltolmazmrkdghitae.supabase.co/storage/v1/object/public/exports/'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ]),

          // ── Segurança (só admins) ─────────────────────────────────────────
          if (perfil?['role'] == 'admin') ...[
            const SizedBox(height: AppSpacing.cardGap),
            _SectionLabel(label: 'SEGURANÇA'),
            const SizedBox(height: 8),
            _MenuCard(children: [
              _MenuItem(
                emoji: '🔐',
                label: 'PIN de Patrimônio',
                subtitle: 'Configurar ou alterar o PIN para acessar dados financeiros privados',
                onTap: () async {
                  final pinConfigurado = await ref.read(pinConfiguradoProvider.future);
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PinScreen(
                        mode: pinConfigurado ? PinMode.verify : PinMode.setup,
                        titulo: pinConfigurado ? 'Confirme o PIN atual' : 'Configurar PIN',
                        onSuccess: () {
                          Navigator.pop(context);
                          if (pinConfigurado) {
                            // Já verificado — agora deixa criar novo
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PinScreen(
                                  mode: PinMode.setup,
                                  titulo: 'Definir novo PIN',
                                  onSuccess: () {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('PIN atualizado com sucesso'),
                                        backgroundColor: AppColors.grn,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('PIN configurado com sucesso'),
                                backgroundColor: AppColors.grn,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ]),
          ],

          const SizedBox(height: AppSpacing.sectionGap),

          // ── Sair ──────────────────────────────────────────────────────────
          _MenuCard(children: [
            _MenuItem(
              emoji: '🚪',
              label: 'Sair',
              subtitle: 'Encerrar sessão neste dispositivo',
              labelColor: AppColors.red,
              showChevron: false,
              onTap: () => _confirmarLogout(context, ref),
            ),
          ]),

          const SizedBox(height: AppSpacing.sectionGap),

          // ── Footer versão ─────────────────────────────────────────────────
          Center(
            child: Column(children: [
              const Text('🦄', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              const Text(
                'Envelope App v2',
                style: TextStyle(color: AppColors.mu, fontSize: 11),
              ),
              const Text(
                'Feito com amor pela família Silva 💚',
                style: TextStyle(color: AppColors.mu, fontSize: 10),
              ),
            ]),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _confirmarLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
        title: const Text('Sair da conta?',
            style: TextStyle(
                color: AppColors.tx, fontWeight: FontWeight.bold)),
        content: const Text(
          'Você precisará fazer login novamente para acessar o app.',
          style: TextStyle(
              color: AppColors.mu, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.mu)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authServiceProvider).signOut();
    // Bloqueia a sessão admin (PIN) — não deve seguir desbloqueada p/ o próximo
    // usuário que logar neste aparelho.
    ref.read(pinNotifierProvider.notifier).bloquear();
    // Limpa o cache do perfil para o AuthGate reavaliar
    ref.invalidate(perfilUsuarioLogadoProvider);
    // O splash faz pushReplacementNamed('/home'), tirando o AuthGate da pilha.
    // Por isso, ao sair, navegamos explicitamente de volta ao gate limpando
    // TODA a pilha — o gate reavalia a sessão (agora nula) e mostra o Login.
    if (context.mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/gate', (route) => false);
    }
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

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

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

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
      height: 1, thickness: 0.5, indent: 52, endIndent: 14);
}

class _MenuItem extends StatelessWidget {
  final String emoji;
  final String label;
  final String subtitle;
  final String? badge;
  final Color? labelColor;
  final bool showChevron;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuItem({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.labelColor,
    this.showChevron = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surf,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.bord, width: 0.5),
              ),
              child: Center(
                child:
                    Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(
                      label,
                      style: AppTextStyles.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: labelColor ?? AppColors.tx,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.acc.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusChip),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                              color: AppColors.acc,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (showChevron && trailing == null)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.mu, size: 18),
          ]),
        ),
      );
}

class _AvatarGrande extends StatelessWidget {
  final String nome;
  const _AvatarGrande({required this.nome});

  @override
  Widget build(BuildContext context) {
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';
    final cor = AppColors.corDoUsuario(nome);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: cor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: cor.withOpacity(0.5), width: 1.5),
      ),
      child: Center(
        child: Text(
          inicial,
          style: TextStyle(
            color: cor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
