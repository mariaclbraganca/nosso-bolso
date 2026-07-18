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
  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    final name     = _nameController.text.trim();
    final email    = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) { _showError('Preencha todos os campos'); return; }
    if (password.length < 6) { _showError('A senha deve ter pelo menos 6 caracteres'); return; }

    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signUpWithEmail(email, password, name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conta criada! Verifique seu email se necessário.'), backgroundColor: AppColors.grn),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showError('Erro ao cadastrar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.red),
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
                  const SizedBox(height: 60),
                  const Icon(Icons.person_add_outlined, size: 60, color: AppColors.acc),
                  const SizedBox(height: 16),
                  Text(
                    'CRIAR CONTA',
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2, color: AppColors.tx),
                  ),
                  const SizedBox(height: 8),
                  Text('Comece sua jornada financeira hoje', style: AppTextStyles.caption),
                  const SizedBox(height: 48),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.bord),
                    ),
                    child: Column(
                      children: [
                        _field(_nameController,     'Seu Nome',             Icons.person_outline,  false),
                        const SizedBox(height: 16),
                        _field(_emailController,    'Email',                Icons.email_outlined,  false),
                        const SizedBox(height: 16),
                        _field(_passwordController, 'Senha (mín. 6 chars)', Icons.lock_outline,    true),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.acc,
                            foregroundColor: AppColors.bg,
                            minimumSize: const Size.fromHeight(56),
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

                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Já tem conta? Entrar agora', style: AppTextStyles.body.copyWith(color: AppColors.mu)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, bool obscure) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.caption,
        prefixIcon: Icon(icon, color: AppColors.mu, size: 20),
        filled: true,
        fillColor: AppColors.surf,
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn), borderSide: const BorderSide(color: AppColors.bord)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn), borderSide: const BorderSide(color: AppColors.bord)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn), borderSide: const BorderSide(color: AppColors.acc, width: 1.5)),
      ),
    );
  }
}
