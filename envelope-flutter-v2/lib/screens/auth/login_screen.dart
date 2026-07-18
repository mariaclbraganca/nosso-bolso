import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading       = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleEmailLogin() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) { _showError('Preencha email e senha'); return; }

    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithEmail(email, password);
    } catch (e) {
      if (mounted) _showError('Erro ao entrar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleGoogleLogin() async {
    setState(() => _isGoogleLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) _showError('Erro ao entrar com Google: $e');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) { _showError('Digite seu email para recuperar a senha'); return; }
    try {
      await ref.read(authServiceProvider).recoverPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email de recuperação enviado!'), backgroundColor: AppColors.grn),
        );
      }
    } catch (e) {
      if (mounted) _showError('Erro ao recuperar senha: $e');
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
          Positioned(top: -100, right: -100, child: _glow(AppColors.acc.withOpacity(0.12), 300)),
          Positioned(bottom: -50, left: -50,  child: _glow(AppColors.acc.withOpacity(0.08), 250)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePad),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 60, color: AppColors.acc),
                    const SizedBox(height: 16),
                    Text(
                      'NOSSO BOLSO',
                      style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2, color: AppColors.tx),
                    ),
                    const SizedBox(height: 8),
                    Text('Finanças familiares inteligentes', style: AppTextStyles.caption),
                    const SizedBox(height: 48),

                    // Card de login
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.bord),
                      ),
                      child: Column(
                        children: [
                          _field(_emailController,    'Email',  Icons.email_outlined,  false, key: const Key('campo_email')),
                          const SizedBox(height: 16),
                          _field(_passwordController, 'Senha',  Icons.lock_outline,    true,  key: const Key('campo_senha')),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _handleForgotPassword,
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                              child: Text('Esqueci minha senha', style: AppTextStyles.caption.copyWith(color: AppColors.acc)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            key: const Key('btn_entrar'),
                            onPressed: _isLoading ? null : _handleEmailLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.acc,
                              foregroundColor: AppColors.bg,
                              minimumSize: const Size.fromHeight(56),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                                : const Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppColors.bord)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('OU', style: AppTextStyles.caption),
                        ),
                        const Expanded(child: Divider(color: AppColors.bord)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    OutlinedButton(
                      onPressed: _isGoogleLoading ? null : _handleGoogleLogin,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.bord),
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                        backgroundColor: AppColors.card,
                      ),
                      child: _isGoogleLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.tx))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                                  height: 20,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.login, color: AppColors.tx, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Text('Entrar com Google', style: AppTextStyles.body),
                              ],
                            ),
                    ),

                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Novo por aqui? ', style: AppTextStyles.caption),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
                          child: Text('Criar conta', style: AppTextStyles.caption.copyWith(color: AppColors.acc, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text('Nosso Bolso v2', style: AppTextStyles.caption.copyWith(fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(Color color, double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: size, spreadRadius: size / 2)]),
  );

  Widget _field(TextEditingController ctrl, String label, IconData icon, bool obscure, {Key? key}) {
    return TextField(
      key: key,
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
