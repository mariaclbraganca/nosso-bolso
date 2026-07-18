import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../providers/usuarios_provider.dart';
import '../../constants.dart';
import '../../services/gemini_key_service.dart';

class ConfiguracaoIAScreen extends ConsumerStatefulWidget {
  const ConfiguracaoIAScreen({super.key});

  @override
  ConsumerState<ConfiguracaoIAScreen> createState() =>
      _ConfiguracaoIAScreenState();
}

class _ConfiguracaoIAScreenState
    extends ConsumerState<ConfiguracaoIAScreen> {
  final _ctrls = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  final _obscuros = [true, true, true];
  bool _salvando = false;
  int _chavesAtivas = 0;

  @override
  void initState() {
    super.initState();
    _carregarSalvos();
  }

  Future<void> _carregarSalvos() async {
    final salvas = await GeminiKeyService.carregarChavesSalvas();
    if (!mounted) return;
    int ativas = 0;
    for (var i = 0; i < 3; i++) {
      _ctrls[i].text = salvas[i];
      if (salvas[i].isNotEmpty) ativas++;
    }
    setState(() => _chavesAtivas = ativas);
  }

  Future<void> _salvar() async {
    final novas = _ctrls.map((c) => c.text.trim()).toList();
    if (novas.every((v) => v.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Preencha ao menos uma chave antes de salvar.'),
        backgroundColor: AppColors.org,
      ));
      return;
    }

    setState(() => _salvando = true);
    try {
      await GeminiKeyService.salvarChaves(novas);

      // Persiste também no Supabase
      final perfil = ref.read(perfilUsuarioLogadoProvider).asData?.value;
      final familiaId = perfil?['familia_id'] as String?;
      if (familiaId != null) {
        await supabase.from('configuracoes_app').upsert({
          'familia_id': familiaId,
          'gemini_api_key': novas[0].isNotEmpty ? novas[0] : null,
          'gemini_key_2': novas[1].isNotEmpty ? novas[1] : null,
          'gemini_key_3': novas[2].isNotEmpty ? novas[2] : null,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'familia_id');
      }

      if (mounted) {
        final ativas = novas.where((v) => v.isNotEmpty).length;
        setState(() => _chavesAtivas = ativas);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$ativas chave(s) Gemini salva(s) com sucesso!'),
          backgroundColor: AppColors.grn,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: AppColors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _removerChave(int index) async {
    _ctrls[index].clear();
    final novas = _ctrls.map((c) => c.text.trim()).toList();
    await GeminiKeyService.salvarChaves(novas);
    final ativas = novas.where((v) => v.isNotEmpty).length;
    if (mounted) {
      setState(() => _chavesAtivas = ativas);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Chave ${index + 1} removida.'),
        backgroundColor: AppColors.org,
      ));
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Configuração de IA', style: AppTextStyles.titleSm),
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.mu, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePad),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Status banner ────────────────────────────────────────────────────
          _StatusBanner(chavesAtivas: _chavesAtivas),

          const SizedBox(height: AppSpacing.sectionGap),

          // ── Card explicativo ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: AppColors.bord, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('🤖', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text('Como a IA é usada no app',
                      style: AppTextStyles.bodySm
                          .copyWith(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 10),
                _DicaItem(
                  emoji: '🔄',
                  texto:
                      'Rotação automática: quando uma chave esgota a cota, o app passa automaticamente para a próxima.',
                ),
                const SizedBox(height: 6),
                _DicaItem(
                  emoji: '🧾',
                  texto:
                      'Leitura de NFC-e: ao escanear um QR code de nota fiscal, o Gemini extrai automaticamente os itens e valores.',
                ),
                const SizedBox(height: 6),
                _DicaItem(
                  emoji: '📊',
                  texto:
                      'Monitor IA: análise diária de gastos, padrões de consumo e projeção do mês.',
                ),
                const SizedBox(height: 6),
                _DicaItem(
                  emoji: '💰',
                  texto:
                      'Patrimônio IA: análise inteligente das suas contas e sugestões de realocação.',
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          // ── Campos das 3 chaves ──────────────────────────────────────────────
          for (var i = 0; i < 3; i++) ...[
            _CampoChave(
              indice: i,
              ctrl: _ctrls[i],
              obscuro: _obscuros[i],
              onToggleObscuro: () => setState(() => _obscuros[i] = !_obscuros[i]),
              onRemover: _ctrls[i].text.isNotEmpty
                  ? () => _removerChave(i)
                  : null,
            ),
            if (i < 2) const SizedBox(height: 12),
          ],

          const SizedBox(height: 8),
          const Text(
            'Adicione até 3 chaves gratuitas do Google AI Studio. '
            'O app usa a primeira disponível e troca automaticamente quando uma esgota.',
            style: TextStyle(color: AppColors.mu, fontSize: 11, height: 1.4),
          ),

          const SizedBox(height: 32),

          // ── Botão Salvar ─────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.acc,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusBtn)),
              ),
              icon: _salvando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.save_rounded, color: Colors.black),
              label: Text(
                _salvando ? 'Salvando…' : 'Salvar chaves',
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
              onPressed: _salvando ? null : _salvar,
            ),
          ),

          const SizedBox(height: 12),

          // ── Link Google AI Studio ─────────────────────────────────────────────
          Center(
            child: TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://aistudio.google.com'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new,
                  color: AppColors.acc, size: 14),
              label: const Text(
                'Obter chave no Google AI Studio',
                style: TextStyle(color: AppColors.acc, fontSize: 12),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          // ── Instrução ─────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: AppColors.bord, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.tips_and_updates_outlined,
                      color: AppColors.mu, size: 16),
                  const SizedBox(width: 6),
                  Text('Como obter sua chave',
                      style: AppTextStyles.bodySm
                          .copyWith(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 10),
                const Text('1. Acesse aistudio.google.com',
                    style: TextStyle(color: AppColors.mu, fontSize: 12)),
                const Text('2. Faça login com sua conta Google',
                    style: TextStyle(color: AppColors.mu, fontSize: 12)),
                const Text(
                    '3. Clique em "Get API key" → "Create API key"',
                    style: TextStyle(color: AppColors.mu, fontSize: 12)),
                const Text('4. Copie e cole em um dos campos acima',
                    style: TextStyle(color: AppColors.mu, fontSize: 12)),
                const SizedBox(height: 8),
                const Text(
                  'Repita com contas Google diferentes para ter 3 chaves gratuitas independentes.',
                  style: TextStyle(
                      color: AppColors.mu, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final int chavesAtivas;
  const _StatusBanner({required this.chavesAtivas});

  @override
  Widget build(BuildContext context) {
    final ok = chavesAtivas > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok
            ? AppColors.acc.withOpacity(0.08)
            : AppColors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(
          color: ok
              ? AppColors.acc.withOpacity(0.3)
              : AppColors.red.withOpacity(0.3),
        ),
      ),
      child: Row(children: [
        Icon(
          ok ? Icons.check_circle : Icons.warning_amber_rounded,
          color: ok ? AppColors.acc : AppColors.red,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ok
                    ? '$chavesAtivas chave(s) configurada(s) ✓'
                    : 'Nenhuma chave configurada',
                style: TextStyle(
                  color: ok ? AppColors.acc : AppColors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                ok
                    ? 'O app rotaciona automaticamente quando uma chave esgota.'
                    : 'Configure ao menos uma chave para usar a IA.',
                style: const TextStyle(color: AppColors.mu, fontSize: 11),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _CampoChave extends StatelessWidget {
  final int indice;
  final TextEditingController ctrl;
  final bool obscuro;
  final VoidCallback onToggleObscuro;
  final VoidCallback? onRemover;

  const _CampoChave({
    required this.indice,
    required this.ctrl,
    required this.obscuro,
    required this.onToggleObscuro,
    this.onRemover,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.acc.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${indice + 1}',
              style: const TextStyle(
                  color: AppColors.acc,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Chave Gemini ${indice + 1}${indice == 0 ? " (principal)" : " (backup)"}',
            style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (ctrl.text.isNotEmpty)
            const Icon(Icons.check_circle, color: AppColors.grn, size: 14),
        ]),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
            border: Border.all(color: AppColors.bord),
          ),
          child: TextField(
            controller: ctrl,
            obscureText: obscuro,
            style: AppTextStyles.bodySm,
            decoration: InputDecoration(
              hintText: 'AIza...',
              hintStyle: const TextStyle(color: AppColors.mu, fontSize: 12),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      obscuro ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.mu,
                      size: 18,
                    ),
                    onPressed: onToggleObscuro,
                  ),
                  if (onRemover != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.red, size: 18),
                      onPressed: onRemover,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DicaItem extends StatelessWidget {
  final String emoji;
  final String texto;
  const _DicaItem({required this.emoji, required this.texto});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                  color: AppColors.mu, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      );
}
