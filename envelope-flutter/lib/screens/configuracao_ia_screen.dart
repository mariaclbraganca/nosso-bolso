import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../providers/envelopes_provider.dart';
import '../providers/usuarios_provider.dart';

class ConfiguracaoIAScreen extends ConsumerStatefulWidget {
  const ConfiguracaoIAScreen({super.key});

  @override
  ConsumerState<ConfiguracaoIAScreen> createState() =>
      _ConfiguracaoIAScreenState();
}

class _ConfiguracaoIAScreenState extends ConsumerState<ConfiguracaoIAScreen> {
  final _geminiCtrl = TextEditingController();
  final _mongoCtrl = TextEditingController();
  bool _geminiObscuro = true;
  bool _mongoObscuro = true;
  bool _salvando = false;
  bool? _geminiOk;
  bool? _mongoOk;
  String? _envelopeMercadoId;
  bool _salvandoEnvelope = false;

  static const _kGemini = 'ia_gemini_api_key';
  static const _kMongo = 'ia_mongo_uri';

  @override
  void initState() {
    super.initState();
    _carregarSalvos();
    _carregarPerfilIA();
  }

  Future<void> _carregarPerfilIA() async {
    final perfil = ref.read(perfilUsuarioLogadoProvider).asData?.value;
    final familiaId = perfil?['familia_id'] as String?;
    if (familiaId == null) return;
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/v1/compras/perfil')
          .replace(queryParameters: {'familia_id': familiaId});
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _envelopeMercadoId = data['envelope_supermercado_id'] as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _salvarEnvelopeMercado(String? envelopeId) async {
    final perfil = ref.read(perfilUsuarioLogadoProvider).asData?.value;
    final familiaId = perfil?['familia_id'] as String?;
    if (familiaId == null || envelopeId == null) return;
    setState(() => _salvandoEnvelope = true);
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/v1/compras/perfil');
      final resp = await http.patch(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'familia_id': familiaId,
            'envelope_supermercado_id': envelopeId,
          }));
      if (resp.statusCode == 200 && mounted) {
        setState(() => _envelopeMercadoId = envelopeId);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Envelope de compras atualizado'),
          backgroundColor: AppColors.grn,
        ));
      } else {
        throw Exception(resp.body);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _salvandoEnvelope = false);
    }
  }

  Future<void> _carregarSalvos() async {
    final prefs = await SharedPreferences.getInstance();
    _geminiCtrl.text = prefs.getString(_kGemini) ?? '';
    _mongoCtrl.text = prefs.getString(_kMongo) ?? '';
    await _verificarStatus();
  }

  Future<void> _verificarStatus() async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/v1/configurar');
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (mounted) {
          setState(() {
            _geminiOk = data['gemini_api_key_configurada'] as bool? ?? false;
            _mongoOk = data['mongo_uri_configurada'] as bool? ?? false;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _salvar() async {
    final gemini = _geminiCtrl.text.trim();
    final mongo = _mongoCtrl.text.trim();

    if (gemini.isEmpty && mongo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Preencha ao menos um campo antes de salvar.'),
        backgroundColor: AppColors.org,
      ));
      return;
    }

    setState(() => _salvando = true);
    try {
      // 1. Salva localmente
      final prefs = await SharedPreferences.getInstance();
      if (gemini.isNotEmpty) await prefs.setString(_kGemini, gemini);
      if (mongo.isNotEmpty) await prefs.setString(_kMongo, mongo);

      // 2. Envia para o backend
      final uri = Uri.parse('${ApiService.baseUrl}/api/v1/configurar');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'gemini_api_key': gemini,
          'mongo_uri': mongo,
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          _geminiOk = data['gemini_api_key_configurada'] as bool? ?? false;
          _mongoOk = data['mongo_uri_configurada'] as bool? ?? false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Configurações aplicadas com sucesso!'),
            backgroundColor: AppColors.grn,
          ));
        }
      } else {
        throw Exception(resp.body);
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

  @override
  void dispose() {
    _geminiCtrl.dispose();
    _mongoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Configurações de IA')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _StatusBanner(geminiOk: _geminiOk, mongoOk: _mongoOk),
          const SizedBox(height: 28),

          // ── Gemini API Key ──────────────────────────────────────────
          _SectionTitle(
            icon: Icons.auto_awesome,
            label: 'Google Gemini API Key',
            ok: _geminiOk,
          ),
          const SizedBox(height: 4),
          const Text(
            'Obtida em aistudio.google.com → "Get API key"',
            style: TextStyle(color: AppColors.mu, fontSize: 11),
          ),
          const SizedBox(height: 10),
          _CampoChave(
            controller: _geminiCtrl,
            hint: 'AIza...',
            obscuro: _geminiObscuro,
            onToggle: () => setState(() => _geminiObscuro = !_geminiObscuro),
          ),

          const SizedBox(height: 32),

          // ── Envelope de Compras (alvo do agente de planejamento) ────
          _SectionTitle(
            icon: Icons.shopping_basket_outlined,
            label: 'Envelope de Compras',
            ok: _envelopeMercadoId != null ? true : null,
          ),
          const SizedBox(height: 4),
          const Text(
            'O agente de IA usa o saldo deste envelope para sugerir compras.',
            style: TextStyle(color: AppColors.mu, fontSize: 11),
          ),
          const SizedBox(height: 10),
          _DropdownEnvelope(
            envelopeId: _envelopeMercadoId,
            salvando: _salvandoEnvelope,
            onChanged: _salvarEnvelopeMercado,
          ),

          const SizedBox(height: 32),

          // ── MongoDB URI ─────────────────────────────────────────────
          _SectionTitle(
            icon: Icons.storage_rounded,
            label: 'MongoDB URI',
            ok: _mongoOk,
          ),
          const SizedBox(height: 4),
          const Text(
            'Ex: mongodb://localhost:27017  ou  mongodb+srv://user:pass@cluster.mongodb.net',
            style: TextStyle(color: AppColors.mu, fontSize: 11),
          ),
          const SizedBox(height: 10),
          _CampoChave(
            controller: _mongoCtrl,
            hint: 'mongodb://localhost:27017',
            obscuro: _mongoObscuro,
            onToggle: () => setState(() => _mongoObscuro = !_mongoObscuro),
          ),

          const SizedBox(height: 40),

          // ── Botão Salvar ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.acc,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
                _salvando ? 'Aplicando…' : 'Salvar e Aplicar',
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
              onPressed: _salvando ? null : _salvar,
            ),
          ),

          const SizedBox(height: 16),

          // ── Botão Verificar ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.bord),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh, color: AppColors.mu, size: 18),
              label: const Text('Verificar Status',
                  style: TextStyle(color: AppColors.mu)),
              onPressed: _verificarStatus,
            ),
          ),

          const SizedBox(height: 32),
          _DicaCard(),
        ]),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final bool? geminiOk;
  final bool? mongoOk;
  const _StatusBanner({required this.geminiOk, required this.mongoOk});

  @override
  Widget build(BuildContext context) {
    final ambosOk = (geminiOk ?? false) && (mongoOk ?? false);
    final algumConfig = (geminiOk ?? false) || (mongoOk ?? false);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ambosOk
            ? AppColors.acc.withAlpha(25)
            : algumConfig
                ? AppColors.org.withAlpha(25)
                : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ambosOk
              ? AppColors.acc.withAlpha(80)
              : algumConfig
                  ? AppColors.org.withAlpha(80)
                  : AppColors.bord,
        ),
      ),
      child: Row(children: [
        Icon(
          ambosOk
              ? Icons.check_circle
              : algumConfig
                  ? Icons.warning_amber_rounded
                  : Icons.radio_button_unchecked,
          color: ambosOk
              ? AppColors.acc
              : algumConfig
                  ? AppColors.org
                  : AppColors.mu,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            ambosOk
                ? 'IA configurada e pronta para uso'
                : algumConfig
                    ? 'Configuração parcial — complete os campos faltantes'
                    : 'Nenhuma chave configurada ainda',
            style: TextStyle(
              color: ambosOk
                  ? AppColors.acc
                  : algumConfig
                      ? AppColors.org
                      : AppColors.mu,
              fontSize: 13,
            ),
          ),
        ),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool? ok;
  const _SectionTitle({required this.icon, required this.label, this.ok});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppColors.acc, size: 18),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              color: AppColors.tx,
              fontSize: 14,
              fontWeight: FontWeight.w600)),
      const Spacer(),
      if (ok != null)
        Icon(
          ok! ? Icons.check_circle : Icons.cancel,
          color: ok! ? AppColors.acc : AppColors.red,
          size: 16,
        ),
    ]);
  }
}

class _CampoChave extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscuro;
  final VoidCallback onToggle;
  const _CampoChave({
    required this.controller,
    required this.hint,
    required this.obscuro,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.bord),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscuro,
        style: const TextStyle(color: AppColors.tx, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.mu, fontSize: 12),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          suffixIcon: IconButton(
            icon: Icon(
              obscuro ? Icons.visibility_off : Icons.visibility,
              color: AppColors.mu,
              size: 18,
            ),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }
}

class _DropdownEnvelope extends ConsumerWidget {
  final String? envelopeId;
  final bool salvando;
  final ValueChanged<String?> onChanged;
  const _DropdownEnvelope({
    required this.envelopeId,
    required this.salvando,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envelopesAsync = ref.watch(envelopesProvider);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.bord),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: envelopesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Carregando envelopes…',
              style: TextStyle(color: AppColors.mu, fontSize: 12)),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Erro: $e',
              style: const TextStyle(color: AppColors.red, fontSize: 12)),
        ),
        data: (envelopes) {
          final ids = envelopes.map((e) => e['id'] as String).toSet();
          final value = (envelopeId != null && ids.contains(envelopeId))
              ? envelopeId
              : null;
          return DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: AppColors.surf,
              value: value,
              hint: const Text('Selecionar envelope-alvo',
                  style: TextStyle(color: AppColors.mu, fontSize: 13)),
              icon: salvando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.acc),
                    )
                  : const Icon(Icons.arrow_drop_down, color: AppColors.mu),
              items: envelopes
                  .map((e) => DropdownMenuItem<String>(
                        value: e['id'] as String,
                        child: Text(
                          '${e['nome_envelope']}  '
                          '(R\$ ${(e['saldo_atual'] as num).toStringAsFixed(2)})',
                          style: const TextStyle(
                              color: AppColors.tx, fontSize: 13),
                        ),
                      ))
                  .toList(),
              onChanged: salvando ? null : onChanged,
            ),
          );
        },
      ),
    );
  }
}

class _DicaCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bord),
      ),
      child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.tips_and_updates_outlined,
                  color: AppColors.mu, size: 16),
              SizedBox(width: 6),
              Text('Como obter as chaves',
                  style: TextStyle(
                      color: AppColors.tx,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ]),
            SizedBox(height: 10),
            Text('Gemini API Key:',
                style: TextStyle(color: AppColors.acc, fontSize: 12)),
            Text('1. Acesse aistudio.google.com',
                style: TextStyle(color: AppColors.mu, fontSize: 12)),
            Text('2. Clique em "Get API key" → "Create API key"',
                style: TextStyle(color: AppColors.mu, fontSize: 12)),
            Text('3. Copie e cole no campo acima',
                style: TextStyle(color: AppColors.mu, fontSize: 12)),
            SizedBox(height: 10),
            Text('MongoDB URI:',
                style: TextStyle(color: AppColors.acc, fontSize: 12)),
            Text('• Local (Docker): mongodb://localhost:27017',
                style: TextStyle(color: AppColors.mu, fontSize: 12)),
            Text('• MongoDB Atlas: mongodb+srv://user:pass@cluster.mongodb.net',
                style: TextStyle(color: AppColors.mu, fontSize: 12)),
          ]),
    );
  }
}
