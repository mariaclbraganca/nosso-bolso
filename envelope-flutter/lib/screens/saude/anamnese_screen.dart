import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../providers/saude_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/saude_api_service.dart';
import 'saude_navigation_screen.dart';

class AnamneseScreen extends ConsumerStatefulWidget {
  final String membroId;
  const AnamneseScreen({super.key, required this.membroId});

  @override
  ConsumerState<AnamneseScreen> createState() => _AnamneseScreenState();
}

class _AnamneseScreenState extends ConsumerState<AnamneseScreen> {
  int _etapa = 0;
  bool _loading = false;

  // Etapa 1 — campos do formulário
  final _pesoCtrl = TextEditingController();
  final _alturaCtrl = TextEditingController();
  final _idadeCtrl = TextEditingController();
  String _sexo = 'M';
  String _nivelAtividade = 'moderado';
  String _objetivo = 'manutencao';
  final List<String> _alergias = [];
  final _alergiasCtrl = TextEditingController();

  // Etapa 2 — chat de anamnese
  final List<Map<String, String>> _historico = [];
  final _chatCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Etapa 3 — confirmação
  Map<String, dynamic>? _perfilCalculado;

  String get _prefKey => 'anamnese_${widget.membroId}';

  @override
  void initState() {
    super.initState();
    _restaurarEstado();
  }

  Future<void> _restaurarEstado() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _etapa = (data['etapa'] as int?) ?? 0;
        _pesoCtrl.text = data['peso'] as String? ?? '';
        _alturaCtrl.text = data['altura'] as String? ?? '';
        _idadeCtrl.text = data['idade'] as String? ?? '';
        _sexo = data['sexo'] as String? ?? 'M';
        _nivelAtividade = data['nivel_atividade'] as String? ?? 'moderado';
        _objetivo = data['objetivo'] as String? ?? 'manutencao';
        _alergias.addAll((data['alergias'] as List<dynamic>?)?.cast<String>() ?? []);
        final hist = data['historico'] as List<dynamic>? ?? [];
        _historico.addAll(hist.map((e) => Map<String, String>.from(e as Map)));
      });
      if (_etapa == 1 && _historico.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {}
  }

  Future<void> _salvarEstado() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode({
      'etapa': _etapa,
      'peso': _pesoCtrl.text,
      'altura': _alturaCtrl.text,
      'idade': _idadeCtrl.text,
      'sexo': _sexo,
      'nivel_atividade': _nivelAtividade,
      'objetivo': _objetivo,
      'alergias': _alergias,
      'historico': _historico,
    }));
  }

  Future<void> _limparEstado() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  @override
  void dispose() {
    _pesoCtrl.dispose();
    _alturaCtrl.dispose();
    _idadeCtrl.dispose();
    _alergiasCtrl.dispose();
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          ['Seus Dados', 'Conhecendo Você', 'Tudo Pronto! 🎉'][_etapa],
          style: const TextStyle(color: AppColors.tx),
        ),
        leading: BackButton(color: AppColors.mu),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_etapa + 1) / 3,
            backgroundColor: AppColors.bord,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.grn),
          ),
        ),
      ),
      body: [
        _buildEtapa1(),
        _buildEtapa2(),
        _buildEtapa3(),
      ][_etapa],
    );
  }

  Widget _buildEtapa1() {
    const niveis = [
      ('sedentario', '🛋️', 'Fico muito parado(a)', 'Não costumo me exercitar'),
      ('leve', '🚶', 'Me mexo um pouco', 'Caminho ou exercito 1–3x por semana'),
      ('moderado', '🏃', 'Treino regularmente', 'Exercito 3–5x por semana'),
      ('intenso', '💪', 'Treino pesado', 'Exercito quase todo dia'),
      ('muito_intenso', '🏅', 'Sou atleta / trabalho físico', 'Atividade intensa diária'),
    ];
    const objetivos = [
      ('perda_peso', '⬇️', 'Emagrecer', 'Quero perder gordura'),
      ('manutencao', '↔️', 'Manter', 'Estou bem do jeito que estou'),
      ('ganho_massa', '⬆️', 'Ganhar massa', 'Quero ficar mais forte'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Seus dados corporais', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.tx)),
          const SizedBox(height: 4),
          const Text('Preciso desses dados para calcular suas necessidades calóricas.', style: TextStyle(fontSize: 12, color: AppColors.mu)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _campo('Peso (kg)', _pesoCtrl, TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _campo('Altura (cm)', _alturaCtrl, TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _campo('Idade', _idadeCtrl, TextInputType.number)),
          ]),
          const SizedBox(height: 20),
          const Text('Sexo biológico', style: TextStyle(fontSize: 13, color: AppColors.mu)),
          const SizedBox(height: 8),
          Row(children: [
            _sexoBtn('M', '♂ Masculino'),
            const SizedBox(width: 8),
            _sexoBtn('F', '♀ Feminino'),
          ]),
          const SizedBox(height: 24),
          const Text('Como é sua rotina de atividade física?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.tx)),
          const SizedBox(height: 10),
          ...niveis.map((n) {
            final isSelected = _nivelAtividade == n.$1;
            return GestureDetector(
              onTap: () => setState(() => _nivelAtividade = n.$1),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.grn.withOpacity(0.1) : AppColors.surf,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.grn : AppColors.bord,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Row(children: [
                  Text(n.$2, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.$3, style: TextStyle(
                        color: isSelected ? AppColors.grn : AppColors.tx,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                      )),
                      Text(n.$4, style: const TextStyle(color: AppColors.mu, fontSize: 11)),
                    ],
                  )),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded, color: AppColors.grn, size: 18),
                ]),
              ),
            );
          }),
          const SizedBox(height: 24),
          const Text('Qual é o seu objetivo?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.tx)),
          const SizedBox(height: 10),
          Row(children: [
            for (int i = 0; i < objetivos.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: Builder(builder: (_) {
                final o = objetivos[i];
                final isSelected = _objetivo == o.$1;
                return GestureDetector(
                  onTap: () => setState(() => _objetivo = o.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.grn.withOpacity(0.1) : AppColors.surf,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.grn : AppColors.bord,
                        width: isSelected ? 1.5 : 0.5,
                      ),
                    ),
                    child: Column(children: [
                      Text(o.$2, style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 4),
                      Text(o.$3, style: TextStyle(
                        color: isSelected ? AppColors.grn : AppColors.tx,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ), textAlign: TextAlign.center),
                      Text(o.$4, style: const TextStyle(color: AppColors.mu, fontSize: 10), textAlign: TextAlign.center),
                    ]),
                  ),
                );
              })),
            ],
          ]),
          const SizedBox(height: 24),
          const Text('Tem alguma restrição alimentar?', style: TextStyle(fontSize: 13, color: AppColors.mu)),
          const Text('Alergias, intolerâncias ou preferências', style: TextStyle(fontSize: 11, color: AppColors.mu)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _alergiasCtrl,
                style: const TextStyle(color: AppColors.tx),
                decoration: const InputDecoration(
                  hintText: 'Ex: lactose, glúten, carne vermelha...',
                  hintStyle: TextStyle(color: AppColors.mu),
                  filled: true,
                  fillColor: AppColors.surf,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.surf, elevation: 0),
              onPressed: () {
                final v = _alergiasCtrl.text.trim();
                if (v.isNotEmpty) {
                  setState(() { _alergias.add(v); _alergiasCtrl.clear(); });
                }
              },
              child: const Text('Add', style: TextStyle(color: AppColors.acc)),
            ),
          ]),
          if (_alergias.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _alergias.map((a) => Chip(
                label: Text(a, style: const TextStyle(fontSize: 12, color: AppColors.tx)),
                backgroundColor: AppColors.surf,
                deleteIconColor: AppColors.mu,
                onDeleted: () => setState(() => _alergias.remove(a)),
                side: const BorderSide(color: AppColors.bord),
              )).toList(),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.grn,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _avancarParaChat,
              child: const Text('Próximo →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEtapa2() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _historico.isEmpty ? 1 : _historico.length,
            itemBuilder: (_, i) {
              if (_historico.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('🤖', style: TextStyle(fontSize: 40)),
                      SizedBox(height: 12),
                      Text(
                        'Vou te fazer algumas perguntas rápidas para personalizar seu plano.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.tx, fontSize: 14),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Leva menos de 2 minutos!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.mu, fontSize: 12),
                      ),
                    ]),
                  ),
                );
              }
              final msg = _historico[i];
              final isUser = msg['role'] == 'user';
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.grn.withOpacity(0.2) : AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.bord, width: 0.5),
                  ),
                  child: Text(
                    msg['content'] ?? '',
                    style: TextStyle(color: isUser ? AppColors.grn : AppColors.tx, fontSize: 14),
                  ),
                ),
              );
            },
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(color: AppColors.grn, backgroundColor: AppColors.bord),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: const BoxDecoration(
            color: AppColors.surf,
            border: Border(top: BorderSide(color: AppColors.bord, width: 0.5)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatCtrl,
                    style: const TextStyle(color: AppColors.tx),
                    decoration: const InputDecoration(
                      hintText: 'Sua resposta...',
                      hintStyle: TextStyle(color: AppColors.mu),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: (_) => _enviarMensagem(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _enviarMensagem,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.grn,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEtapa3() {
    final p = _perfilCalculado;
    if (p == null) return const Center(child: CircularProgressIndicator(color: AppColors.grn));

    final met = p['metabolico'] as Map<String, dynamic>? ?? {};
    final macros = met['metas_macros'] as Map<String, dynamic>? ?? {};
    final tmb = (met['tmb_kcal'] as num?)?.toInt() ?? 0;
    final tdee = (met['tdee_kcal'] as num?)?.toInt() ?? 0;
    final meta = (met['meta_calorica_kcal'] as num?)?.toInt() ?? 0;
    final protComida = (macros['proteina_via_comida_g'] as num?)?.toInt() ?? 0;
    final carb = (macros['carboidrato_g'] as num?)?.toInt() ?? 0;
    final gord = (macros['gordura_g'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Seu plano está pronto!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.tx)),
          const SizedBox(height: 4),
          const Text('Calculei tudo com base nos seus dados. Aqui está o que seu corpo precisa por dia:', style: TextStyle(fontSize: 13, color: AppColors.mu)),
          const SizedBox(height: 20),
          _cardInfo('🔥', 'Você queima dormindo', '$tmb kcal', 'Seu metabolismo em repouso'),
          const SizedBox(height: 8),
          _cardInfo('⚡', 'Você gasta no dia a dia', '$tdee kcal', 'Incluindo sua rotina de atividades'),
          const SizedBox(height: 8),
          _cardInfo('🎯', 'Sua meta de calorias', '$meta kcal/dia', 'O alvo para atingir seu objetivo', destaque: true),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.bord, width: 0.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('DISTRIBUIÇÃO DOS NUTRIENTES', style: TextStyle(fontSize: 11, color: AppColors.mu, fontWeight: FontWeight.bold, letterSpacing: 0.6)),
              const SizedBox(height: 10),
              _infoRow('💪 Proteína', '${protComida}g'),
              _infoRow('🌾 Carboidrato', '${carb}g'),
              _infoRow('🥑 Gordura', '${gord}g'),
            ]),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.grn,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loading ? null : _confirmar,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Começar a usar meu plano! 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardInfo(String emoji, String titulo, String valor, String subtitulo, {bool destaque = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: destaque ? AppColors.grn.withOpacity(0.08) : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: destaque ? AppColors.grn.withOpacity(0.4) : AppColors.bord,
          width: destaque ? 1.5 : 0.5,
        ),
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: TextStyle(fontSize: 12, color: destaque ? AppColors.grn : AppColors.mu)),
          Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: destaque ? AppColors.grn : AppColors.tx)),
          Text(subtitulo, style: const TextStyle(fontSize: 11, color: AppColors.mu)),
        ])),
      ]),
    );
  }

  Widget _campo(String label, TextEditingController ctrl, TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: AppColors.tx),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.mu, fontSize: 12),
        filled: true,
        fillColor: AppColors.surf,
        border: const OutlineInputBorder(borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _sexoBtn(String value, String label) {
    final isSelected = _sexo == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _sexo = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.grn.withOpacity(0.2) : AppColors.surf,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.grn : AppColors.bord,
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.grn : AppColors.mu,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.mu)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.tx)),
        ],
      ),
    );
  }

  void _avancarParaChat() {
    final peso = double.tryParse(_pesoCtrl.text.replaceAll(',', '.'));
    final altura = double.tryParse(_alturaCtrl.text.replaceAll(',', '.'));
    final idade = int.tryParse(_idadeCtrl.text);
    if (peso == null || altura == null || idade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha peso, altura e idade.'), backgroundColor: AppColors.red),
      );
      return;
    }
    setState(() => _etapa = 1);
    _salvarEstado();
    _iniciarChat();
  }

  Future<void> _iniciarChat() async {
    setState(() => _loading = true);
    try {
      // Seed com uma mensagem inicial para que o backend não receba histórico vazio
      final seed = [{'role': 'user', 'content': 'Pode começar a anamnese.'}];
      final resp = await SaudeApiService.turnoAnamnese(seed);
      final agentMsg = resp['resposta_agente'] as String? ?? 'Olá! Vou fazer algumas perguntas sobre seus hábitos.';
      setState(() {
        _historico.add({'role': 'assistant', 'content': agentMsg});
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _historico.add({'role': 'assistant', 'content': 'Olá! Conte-me sobre seus suplementos e hábitos alimentares. Você toma algum suplemento regularmente?'});
        _loading = false;
      });
    }
  }

  Future<void> _enviarMensagem() async {
    final texto = _chatCtrl.text.trim();
    if (texto.isEmpty || _loading) return;
    _chatCtrl.clear();
    setState(() {
      _historico.add({'role': 'user', 'content': texto});
      _loading = true;
    });
    _salvarEstado();
    _scrollToBottom();
    try {
      final resp = await SaudeApiService.turnoAnamnese(List<Map<String, String>>.from(_historico));
      final agentMsg = resp['resposta_agente'] as String? ?? '';
      final finalizado = resp['finalizado'] == true;
      final dados = resp['dados_estruturados'];

      setState(() {
        _historico.add({'role': 'assistant', 'content': agentMsg});
        _loading = false;
      });
      _salvarEstado();
      _scrollToBottom();

      if (finalizado && dados != null) {
        await _calcularEAvancar(dados as Map<String, dynamic>);
      }
    } catch (e) {
      // Remove a mensagem do usuário do histórico para permitir reenvio
      setState(() {
        if (_historico.isNotEmpty && _historico.last['role'] == 'user') {
          _chatCtrl.text = _historico.last['content'] ?? '';
          _historico.removeLast();
        }
        _loading = false;
      });
      if (mounted) {
        final isTimeout = e.toString().contains('TimeoutException');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTimeout
                ? 'O servidor demorou demais. Tente novamente — pode ser cold start.'
                : 'Erro de conexão. Verifique sua internet e tente novamente.'),
            backgroundColor: AppColors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Reenviar',
              textColor: Colors.white,
              onPressed: _enviarMensagem,
            ),
          ),
        );
      }
    }
  }

  Future<void> _calcularEAvancar(Map<String, dynamic> dadosAnamnese) async {
    final perfil = ref.read(perfilUsuarioLogadoProvider).asData?.value;
    setState(() => _loading = true);
    try {
      final alturaRaw = double.tryParse(_alturaCtrl.text.replaceAll(',', '.')) ?? 170;
      // Usuários frequentemente digitam em metros (1.76) — converter para cm
      final alturaCm = alturaRaw < 3.0 ? alturaRaw * 100 : alturaRaw;

      final payload = {
        'membro_id': widget.membroId,
        'familia_id': perfil?['familia_id'] ?? '',
        'antropometria': {
          'peso_kg': double.tryParse(_pesoCtrl.text.replaceAll(',', '.')) ?? 70,
          'altura_cm': alturaCm,
          'idade': int.tryParse(_idadeCtrl.text) ?? 30,
          'sexo': _sexo,
        },
        'metabolico': {
          'nivel_atividade': _nivelAtividade,
          'objetivo': _objetivo,
        },
        'anamnese': {
          ...dadosAnamnese,
          'alergias': _alergias,
        },
      };
      final resultado = await SaudeApiService.criarPerfilMetabolico(payload);
      setState(() {
        _perfilCalculado = resultado;
        _loading = false;
        _etapa = 2;
      });
      await _limparEstado();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmar() async {
    if (!mounted) return;
    ref.invalidate(perfilMetabolicoProvider);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SaudeNavigationScreen()),
      (route) => false,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
