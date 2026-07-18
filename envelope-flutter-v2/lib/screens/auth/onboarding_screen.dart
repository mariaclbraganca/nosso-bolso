import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../constants.dart';

// ─────────────────────────────────────────────
// Perfis de família disponíveis no onboarding
// ─────────────────────────────────────────────
enum _Perfil {
  solteiro,
  comFilhos,
  numerosa,
}

extension _PerfilExt on _Perfil {
  String get label {
    switch (this) {
      case _Perfil.solteiro:   return 'Solteiro / Casal sem filhos';
      case _Perfil.comFilhos:  return 'Família com filhos';
      case _Perfil.numerosa:   return 'Família numerosa (4+ pessoas)';
    }
  }

  String get emoji {
    switch (this) {
      case _Perfil.solteiro:   return '👫';
      case _Perfil.comFilhos:  return '👨‍👩‍👧';
      case _Perfil.numerosa:   return '👨‍👩‍👧‍👦';
    }
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _familyController = TextEditingController();
  final _codeController   = TextEditingController();
  final _saldoController  = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _familyController.dispose();
    _codeController.dispose();
    _saldoController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Geração de envelopes baseada em perfil/renda
  // ─────────────────────────────────────────────
  List<Map<String, dynamic>> _gerarEnvelopes(
    _Perfil perfil,
    double renda,
    String familyId,
  ) {
    final bool temRenda = renda > 0;

    // Definições: [nome, emoji, percentual]
    final List<List<dynamic>> def;
    switch (perfil) {
      case _Perfil.solteiro:
        def = [
          ['Alimentação', '🥗', 0.25],
          ['Moradia',      '🏠', 0.30],
          ['Transporte',   '🚗', 0.15],
          ['Lazer',        '🎉', 0.10],
          ['Saúde',        '💊', 0.05],
          ['Outros',       '📦', 0.15],
        ];
        break;
      case _Perfil.comFilhos:
        def = [
          ['Alimentação', '🥗', 0.30],
          ['Moradia',      '🏠', 0.25],
          ['Transporte',   '🚗', 0.10],
          ['Educação',     '🎓', 0.15],
          ['Lazer',        '🎉', 0.08],
          ['Saúde',        '💊', 0.07],
          ['Outros',       '📦', 0.05],
        ];
        break;
      case _Perfil.numerosa:
        def = [
          ['Alimentação', '🥗', 0.35],
          ['Moradia',      '🏠', 0.25],
          ['Transporte',   '🚗', 0.10],
          ['Educação',     '🎓', 0.15],
          ['Saúde',        '💊', 0.10],
          ['Outros',       '📦', 0.05],
        ];
        break;
    }

    return def.map((d) => {
      'nome_envelope':   d[0] as String,
      'emoji':           d[1] as String,
      'valor_planejado': temRenda ? renda * (d[2] as double) : 0.0,
      'familia_id':      familyId,
    }).toList();
  }

  // ─────────────────────────────────────────────
  // Dialog de escolha de perfil
  // ─────────────────────────────────────────────
  Future<_Perfil?> _showPerfilDialog() {
    _Perfil? selecionado = _Perfil.solteiro;

    return showDialog<_Perfil>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Qual o perfil da sua família?',
                style: AppTextStyles.titleSm,
              ),
              const SizedBox(height: 4),
              Text(
                'Vamos sugerir envelopes com valores personalizados.',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _Perfil.values.map((perfil) {
              return InkWell(
                onTap: () => setDialogState(() => selecionado = perfil),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: selecionado == perfil
                        ? AppColors.acc.withOpacity(0.12)
                        : AppColors.surf,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: selecionado == perfil
                          ? AppColors.acc.withOpacity(0.5)
                          : AppColors.bord,
                    ),
                  ),
                  child: Row(
                    children: [
                      Radio<_Perfil>(
                        value: perfil,
                        groupValue: selecionado,
                        onChanged: (v) => setDialogState(() => selecionado = v),
                        activeColor: AppColors.acc,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      Text(perfil.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          perfil.label,
                          style: AppTextStyles.body.copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, _Perfil.solteiro),
              child: Text('PULAR', style: AppTextStyles.caption.copyWith(color: AppColors.mu)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selecionado ?? _Perfil.solteiro),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.acc,
                foregroundColor: AppColors.bg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                ),
                elevation: 0,
              ),
              child: Text(
                'CONFIRMAR',
                style: AppTextStyles.bodySm.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.bg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Fluxo principal: criar família
  // ─────────────────────────────────────────────
  void _createFamily() async {
    final name  = _familyController.text.trim();
    final renda = double.tryParse(_saldoController.text.replaceAll(',', '.')) ?? 0.0;
    if (name.isEmpty) return;

    // Abre o dialog de perfil antes de criar
    final perfil = await _showPerfilDialog() ?? _Perfil.solteiro;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw 'Usuário não logado';

      final familyRes = await supabase
          .from('familias')
          .insert({'nome': name})
          .select('id, codigo_acesso')
          .single();

      final familyId   = familyRes['id'] as String;
      final accessCode = familyRes['codigo_acesso'] as String? ?? '---';

      final updatedUser = await supabase.from('usuarios').upsert({
        'id':         user.id,
        'email':      user.email,
        'nome':       user.userMetadata?['nome'] ?? user.email?.split('@')[0] ?? 'Usuário',
        'familia_id': familyId,
        'role':       'admin',
      }).select('*, familias(*)').single();

      ref.read(perfilUsuarioLogadoProvider.notifier).atualizarEstado(updatedUser);

      // Envelopes personalizados por perfil e renda
      final envelopes = _gerarEnvelopes(perfil, renda, familyId);
      await supabase.from('envelopes').insert(envelopes);

      // Lança receita inicial se informada (como renda mensal)
      if (renda > 0) {
        await supabase.from('transacoes').insert({
          'familia_id': familyId,
          'usuario_id': user.id,
          'descricao':  'Renda Mensal — Onboarding',
          'valor':      renda,
          'tipo':       'receita',
        });
      }

      if (mounted) await _showSuccessDialog(accessCode);
    } catch (e) {
      if (mounted) _showError('Erro ao criar família: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────
  // Dialog de sucesso com código de acesso
  // ─────────────────────────────────────────────
  Future<void> _showSuccessDialog(String code) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Família Criada!',
          style: TextStyle(color: AppColors.tx, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Compartilhe este código com quem vai usar o app com você:',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.acc.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
                border: Border.all(color: AppColors.acc.withOpacity(0.3)),
              ),
              child: SelectableText(
                code,
                style: AppTextStyles.monoLg.copyWith(
                  color: AppColors.acc,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Código copiado!')),
              );
            },
            child: Text(
              'COPIAR',
              style: TextStyle(color: AppColors.acc, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.acc),
            child: const Text(
              'COMEÇAR',
              style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Entrar em família existente via código
  // ─────────────────────────────────────────────
  void _joinFamily() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw 'Usuário não logado';

      final familyRes = await supabase
          .from('familias')
          .select('id')
          .eq('codigo_acesso', code)
          .maybeSingle();

      if (familyRes == null) throw 'Código de família inválido ou não encontrado.';

      final familyId = familyRes['id'];

      final updatedUser = await supabase.from('usuarios').upsert({
        'id':         user.id,
        'email':      user.email,
        'nome':       user.userMetadata?['nome'] ?? user.email?.split('@')[0] ?? 'Usuário',
        'familia_id': familyId,
      }).select('*, familias(*)').single();

      ref.read(perfilUsuarioLogadoProvider.notifier).atualizarEstado(updatedUser);
    } catch (e) {
      if (mounted) _showError('Erro ao entrar na família: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.red),
    );
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.bg, Color(0xFF111408), AppColors.bg],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePad),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  const Icon(Icons.auto_awesome, size: 60, color: AppColors.acc),
                  const SizedBox(height: 16),
                  Text(
                    'BEM-VINDO!',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: AppColors.tx,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Para começar, você precisa de uma família.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 48),

                  _buildCard(
                    title: 'CRIAR NOVA FAMÍLIA',
                    subtitle: 'Gerencie sua própria economia familiar',
                    controller: _familyController,
                    hint: 'Nome da Família (Ex: Silva)',
                    btnText: 'Criar Família',
                    onPressed: _isLoading ? null : _createFamily,
                    extraController: _saldoController,
                    extraHint: 'Renda mensal da família (R\$)',
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'OU',
                    style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  _buildCard(
                    title: 'ENTRAR EM FAMÍLIA',
                    subtitle: 'Use o código de convite de alguém',
                    controller: _codeController,
                    hint: 'Código de Acesso (Ex: BOLSO-1234)',
                    btnText: 'Entrar na Família',
                    onPressed: _isLoading ? null : _joinFamily,
                  ),

                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: () => ref.read(authServiceProvider).signOut(),
                    child: Text('Sair da conta', style: AppTextStyles.caption),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required String hint,
    required String btnText,
    required VoidCallback? onPressed,
    TextEditingController? extraController,
    String? extraHint,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.bord),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,    style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1)),
          Text(subtitle, style: AppTextStyles.caption),
          const SizedBox(height: 20),
          _field(controller, hint, false),
          if (extraController != null) ...[
            const SizedBox(height: 12),
            _field(extraController, extraHint ?? '', true, isNumber: true),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.acc,
              foregroundColor: AppColors.bg,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                  )
                : Text(
                    btnText,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, bool obscure, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.caption,
        filled: true,
        fillColor: AppColors.surf,
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn), borderSide: const BorderSide(color: AppColors.bord)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn), borderSide: const BorderSide(color: AppColors.bord)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn), borderSide: const BorderSide(color: AppColors.acc, width: 1.5)),
      ),
    );
  }
}
