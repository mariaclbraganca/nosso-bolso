import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameController            = TextEditingController();
  final _emailController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    final name     = _nameController.text.trim();
    final email    = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final confirm  = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showError('Preencha todos os campos');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _showError('Digite um e-mail válido');
      return;
    }
    if (password.length < 6) {
      _showError('A senha deve ter pelo menos 6 caracteres');
      return;
    }
    if (password != confirm) {
      _showError('As senhas não coincidem');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signUpWithEmail(email, password, name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta criada com sucesso! Seja bem-vindo 🎉'),
            backgroundColor: AppColors.grn,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      String msgAmigavel = 'Não foi possível cadastrar no momento.';
      if (errStr.contains('already registered') || errStr.contains('already in use')) {
        msgAmigavel = 'Este e-mail já está cadastrado. Tente entrar.';
      } else if (errStr.contains('network') || errStr.contains('socket') || errStr.contains('connection')) {
        msgAmigavel = 'Erro de conexão. Verifique sua internet.';
      } else if (errStr.contains('password')) {
        msgAmigavel = 'A senha informada não é forte o suficiente.';
      }
      if (mounted) _showError(msgAmigavel);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.tx),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Voltar',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Icon(Icons.person_add_outlined, size: 56, color: AppColors.acc),
                  const SizedBox(height: 12),
                  Text(
                    'CRIAR CONTA',
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2, color: AppColors.tx),
                  ),
                  const SizedBox(height: 6),
                  Text('Comece sua jornada financeira hoje', style: AppTextStyles.caption),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.bord),
                    ),
                    child: Column(
                      children: [
                        _field(_nameController, 'Seu Nome', Icons.person_outline, false, null),
                        const SizedBox(height: 12),
                        _field(_emailController, 'Email', Icons.email_outlined, false, null, type: TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        _field(
                          _passwordController, 'Senha (mín. 6 chars)', Icons.lock_outline, _obscurePassword,
                          IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.mu, size: 20),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _field(
                          _confirmPasswordController, 'Confirmar Senha', Icons.lock_outline, _obscureConfirmPassword,
                          IconButton(
                            icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.mu, size: 20),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.acc,
                            foregroundColor: AppColors.bg,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                              : const Text('Cadastrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Já tem conta? Entrar agora', style: AppTextStyles.body.copyWith(color: AppColors.mu)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon,
    bool obscure,
    Widget? suffix, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.caption,
        prefixIcon: Icon(icon, color: AppColors.mu, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surf,
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn), borderSide: const BorderSide(color: AppColors.bord)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn), borderSide: const BorderSide(color: AppColors.bord)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn), borderSide: const BorderSide(color: AppColors.acc, width: 1.5)),
      ),
    );
  }
}
