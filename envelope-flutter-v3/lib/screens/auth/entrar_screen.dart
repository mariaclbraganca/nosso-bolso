import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/auth_provider.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../../ui/unicorn/unicorn.dart';
import '../sheets/comum.dart';

enum _Modo { entrar, criar }

class EntrarScreen extends ConsumerStatefulWidget {
  const EntrarScreen({super.key});

  @override
  ConsumerState<EntrarScreen> createState() => _EntrarScreenState();
}

class _EntrarScreenState extends ConsumerState<EntrarScreen> {
  _Modo _modo = _Modo.entrar;
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _ocultar = true;
  bool _ocupado = false;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  String _traduzir(Object e) {
    final m = e is AuthException ? e.message.toLowerCase() : e.toString().toLowerCase();
    if (m.contains('invalid login')) return 'E-mail ou senha não conferem.';
    if (m.contains('already registered')) return 'Esse e-mail já tem conta. Use Entrar.';
    if (m.contains('password should be')) return 'A senha precisa de pelo menos 6 caracteres.';
    if (m.contains('cancel')) return 'Login com Google cancelado.';
    return mensagemErro(e);
  }

  Future<void> _rodar(Future<void> Function() acao) async {
    setState(() => _ocupado = true);
    try {
      await acao();
    } catch (e) {
      avisar(_traduzir(e), erro: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _enviar() {
    final auth = ref.read(authServiceProvider);
    final email = _email.text.trim();
    final senha = _senha.text;
    if (email.isEmpty || senha.isEmpty) return avisar('Preencha e-mail e senha.', erro: true);
    if (_modo == _Modo.criar) {
      if (_nome.text.trim().isEmpty) return avisar('Diga seu nome para a família te reconhecer.', erro: true);
      _rodar(() async {
        await auth.signUpWithEmail(email, senha, _nome.text.trim());
        avisar('Conta criada. Se pedir confirmação, veja seu e-mail.');
      });
    } else {
      _rodar(() => auth.signInWithEmail(email, senha));
    }
  }

  void _esqueci() {
    final email = _email.text.trim();
    if (email.isEmpty) return avisar('Digite seu e-mail acima primeiro.', erro: true);
    _rodar(() async {
      await ref.read(authServiceProvider).recoverPassword(email);
      avisar('Mandamos um link para $email.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final criar = _modo == _Modo.criar;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(NBSpacing.xxl, NBSpacing.x3, NBSpacing.xxl, NBSpacing.xxl),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const UnicornWidget(type: UnicornType.astrix, size: 96, mood: UnicornMood.wave),
                const SizedBox(width: NBSpacing.s),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: UnicornFala(
                      type: UnicornType.astrix,
                      texto: criar ? 'Bem-vindo! Vamos montar os envelopes da família.' : 'Oi de novo! Seus envelopes estão te esperando.',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NBSpacing.xxl),
            Text('Nosso Bolso', style: NBText.saldo.copyWith(fontSize: 40, color: NBColors.verde)),
            const SizedBox(height: 4),
            Text('O dinheiro da família, em envelopes.', style: NBText.corpo.copyWith(color: NBColors.tintaSuave)),
            const SizedBox(height: NBSpacing.xxl),
            Segmentado<_Modo>(
              opcoes: const {_Modo.entrar: 'Entrar', _Modo.criar: 'Criar conta'},
              valor: _modo,
              onChanged: (m) => setState(() => _modo = m),
            ),
            const SizedBox(height: NBSpacing.xl),
            if (criar) ...[
              TextField(
                controller: _nome,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Seu nome'),
              ),
              const SizedBox(height: NBSpacing.m),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            const SizedBox(height: NBSpacing.m),
            TextField(
              controller: _senha,
              obscureText: _ocultar,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _enviar(),
              decoration: InputDecoration(
                labelText: 'Senha',
                suffixIcon: IconButton(
                  tooltip: _ocultar ? 'Mostrar senha' : 'Ocultar senha',
                  icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _ocultar = !_ocultar),
                ),
              ),
            ),
            if (!criar)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _ocupado ? null : _esqueci, child: const Text('Esqueci a senha')),
              ),
            const SizedBox(height: NBSpacing.l),
            BotaoPrincipal(rotulo: criar ? 'Criar conta' : 'Entrar', carregando: _ocupado, onPressed: _enviar),
            const SizedBox(height: NBSpacing.m),
            OutlinedButton.icon(
              onPressed: _ocupado ? null : () => _rodar(() => ref.read(authServiceProvider).signInWithGoogle()),
              icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
              label: const Text('Continuar com Google'),
            ),
          ],
        ),
      ),
    );
  }
}
