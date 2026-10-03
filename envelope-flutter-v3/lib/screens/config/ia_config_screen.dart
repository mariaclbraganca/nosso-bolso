import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/usuarios_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/services/gemini_key_service.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../sheets/comum.dart';

/// Até 3 chaves Gemini. O app usa a primeira e passa para a próxima quando a
/// cota acaba (GeminiKeyService). A primeira também vai para o servidor.
class IaConfigScreen extends ConsumerStatefulWidget {
  const IaConfigScreen({super.key});

  @override
  ConsumerState<IaConfigScreen> createState() => _IaConfigScreenState();
}

class _IaConfigScreenState extends ConsumerState<IaConfigScreen> {
  final _ctrls = List.generate(3, (_) => TextEditingController());
  final _visivel = [false, false, false];
  bool _carregado = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    GeminiKeyService.carregarChavesSalvas().then((salvas) {
      if (!mounted) return;
      for (var i = 0; i < 3; i++) {
        _ctrls[i].text = i < salvas.length ? salvas[i] : '';
      }
      setState(() => _carregado = true);
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _chaves => _ctrls.map((c) => c.text.trim()).toList();

  Future<void> _salvar() async {
    final chaves = _chaves;
    if (chaves.every((c) => c.isEmpty)) return avisar('Preencha ao menos uma chave.', erro: true);
    setState(() => _salvando = true);
    try {
      for (var i = 0; i < chaves.length; i++) {
        if (chaves[i].isNotEmpty && !await GeminiKeyService.validarChave(chaves[i])) {
          return avisar('A chave ${i + 1} foi recusada pelo Gemini. Confira e tente de novo.', erro: true);
        }
      }
      await GeminiKeyService.salvarChaves(chaves);
      final principal = chaves.firstWhere((c) => c.isNotEmpty);
      final familiaId = ref.read(perfilUsuarioLogadoProvider).valueOrNull?['familia_id'];
      await ApiService.post('/api/v1/configurar', {'gemini_api_key': principal, 'familia_id': familiaId});
      final ativas = chaves.where((c) => c.isNotEmpty).length;
      avisar('$ativas ${ativas == 1 ? 'chave salva' : 'chaves salvas'}.');
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _remover(int i) async {
    _ctrls[i].clear();
    await GeminiKeyService.salvarChaves(_chaves);
    setState(() {});
    avisar('Chave ${i + 1} removida deste celular.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inteligência artificial')),
      body: !_carregado
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
              children: [
                const PainelIA(
                  titulo: 'Onde a IA trabalha',
                  texto: 'Lê notas fiscais, entende notificações que o padrão não reconhece, '
                      'sugere listas de compras, analisa refeições e gera os insights do Astrix.',
                ),
                const SizedBox(height: NBSpacing.xl),
                Text('CHAVES DO GEMINI', style: NBText.eyebrow),
                const SizedBox(height: 4),
                Text(
                  'Use até três. Quando a cota de uma acaba, o app passa para a próxima.',
                  style: NBText.legenda,
                ),
                const SizedBox(height: NBSpacing.m),
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: NBSpacing.m),
                    child: TextField(
                      controller: _ctrls[i],
                      obscureText: !_visivel[i],
                      autocorrect: false,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: i == 0 ? 'Chave principal' : 'Chave reserva $i',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: _visivel[i] ? 'Ocultar' : 'Mostrar',
                              icon: Icon(_visivel[i] ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => setState(() => _visivel[i] = !_visivel[i]),
                            ),
                            if (_ctrls[i].text.isNotEmpty)
                              IconButton(
                                tooltip: 'Remover',
                                icon: const Icon(Icons.delete_outline_rounded, color: NBColors.estouro),
                                onPressed: () => _remover(i),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                BotaoPrincipal(rotulo: 'Validar e salvar', carregando: _salvando, onPressed: _salvar),
                const SizedBox(height: NBSpacing.xl),
                CartaoNB(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Como conseguir uma chave', style: NBText.rotulo),
                      const SizedBox(height: NBSpacing.s),
                      for (final passo in const [
                        '1. Abra aistudio.google.com no navegador',
                        '2. Entre com a sua conta Google',
                        '3. Toque em "Get API key" e crie uma chave',
                        '4. Copie e cole num dos campos acima',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: SelectableText(passo, style: NBText.corpo.copyWith(fontSize: 14)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
