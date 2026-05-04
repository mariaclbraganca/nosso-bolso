import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../providers/usuarios_provider.dart';

class PerfilFamiliaScreen extends ConsumerStatefulWidget {
  const PerfilFamiliaScreen({super.key});

  @override
  ConsumerState<PerfilFamiliaScreen> createState() =>
      _PerfilFamiliaScreenState();
}

class _PerfilFamiliaScreenState extends ConsumerState<PerfilFamiliaScreen> {
  final _nomeCtrl = TextEditingController();
  final _membrosCtrl = TextEditingController();
  final _cestaAddCtrl = TextEditingController();
  final _restricaoAddCtrl = TextEditingController();

  List<String> _cesta = [];
  List<String> _restricoes = [];
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
  }

  String? get _familiaId {
    final perfil = ref.read(perfilUsuarioLogadoProvider).asData?.value;
    return perfil?['familia_id'] as String?;
  }

  Future<void> _carregarPerfil() async {
    final fid = _familiaId;
    if (fid == null) {
      if (mounted) setState(() => _carregando = false);
      return;
    }
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/v1/compras/perfil')
          .replace(queryParameters: {'familia_id': fid});
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _nomeCtrl.text = (data['nome_familia'] as String?) ?? '';
        _membrosCtrl.text =
            (data['num_membros'] as int?)?.toString() ?? '';
        _cesta = List<String>.from(
            (data['cesta_basica_inegociavel'] as List?) ?? []);
        _restricoes = List<String>.from(
            (data['restricoes_alimentares'] as List?) ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _salvar() async {
    final fid = _familiaId;
    if (fid == null) return;
    setState(() => _salvando = true);
    try {
      final body = <String, dynamic>{'familia_id': fid};
      final nome = _nomeCtrl.text.trim();
      if (nome.isNotEmpty) body['nome_familia'] = nome;
      final membros = int.tryParse(_membrosCtrl.text.trim());
      if (membros != null && membros > 0) body['num_membros'] = membros;
      body['cesta_basica_inegociavel'] = _cesta;
      body['restricoes_alimentares'] = _restricoes;

      final uri = Uri.parse('${ApiService.baseUrl}/api/v1/compras/perfil');
      final resp = await http.patch(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body));
      if (resp.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Perfil salvo com sucesso!'),
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
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _addItem(List<String> lista, TextEditingController ctrl) {
    final txt = ctrl.text.trim();
    if (txt.isEmpty || lista.contains(txt)) return;
    setState(() => lista.add(txt));
    ctrl.clear();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _membrosCtrl.dispose();
    _cestaAddCtrl.dispose();
    _restricaoAddCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Perfil da Família')),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.acc))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildInfo(),
                const SizedBox(height: 24),
                _buildField('Nome da Família', _nomeCtrl, 'Ex: Família Silva'),
                const SizedBox(height: 16),
                _buildField('Nº de Membros', _membrosCtrl, 'Ex: 4',
                    numeric: true),
                const SizedBox(height: 28),
                _buildChipSection(
                  icon: Icons.shopping_basket,
                  label: 'Cesta Básica Inegociável',
                  hint: 'Arroz, Feijão, Leite…',
                  lista: _cesta,
                  ctrl: _cestaAddCtrl,
                ),
                const SizedBox(height: 28),
                _buildChipSection(
                  icon: Icons.no_food_outlined,
                  label: 'Restrições Alimentares',
                  hint: 'Sem glúten, Sem lactose…',
                  lista: _restricoes,
                  ctrl: _restricaoAddCtrl,
                ),
                const SizedBox(height: 36),
                _buildSaveButton(),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.acc.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.acc.withAlpha(60)),
      ),
      child: const Row(children: [
        Icon(Icons.info_outline, color: AppColors.acc, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Esses dados ajudam a IA a gerar listas de compras '
            'personalizadas para sua família.',
            style: TextStyle(color: AppColors.acc, fontSize: 12),
          ),
        ),
      ]),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint,
      {bool numeric = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              color: AppColors.tx, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.bord),
        ),
        child: TextField(
          controller: ctrl,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: AppColors.tx, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.mu, fontSize: 12),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ),
    ]);
  }

  Widget _buildChipSection({
    required IconData icon,
    required String label,
    required String hint,
    required List<String> lista,
    required TextEditingController ctrl,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: AppColors.acc, size: 18),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: AppColors.tx,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('${lista.length} itens',
            style: const TextStyle(color: AppColors.mu, fontSize: 11)),
      ]),
      const SizedBox(height: 10),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: lista
            .map((item) => Chip(
                  label: Text(item,
                      style:
                          const TextStyle(color: AppColors.tx, fontSize: 12)),
                  backgroundColor: AppColors.card,
                  side: const BorderSide(color: AppColors.bord),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  deleteIconColor: AppColors.mu,
                  onDeleted: () => setState(() => lista.remove(item)),
                ))
            .toList(),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.bord),
            ),
            child: TextField(
              controller: ctrl,
              style: const TextStyle(color: AppColors.tx, fontSize: 13),
              onSubmitted: (_) => _addItem(lista, ctrl),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.mu, fontSize: 12),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _addItem(lista, ctrl),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.acc,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add, color: Colors.black, size: 20),
          ),
        ),
      ]),
    ]);
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.acc,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          _salvando ? 'Salvando…' : 'Salvar Perfil',
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        onPressed: _salvando ? null : _salvar,
      ),
    );
  }
}
