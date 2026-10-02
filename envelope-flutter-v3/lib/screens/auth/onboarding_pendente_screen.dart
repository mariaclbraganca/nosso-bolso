import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nosso_bolso_v3/core/constants.dart';
import 'package:nosso_bolso_v3/core/providers/auth_provider.dart';
import 'package:nosso_bolso_v3/core/providers/usuarios_provider.dart';
import 'package:nosso_bolso_v3/screens/sheets/comum.dart';
import 'package:nosso_bolso_v3/ui/components/nb_components.dart';
import 'package:nosso_bolso_v3/ui/theme/nb_theme.dart';
import 'package:nosso_bolso_v3/ui/unicorn/unicorn.dart';

enum _ModoOnboarding { criar, entrar }

class OnboardingPendenteScreen extends ConsumerStatefulWidget {
  const OnboardingPendenteScreen({super.key});

  @override
  ConsumerState<OnboardingPendenteScreen> createState() =>
      _OnboardingPendenteScreenState();
}

class _OnboardingPendenteScreenState
    extends ConsumerState<OnboardingPendenteScreen> {
  _ModoOnboarding _modo = _ModoOnboarding.criar;
  final _nomeFamiliaCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  bool _ocupado = false;

  @override
  void dispose() {
    _nomeFamiliaCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _criarFamilia() async {
    final nome = _nomeFamiliaCtrl.text.trim();
    if (nome.isEmpty) {
      avisar('Informe o nome da família', erro: true);
      return;
    }
    setState(() => _ocupado = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final familyRes = await supabase
          .from('familias')
          .insert({'nome': nome})
          .select('id, codigo_acesso')
          .single();

      final familyId = familyRes['id'] as String;

      await supabase.from('usuarios').upsert({
        'id': user.id,
        'email': user.email,
        'nome': user.userMetadata?['nome'] ?? user.email?.split('@')[0] ?? 'Eu',
        'familia_id': familyId,
        'role': 'admin',
      });

      await supabase.from('envelopes').insert([
        {'familia_id': familyId, 'nome_envelope': 'Alimentação & Mercado', 'valor_planejado': 1200.0, 'natureza': 'consumo'},
        {'familia_id': familyId, 'nome_envelope': 'Casa & Contas', 'valor_planejado': 1000.0, 'natureza': 'consumo'},
        {'familia_id': familyId, 'nome_envelope': 'Transporte', 'valor_planejado': 400.0, 'natureza': 'consumo'},
        {'familia_id': familyId, 'nome_envelope': 'Lazer', 'valor_planejado': 300.0, 'natureza': 'consumo'},
        {'familia_id': familyId, 'nome_envelope': 'Reserva de Emergência', 'valor_planejado': 500.0, 'natureza': 'reserva'},
      ]);

      ref.read(perfilUsuarioLogadoProvider.notifier).recarregar();
      avisar('Família criada com sucesso! Bem-vindo!');
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _entrarComCodigo() async {
    final code = _codigoCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      avisar('Digite o código de acesso da família', erro: true);
      return;
    }
    setState(() => _ocupado = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final familyRes = await supabase
          .from('familias')
          .select('id')
          .eq('codigo_acesso', code)
          .maybeSingle();

      if (familyRes == null) {
        throw Exception('Código de família não encontrado.');
      }

      final familyId = familyRes['id'] as String;

      await supabase.from('usuarios').upsert({
        'id': user.id,
        'email': user.email,
        'nome': user.userMetadata?['nome'] ?? user.email?.split('@')[0] ?? 'Eu',
        'familia_id': familyId,
      });

      ref.read(perfilUsuarioLogadoProvider.notifier).recarregar();
      avisar('Você entrou na família com sucesso! 🎉');
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final criar = _modo == _ModoOnboarding.criar;

    return Scaffold(
      backgroundColor: NBColors.papel,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const Center(
              child: UnicornWidget(
                type: UnicornType.astrix,
                size: 110,
                mood: UnicornMood.wave,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Vamos organizar as contas?',
              style: NBText.tituloTela,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Você pode criar um espaço novo para sua família ou entrar em um já existente.',
              style: NBText.legenda,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Segmentado<_ModoOnboarding>(
              opcoes: const {
                _ModoOnboarding.criar: 'Criar Família',
                _ModoOnboarding.entrar: 'Tenho um Código',
              },
              valor: _modo,
              onChanged: (m) => setState(() => _modo = m),
            ),
            const SizedBox(height: 20),
            if (criar) ...[
              TextField(
                controller: _nomeFamiliaCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nome da família',
                  hintText: 'Ex: Família Silva',
                  filled: true,
                  fillColor: NBColors.cartao,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(NBRadius.campo),
                    borderSide: const BorderSide(color: NBColors.linha),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              BotaoPrincipal(
                rotulo: 'Criar Família e Iniciar',
                carregando: _ocupado,
                onPressed: _criarFamilia,
              ),
            ] else ...[
              TextField(
                controller: _codigoCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Código de acesso',
                  hintText: 'Ex: AB12CD',
                  filled: true,
                  fillColor: NBColors.cartao,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(NBRadius.campo),
                    borderSide: const BorderSide(color: NBColors.linha),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              BotaoPrincipal(
                rotulo: 'Entrar na Família',
                carregando: _ocupado,
                onPressed: _entrarComCodigo,
              ),
            ],
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => ref.read(authServiceProvider).signOut(),
                child: const Text(
                  'Sair da conta',
                  style: TextStyle(color: NBColors.estouro),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
