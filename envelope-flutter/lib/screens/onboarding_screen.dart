import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/usuarios_provider.dart';
import '../constants.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _familyController = TextEditingController();
  final _codeController = TextEditingController();
  final _saldoController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _familyController.dispose();
    _codeController.dispose();
    _saldoController.dispose();
    super.dispose();
  }

  void _createFamily() async {
    final name = _familyController.text.trim();
    final saldoInicial = double.tryParse(_saldoController.text.replaceAll(',', '.')) ?? 0.0;
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw 'Usuário não logado';

      // 1. Criar a família
      final familyRes = await supabase
          .from('familias')
          .insert({'nome': name})
          .select('id, codigo_acesso')
          .single();
          
      final familyId = familyRes['id'];
      final accessCode = familyRes['codigo_acesso'] as String? ?? '---';

      // 2. Vincular o usuário como admin (SPEC-15) - Self-Healing (Upsert v2.4)
      final updatedUser = await supabase.from('usuarios').upsert({
        'id': user.id,
        'email': user.email,
        'nome': user.userMetadata?['nome'] ?? user.email?.split('@')[0] ?? 'Usuário',
        'familia_id': familyId,
        'role': 'admin'
      }).select('*, familias(*)').single();

      // Injeção otimista de estado
      ref.read(perfilUsuarioLogadoProvider.notifier).atualizarEstado(updatedUser);

      // 3. Criar envelopes base (SPEC-10)
      final baseEnvs = [
        {'nome_envelope': 'Alimentação', 'emoji': '🥗', 'valor_planejado': 0.0, 'familia_id': familyId},
        {'nome_envelope': 'Casa', 'emoji': '🏠', 'valor_planejado': 0.0, 'familia_id': familyId},
        {'nome_envelope': 'Lazer', 'emoji': '🎉', 'valor_planejado': 0.0, 'familia_id': familyId},
      ];
      await supabase.from('envelopes').insert(baseEnvs);

      // 4. Registrar saldo inicial como receita (SPEC-10)
      if (saldoInicial > 0) {
        await supabase.from('transacoes').insert({
          'familia_id': familyId,
          'usuario_id': user.id,
          'descricao': 'Aporte Inicial — Onboarding',
          'valor': saldoInicial,
          'tipo': 'receita',
        });
      }

      if (mounted) {
        await _showSuccessDialog(accessCode);
      }
    } catch (e) {
      if (mounted) _showError('Erro ao criar família: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccessDialog(String code) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Família Criada! 🎉', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sua família está pronta. Compartilhe este código com quem vai usar o app com você:',
              style: TextStyle(color: AppColors.mu, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.acc.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.acc.withOpacity(0.3)),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(color: AppColors.acc, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Código copiado!')));
            },
            child: const Text('COPIAR CÓDIGO', style: TextStyle(color: AppColors.acc, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.acc),
            child: const Text('COMEÇAR', style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _joinFamily() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw 'Usuário não logado';

      // 1. Buscar a família pelo código
      final familyRes = await supabase.from('familias').select('id').eq('codigo_acesso', code).maybeSingle();
      if (familyRes == null) {
        throw 'Código de família inválido ou não encontrado.';
      }

      final familyId = familyRes['id'];

      // 2. Vincular o usuário - Self-Healing (Upsert v2.4)
      final updatedUser = await supabase
          .from('usuarios')
          .upsert({
            'id': user.id,
            'email': user.email,
            'nome': user.userMetadata?['nome'] ?? user.email?.split('@')[0] ?? 'Usuário',
            'familia_id': familyId,
          })
          .select('*, familias(*)')
          .single();

      // 3. Atualizar e prosseguir (Optimistic v2.4)
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
                colors: [Color(0xFF0D1117), Color(0xFF161B22), Color(0xFF0D1117)],
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Para começar, você precisa de uma família.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mu, fontSize: 13),
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
                    extraHint: 'Saldo inicial (R\$) — opcional',
                  ),

                  const SizedBox(height: 24),
                  const Text('OU', style: TextStyle(color: AppColors.mu, fontSize: 11, fontWeight: FontWeight.bold)),
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
                    child: const Text('Sair da conta', style: TextStyle(color: AppColors.mu, fontSize: 13)),
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
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
          Text(subtitle, style: const TextStyle(color: AppColors.mu, fontSize: 12)),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.mu, fontSize: 12),
              filled: true,
              fillColor: Colors.white.withOpacity(0.02),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.acc, width: 1)),
            ),
          ),
          if (extraController != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: extraController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: extraHint,
                hintStyle: const TextStyle(color: AppColors.mu, fontSize: 12),
                filled: true,
                fillColor: Colors.white.withOpacity(0.02),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.acc, width: 1)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.acc,
              foregroundColor: AppColors.bg,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(btnText, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
