import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/usuarios_provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants.dart';

class PerfilFamiliaScreen extends ConsumerStatefulWidget {
  const PerfilFamiliaScreen({super.key});

  @override
  ConsumerState<PerfilFamiliaScreen> createState() =>
      _PerfilFamiliaScreenState();
}

class _PerfilFamiliaScreenState extends ConsumerState<PerfilFamiliaScreen> {
  final _nomeCtrl = TextEditingController();
  bool _salvandoNome = false;
  bool _showCode = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvarNome(String usuarioId) async {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) return;
    setState(() => _salvandoNome = true);
    try {
      await supabase.from('usuarios').update({'nome': nome}).eq('id', usuarioId);
      ref.read(perfilUsuarioLogadoProvider.notifier).recarregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nome atualizado!'),
            backgroundColor: AppColors.grn,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvandoNome = false);
    }
  }

  Future<void> _confirmarSairFamilia(
      String usuarioId, String familiaId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
        title: const Text('Sair da família?',
            style: TextStyle(color: AppColors.tx, fontWeight: FontWeight.bold)),
        content: const Text(
          'Você perderá acesso aos dados compartilhados da família. '
          'Essa ação não pode ser desfeita.',
          style: TextStyle(color: AppColors.mu, fontSize: 13, height: 1.4),
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
    try {
      await supabase
          .from('usuarios')
          .update({'familia_id': null}).eq('id', usuarioId);
      ref.read(perfilUsuarioLogadoProvider.notifier).recarregar();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authServiceProvider).signOut();
  }

  void _copiarCodigo(String codigo) {
    Clipboard.setData(ClipboardData(text: codigo));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado!'),
        backgroundColor: AppColors.acc,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final perfilAsync = ref.watch(perfilUsuarioLogadoProvider);
    final membrosAsync = ref.watch(listaUsuariosProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Família', style: AppTextStyles.titleSm),
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.mu, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: perfilAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.acc)),
        error: (e, _) => Center(
            child: Text('Erro: $e',
                style: const TextStyle(color: AppColors.red))),
        data: (perfil) {
          if (perfil == null) {
            return const Center(
              child: Text('Nenhum perfil carregado.',
                  style: TextStyle(color: AppColors.mu)),
            );
          }

          final nome = perfil['nome'] as String? ?? '';
          final email = perfil['email'] as String? ?? '';
          final usuarioId = perfil['id'] as String? ?? '';
          final familiaId = perfil['familia_id'] as String? ?? '';
          final familia = perfil['familias'] as Map<String, dynamic>?;
          final codigoFamilia = familia?['codigo_acesso'] as String? ??
              familia?['id'] as String? ??
              familiaId;
          final nomeFamilia = familia?['nome'] as String? ?? 'Minha Família';
          // ignore: unused_local_variable
          final isAdmin = (perfil['role'] as String? ?? 'membro') == 'admin';

          if (_nomeCtrl.text.isEmpty) _nomeCtrl.text = nome;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePad),
            children: [
              // ── Card Família ────────────────────────────────────────────────
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.acc.withOpacity(0.15),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: const Center(
                          child: Text('👨‍👩‍👧',
                              style: TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nomeFamilia,
                                style: AppTextStyles.body.copyWith(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('Código de acesso',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    // Código de acesso
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surf,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusInput),
                        border: Border.all(color: AppColors.bord),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            _showCode
                                ? codigoFamilia
                                : '•' * codigoFamilia.length.clamp(6, 24),
                            style: AppTextStyles.bodySm.copyWith(
                              fontFamily: 'monospace',
                              letterSpacing: _showCode ? 1.2 : 2,
                              color: AppColors.acc,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showCode = !_showCode),
                          child: Icon(
                            _showCode
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.mu,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => _copiarCodigo(codigoFamilia),
                          child: const Icon(Icons.copy_rounded,
                              color: AppColors.acc, size: 18),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Compartilhe este código para convidar membros à família.',
                      style: TextStyle(
                          color: AppColors.mu, fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.cardGap),

              // ── Membros ─────────────────────────────────────────────────────
              _SectionLabel(label: 'MEMBROS'),
              const SizedBox(height: 8),
              membrosAsync.when(
                loading: () => const Center(
                    child: Padding(
                  padding: EdgeInsets.all(16),
                  child:
                      CircularProgressIndicator(color: AppColors.acc, strokeWidth: 2),
                )),
                error: (e, _) => Text('Erro: $e',
                    style: const TextStyle(color: AppColors.red)),
                data: (membros) => _SectionCard(
                  child: Column(
                    children: membros.asMap().entries.map((entry) {
                      final i = entry.key;
                      final m = entry.value;
                      final mNome = m['nome'] as String? ?? '?';
                      final mRole =
                          (m['role'] as String? ?? 'membro');
                      final isSelf = m['id'] == usuarioId;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(children: [
                              _Avatar(nome: mNome),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Text(
                                        mNome +
                                            (isSelf ? ' (você)' : ''),
                                        style: AppTextStyles.bodySm
                                            .copyWith(
                                                fontWeight:
                                                    FontWeight.w600),
                                      ),
                                    ]),
                                    const SizedBox(height: 2),
                                    Text(
                                      m['email'] as String? ?? '',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                              _RoleBadge(role: mRole),
                            ]),
                          ),
                          if (i < membros.length - 1)
                            const Divider(
                                height: 1,
                                thickness: 0.5,
                                indent: 14,
                                endIndent: 14),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sectionGap),

              // ── Minha conta ─────────────────────────────────────────────────
              _SectionLabel(label: 'MINHA CONTA'),
              const SizedBox(height: 8),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nome',
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 12)),
                          const SizedBox(height: 6),
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _nomeCtrl,
                                style: AppTextStyles.bodySm,
                                decoration: InputDecoration(
                                  hintText: 'Seu nome',
                                  hintStyle: TextStyle(
                                      color: AppColors.mu, fontSize: 13),
                                  filled: true,
                                  fillColor: AppColors.surf,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusInput),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.acc,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusBtn),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                ),
                                onPressed: _salvandoNome
                                    ? null
                                    : () => _salvarNome(usuarioId),
                                child: _salvandoNome
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black),
                                      )
                                    : const Text('Salvar',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 16),
                          Text('E-mail',
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 12)),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: AppColors.surf,
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusInput),
                            ),
                            child: Text(email,
                                style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.mu)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 0.5),
                    // Logout
                    _ActionRow(
                      icon: Icons.logout_rounded,
                      iconColor: AppColors.red,
                      label: 'Sair da conta',
                      labelColor: AppColors.red,
                      onTap: _logout,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.cardGap),

              // ── Ações de família ────────────────────────────────────────────
              if (familiaId.isNotEmpty) ...[
                _SectionLabel(label: 'AÇÕES'),
                const SizedBox(height: 8),
                _SectionCard(
                  child: Column(children: [
                    _ActionRow(
                      icon: Icons.person_add_outlined,
                      iconColor: AppColors.acc,
                      label: 'Convidar membro',
                      onTap: () => _mostrarModalConvite(
                          context, codigoFamilia, nomeFamilia),
                    ),
                    const Divider(height: 1, thickness: 0.5),
                    _ActionRow(
                      icon: Icons.exit_to_app_rounded,
                      iconColor: AppColors.org,
                      label: 'Sair da família',
                      labelColor: AppColors.org,
                      onTap: () =>
                          _confirmarSairFamilia(usuarioId, familiaId),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  void _mostrarModalConvite(
      BuildContext context, String codigo, String nomeFamilia) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.bord,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('👨‍👩‍👧', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Convidar para $nomeFamilia',
                style: AppTextStyles.titleSm, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Compartilhe o código abaixo com quem você quer convidar.',
              style: TextStyle(color: AppColors.mu, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surf,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusCard),
                border: Border.all(
                    color: AppColors.acc.withOpacity(0.4), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    codigo,
                    style: const TextStyle(
                      color: AppColors.acc,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      _copiarCodigo(codigo);
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.copy_rounded,
                        color: AppColors.acc, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.acc,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusBtn),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  _copiarCodigo(codigo);
                  Navigator.pop(context);
                },
                child: const Text('Copiar código',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 0),
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
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: child,
      );
}

class _Avatar extends StatelessWidget {
  final String nome;
  const _Avatar({required this.nome});

  @override
  Widget build(BuildContext context) {
    final inicial =
        nome.isNotEmpty ? nome[0].toUpperCase() : '?';
    final cor = AppColors.corDoUsuario(nome);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withOpacity(0.5)),
      ),
      child: Center(
        child: Text(
          inicial,
          style: TextStyle(
            color: cor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppColors.gold.withOpacity(0.15)
            : AppColors.bord,
        borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        border: Border.all(
          color: isAdmin
              ? AppColors.gold.withOpacity(0.4)
              : AppColors.bord,
          width: 0.5,
        ),
      ),
      child: Text(
        isAdmin ? 'admin' : 'membro',
        style: TextStyle(
          color: isAdmin ? AppColors.gold : AppColors.mu,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodySm.copyWith(
                  color: labelColor ?? AppColors.tx,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.mu, size: 18),
          ]),
        ),
      );
}
