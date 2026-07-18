import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../services/saude_api_service.dart';
import '../../../providers/saude_provider.dart';

class AnamneseScreen extends ConsumerStatefulWidget {
  final String membroId;

  const AnamneseScreen({super.key, required this.membroId});

  @override
  ConsumerState<AnamneseScreen> createState() => _AnamneseScreenState();
}

class _AnamneseScreenState extends ConsumerState<AnamneseScreen> {
  int _step = 0;
  bool _isLoading = false;

  // Form fields
  final _idadeCtrl  = TextEditingController();
  final _pesoCtrl   = TextEditingController();
  final _alturaCtrl = TextEditingController();
  String _sexo      = 'masculino';
  String _objetivo  = 'manter_peso';
  String _nivel     = 'sedentario';

  static const _sexos = [
    ('masculino', '♂️ Masculino'),
    ('feminino',  '♀️ Feminino'),
  ];

  static const _objetivos = [
    ('perder_peso',  '🔻 Perder peso'),
    ('manter_peso',  '⚖️ Manter peso'),
    ('ganhar_massa', '💪 Ganhar massa'),
  ];

  static const _niveis = [
    ('sedentario',        '🛋️ Sedentário'),
    ('levemente_ativo',   '🚶 Levemente ativo'),
    ('moderadamente_ativo','🏃 Moderado'),
    ('muito_ativo',       '⚡ Muito ativo'),
    ('extremamente_ativo','🔥 Atleta'),
  ];

  @override
  void dispose() {
    _idadeCtrl.dispose();
    _pesoCtrl.dispose();
    _alturaCtrl.dispose();
    super.dispose();
  }

  Future<void> _finalizar() async {
    final idade  = int.tryParse(_idadeCtrl.text);
    final peso   = double.tryParse(_pesoCtrl.text.replaceAll(',', '.'));
    final altura = double.tryParse(_alturaCtrl.text.replaceAll(',', '.'));

    if (idade == null || peso == null || altura == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos'), backgroundColor: AppColors.org),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SaudeApiService.criarPerfilMetabolico({
        'membro_id':        widget.membroId,
        'sexo':             _sexo,
        'idade_anos':       idade,
        'peso_kg':          peso,
        'altura_cm':        altura,
        'nivel_atividade':  _nivel,
        'objetivo':         _objetivo,
      });
      ref.invalidate(perfilMetabolicoProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil criado! '), backgroundColor: AppColors.grn),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text('Meu Plano Nutricional', style: AppTextStyles.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.tx),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: AppColors.bord,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.grn),
          ),
        ),
      ),
      body: IndexedStack(
        index: _step,
        children: [
          _buildStep0(),
          _buildStep1(),
          _buildStep2(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildStep0() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊 Seus dados', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.tx)),
          const SizedBox(height: 8),
          const Text('Usaremos para calcular sua TMB e metas calóricas.', style: TextStyle(color: AppColors.mu, fontSize: 14)),
          const SizedBox(height: 24),
          _field(_idadeCtrl, 'Idade (anos)', TextInputType.number),
          const SizedBox(height: 12),
          _field(_pesoCtrl,   'Peso (kg)', TextInputType.number),
          const SizedBox(height: 12),
          _field(_alturaCtrl, 'Altura (cm)', TextInputType.number),
          const SizedBox(height: 20),
          const Text('Sexo biológico', style: TextStyle(color: AppColors.mu, fontSize: 13)),
          const SizedBox(height: 8),
          _chipRow(_sexos, _sexo, (v) => setState(() => _sexo = v)),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎯 Seu objetivo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.tx)),
          const SizedBox(height: 8),
          const Text('O que você quer alcançar com seu plano?', style: TextStyle(color: AppColors.mu, fontSize: 14)),
          const SizedBox(height: 24),
          _chipColumn(_objetivos, _objetivo, (v) => setState(() => _objetivo = v)),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏃 Nível de atividade', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.tx)),
          const SizedBox(height: 8),
          const Text('Com que frequência você se exercita?', style: TextStyle(color: AppColors.mu, fontSize: 14)),
          const SizedBox(height: 24),
          _chipColumn(_niveis, _nivel, (v) => setState(() => _nivel = v)),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      color: AppColors.surf,
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.bord),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
                ),
                child: const Text('Voltar', style: TextStyle(color: AppColors.mu)),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () {
                if (_step < 2) {
                  setState(() => _step++);
                } else {
                  _finalizar();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.grn,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_step < 2 ? 'Próximo' : 'Criar meu plano', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.caption,
        filled: true,
        fillColor: AppColors.surf,
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn), borderSide: const BorderSide(color: AppColors.bord)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn), borderSide: const BorderSide(color: AppColors.bord)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusBtn), borderSide: const BorderSide(color: AppColors.grn, width: 1.5)),
      ),
    );
  }

  Widget _chipRow(List<(String, String)> opts, String current, ValueChanged<String> onTap) {
    return Row(
      children: opts.map((o) {
        final sel = current == o.$1;
        return GestureDetector(
          onTap: () => onTap(o.$1),
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? AppColors.grn.withOpacity(0.15) : AppColors.surf,
              borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
              border: Border.all(color: sel ? AppColors.grn : AppColors.bord, width: sel ? 1.5 : 1),
            ),
            child: Text(o.$2, style: TextStyle(color: sel ? AppColors.grn : AppColors.mu, fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
          ),
        );
      }).toList(),
    );
  }

  Widget _chipColumn(List<(String, String)> opts, String current, ValueChanged<String> onTap) {
    return Column(
      children: opts.map((o) {
        final sel = current == o.$1;
        return GestureDetector(
          onTap: () => onTap(o.$1),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: sel ? AppColors.grn.withOpacity(0.15) : AppColors.surf,
              borderRadius: BorderRadius.circular(AppSpacing.radiusBtn),
              border: Border.all(color: sel ? AppColors.grn : AppColors.bord, width: sel ? 1.5 : 1),
            ),
            child: Text(o.$2, style: TextStyle(color: sel ? AppColors.grn : AppColors.tx, fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
          ),
        );
      }).toList(),
    );
  }
}
