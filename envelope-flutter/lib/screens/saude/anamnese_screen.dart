import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          ['Seus Dados', 'Anamnese', 'Confirmação'][_etapa],
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
      ('sedentario', 'Sedentário', 'Pouco ou nenhum exercício'),
      ('leve', 'Leve', 'Exercício 1-3x/semana'),
      ('moderado', 'Moderado', 'Exercício 3-5x/semana'),
      ('intenso', 'Intenso', 'Exercício 6-7x/semana'),
      ('muito_intenso', 'Muito Intenso', 'Atleta / trabalho físico pesado'),
    ];
    const objetivos = [
      ('perda_peso', '⬇️ Emagrecer', 'Déficit de 500 kcal/dia'),
      ('manutencao', '↔️ Manter', 'Equilíbrio calórico'),
      ('ganho_massa', '⬆️ Ganhar Massa', 'Superávit de 250 kcal/dia'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dados Antropométricos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.tx)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _campo('Peso (kg)', _pesoCtrl, TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _campo('Altura (cm)', _alturaCtrl, TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _campo('Idade', _idadeCtrl, TextInputType.number)),
          ]),
          const SizedBox(height: 20),
          const Text('Sexo', style: TextStyle(fontSize: 13, color: AppColors.mu)),
          const SizedBox(height: 8),
          Row(children: [
            _sexoBtn('M', 'Masculino'),
            const SizedBox(width: 8),
            _sexoBtn('F', 'Feminino'),
          ]),
          const SizedBox(height: 20),
          const Text('Nível de Atividade', style: TextStyle(fontSize: 13, color: AppColors.mu)),
          const SizedBox(height: 8),
          ...niveis.map((n) => RadioListTile<String>(
            value: n.$1,
            groupValue: _nivelAtividade,
            onChanged: (v) => setState(() => _nivelAtividade = v!),
            activeColor: AppColors.grn,
            title: Text(n.$2, style: const TextStyle(color: AppColors.tx, fontSize: 14)),
            subtitle: Text(n.$3, style: const TextStyle(color: AppColors.mu, fontSize: 11)),
            contentPadding: EdgeInsets.zero,
            dense: true,
          )),
          const SizedBox(height: 20),
          const Text('Objetivo', style: TextStyle(fontSize: 13, color: AppColors.mu)),
          const SizedBox(height: 8),
          ...objetivos.map((o) => RadioListTile<String>(
            value: o.$1,
            groupValue: _objetivo,
            onChanged: (v) => setState(() => _objetivo = v!),
            activeColor: AppColors.grn,
            title: Text(o.$2, style: const TextStyle(color: AppColors.tx, fontSize: 14)),
            subtitle: Text(o.$3, style: const TextStyle(color: AppColors.mu, fontSize: 11)),
            contentPadding: EdgeInsets.zero,
            dense: true,
          )),
          const SizedBox(height: 20),
          const Text('Alergias / Intolerâncias', style: TextStyle(fontSize: 13, color: AppColors.mu)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _alergiasCtrl,
                style: const TextStyle(color: AppColors.tx),
                decoration: const InputDecoration(
                  hintText: 'Ex: lactose, glúten',
                  hintStyle: TextStyle(color: AppColors.mu),
                  filled: true,
                  fillColor: AppColors.surf,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.surf),
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
              child: const Text('Próximo — Anamnese', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                    child: Text(
                      'O agente nutricional vai fazer algumas perguntas sobre seus hábitos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.mu),
                    ),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Seu Perfil Metabólico',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.tx)),
          const SizedBox(height: 4),
          const Text('Confirme seus dados calculados:',
              style: TextStyle(fontSize: 13, color: AppColors.mu)),
          const SizedBox(height: 20),
          _infoRow('TMB (Taxa Metabólica Basal)', '${(met['tmb_kcal'] as num?)?.toInt() ?? 0} kcal'),
          _infoRow('TDEE (Gasto Total Diário)', '${(met['tdee_kcal'] as num?)?.toInt() ?? 0} kcal'),
          _infoRow('Meta Calórica Diária', '${(met['meta_calorica_kcal'] as num?)?.toInt() ?? 0} kcal'),
          const Divider(color: AppColors.bord, height: 24),
          _infoRow('Proteína Total', '${(macros['proteina_total_g'] as num?)?.toInt() ?? 0}g'),
          _infoRow('Proteína via Comida', '${(macros['proteina_via_comida_g'] as num?)?.toInt() ?? 0}g'),
          _infoRow('Carboidrato', '${(macros['carboidrato_g'] as num?)?.toInt() ?? 0}g'),
          _infoRow('Gordura', '${(macros['gordura_g'] as num?)?.toInt() ?? 0}g'),
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
                  : const Text('Confirmar e Entrar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
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
      _scrollToBottom();

      if (finalizado && dados != null) {
        await _calcularEAvancar(dados as Map<String, dynamic>);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _calcularEAvancar(Map<String, dynamic> dadosAnamnese) async {
    final perfil = ref.read(perfilUsuarioLogadoProvider).asData?.value;
    setState(() => _loading = true);
    try {
      final payload = {
        'membro_id': widget.membroId,
        'familia_id': perfil?['familia_id'] ?? '',
        'antropometria': {
          'peso_kg': double.tryParse(_pesoCtrl.text.replaceAll(',', '.')) ?? 70,
          'altura_cm': double.tryParse(_alturaCtrl.text.replaceAll(',', '.')) ?? 170,
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
