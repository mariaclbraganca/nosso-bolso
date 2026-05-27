import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_theme.dart';
import '../../providers/saude_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/saude_api_service.dart';

class RegistrarRefeicaoSheet extends ConsumerStatefulWidget {
  final String membroId;
  final String familiaId;

  const RegistrarRefeicaoSheet({super.key, required this.membroId, required this.familiaId});

  @override
  ConsumerState<RegistrarRefeicaoSheet> createState() => _RegistrarRefeicaoSheetState();
}

class _RegistrarRefeicaoSheetState extends ConsumerState<RegistrarRefeicaoSheet> {
  String _modalidade = 'texto'; // texto | foto | barcode
  String _tipoRefeicao = 'almoco';
  bool _isCheatMeal = false;
  bool _loading = false;
  final _textoCtrl = TextEditingController();

  // Resultado após análise IA
  Map<String, dynamic>? _analise;
  bool _aguardandoClarificacao = false;
  String? _perguntaClarificacao;

  // Barcode
  String? _barcodeEncontrado;

  // Replicar para membros
  final Set<String> _replicarPara = {};

  // Refeições recentes para atalhos
  List<Map<String, dynamic>> _recentes = [];

  @override
  void initState() {
    super.initState();
    _carregarRecentes();
  }

  Future<void> _carregarRecentes() async {
    try {
      final lista = await SaudeApiService.getRefeicoeRecentes(widget.membroId);
      if (mounted) setState(() => _recentes = lista);
    } catch (_) {}
  }

  void _usarRecente(Map<String, dynamic> recente) {
    setState(() {
      _tipoRefeicao = recente['tipo_refeicao'] as String? ?? _tipoRefeicao;
      _analise = {
        'descricao': recente['descricao'] ?? '',
        'itens_identificados': recente['itens_identificados'] ?? [],
        'totais': recente['macros_totais'] ?? {},
        'confianca': recente['confianca_ia'] ?? 0.8,
      };
      _aguardandoClarificacao = false;
    });
  }

  @override
  void dispose() {
    _textoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.98,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.bord, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Registrar Refeição',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.tx)),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.mu),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            _buildModalidadeSelector(),
            _buildTipoRefeicaoSelector(),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_analise == null) _buildEntrada(),
                    if (_aguardandoClarificacao) _buildClarificacao(),
                    if (_analise != null) _buildConfirmacao(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            if (_loading)
              const LinearProgressIndicator(color: AppColors.grn, backgroundColor: AppColors.bord),
          ],
        ),
      ),
    );
  }

  Widget _buildModalidadeSelector() {
    final opcoes = [
      ('texto', Icons.edit_rounded, 'Texto'),
      ('foto', Icons.camera_alt_rounded, 'Foto'),
      ('barcode', Icons.qr_code_scanner_rounded, 'Código'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: opcoes.map((o) {
          final isSelected = _modalidade == o.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() { _modalidade = o.$1; _analise = null; }),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.grn.withOpacity(0.15) : AppColors.surf,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.grn : AppColors.bord,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(o.$2, color: isSelected ? AppColors.grn : AppColors.mu, size: 20),
                    const SizedBox(height: 4),
                    Text(o.$3, style: TextStyle(fontSize: 11, color: isSelected ? AppColors.grn : AppColors.mu)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTipoRefeicaoSelector() {
    final tipos = [
      ('cafe_da_manha', '☕ Café'),
      ('almoco', '🍽 Almoço'),
      ('lanche_tarde', '🍪 Lanche'),
      ('jantar', '🌙 Jantar'),
      ('ceia', '🌛 Ceia'),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: tipos.map((t) {
          final isSelected = _tipoRefeicao == t.$1;
          return GestureDetector(
            onTap: () => setState(() => _tipoRefeicao = t.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.grn.withOpacity(0.15) : AppColors.surf,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppColors.grn : AppColors.bord),
              ),
              child: Text(
                t.$2,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? AppColors.grn : AppColors.mu,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEntrada() {
    if (_modalidade == 'texto') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('RECENTES', style: TextStyle(fontSize: 10, color: AppColors.mu, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _recentes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final r = _recentes[i];
                  final desc = (r['descricao'] as String? ?? '').trim();
                  final label = desc.length > 28 ? '${desc.substring(0, 28)}…' : desc;
                  return GestureDetector(
                    onTap: () => _usarRecente(r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      decoration: BoxDecoration(
                        color: AppColors.grn.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.grn.withOpacity(0.3)),
                      ),
                      alignment: Alignment.center,
                      child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.grn)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.bord, height: 1),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _textoCtrl,
            style: const TextStyle(color: AppColors.tx),
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Ex: comi 200g de frango grelhado com arroz branco e salada...',
              hintStyle: TextStyle(color: AppColors.mu, fontSize: 13),
              filled: true,
              fillColor: AppColors.surf,
              border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
              contentPadding: EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.grn,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Analisar com IA', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _loading ? null : _analisarTexto,
            ),
          ),
        ],
      );
    }

    if (_modalidade == 'foto') {
      return Column(
        children: [
          const SizedBox(height: 20),
          _BotaoGrande(
            icon: Icons.photo_library_rounded,
            label: 'Escolher da Galeria',
            color: AppColors.blu,
            onTap: () => _capturaFoto(ImageSource.gallery),
          ),
          const SizedBox(height: 12),
          _BotaoGrande(
            icon: Icons.camera_alt_rounded,
            label: 'Tirar Foto',
            color: AppColors.acc,
            onTap: () => _capturaFoto(ImageSource.camera),
          ),
        ],
      );
    }

    // barcode
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text('Aponte para o código de barras', style: TextStyle(color: AppColors.mu, fontSize: 13)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              onDetect: (capture) {
                final barcode = capture.barcodes.firstOrNull?.rawValue;
                if (barcode != null && !_loading) {
                  _buscarBarcode(barcode);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClarificacao() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.org.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.org.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.help_outline_rounded, color: AppColors.org, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _perguntaClarificacao ?? '',
                  style: const TextStyle(color: AppColors.tx, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _textoCtrl,
          style: const TextStyle(color: AppColors.tx),
          decoration: const InputDecoration(
            hintText: 'Responda para calcular os macros...',
            hintStyle: TextStyle(color: AppColors.mu),
            filled: true,
            fillColor: AppColors.surf,
            border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
            contentPadding: EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.org,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _loading ? null : _responderClarificacao,
            child: const Text('Responder e Calcular'),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmacao() {
    final analise = _analise!;
    final totais = analise['totais'] as Map<String, dynamic>? ?? {};
    final itens = analise['itens_identificados'] as List? ?? [];
    final confianca = (analise['confianca'] as num?)?.toDouble() ?? 0.0;

    final membros = ref.watch(listaUsuariosProvider).asData?.value ?? [];
    final outrosMembros = membros.where((m) => m['id'] != widget.membroId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.grn.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grn.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                analise['descricao'] as String? ?? '',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.tx),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _macroChip('${(totais['calorias_kcal'] as num?)?.toInt() ?? 0} kcal', AppColors.acc),
                  _macroChip('P: ${(totais['proteina_g'] as num?)?.toInt() ?? 0}g', AppColors.blu),
                  _macroChip('C: ${(totais['carboidrato_g'] as num?)?.toInt() ?? 0}g', AppColors.org),
                  _macroChip('G: ${(totais['gordura_g'] as num?)?.toInt() ?? 0}g', AppColors.pur),
                ],
              ),
              if (confianca > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Confiança da IA: ${(confianca * 100).toInt()}%',
                  style: TextStyle(fontSize: 11, color: confianca > 0.7 ? AppColors.grn : AppColors.org),
                ),
              ],
            ],
          ),
        ),
        if (itens.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Itens identificados:', style: TextStyle(fontSize: 12, color: AppColors.mu)),
          const SizedBox(height: 4),
          ...itens.map((item) {
            final i = item as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '• ${i['nome'] ?? ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.tx),
                    ),
                  ),
                  Text(
                    '${(i['peso_prato_g'] as num?)?.toInt() ?? 0}g — ${(i['calorias_kcal'] as num?)?.toInt() ?? 0}kcal',
                    style: const TextStyle(fontSize: 11, color: AppColors.mu),
                  ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 16),
        // Toggle cheat meal
        GestureDetector(
          onTap: () => setState(() => _isCheatMeal = !_isCheatMeal),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isCheatMeal ? AppColors.org.withOpacity(0.1) : AppColors.surf,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _isCheatMeal ? AppColors.org : AppColors.bord),
            ),
            child: Row(
              children: [
                Icon(
                  _isCheatMeal ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  color: _isCheatMeal ? AppColors.org : AppColors.mu,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🎉 Refeição Livre', style: TextStyle(color: AppColors.tx, fontSize: 14, fontWeight: FontWeight.w500)),
                      Text('Não afeta metas do dia seguinte', style: TextStyle(color: AppColors.mu, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Replicar para membros
        if (outrosMembros.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Replicar para:', style: TextStyle(fontSize: 12, color: AppColors.mu)),
          const SizedBox(height: 6),
          ...outrosMembros.map((m) => CheckboxListTile(
            value: _replicarPara.contains(m['id']),
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _replicarPara.add(m['id'] as String);
                } else {
                  _replicarPara.remove(m['id']);
                }
              });
            },
            activeColor: AppColors.grn,
            title: Text(m['nome'] as String? ?? '', style: const TextStyle(color: AppColors.tx, fontSize: 13)),
            contentPadding: EdgeInsets.zero,
            dense: true,
          )),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.grn,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _loading ? null : _confirmarRefeicao,
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _macroChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Future<void> _analisarTexto() async {
    final texto = _textoCtrl.text.trim();
    if (texto.isEmpty) return;
    setState(() => _loading = true);
    try {
      final resp = await SaudeApiService.registrarRefeicao({
        'membro_id': widget.membroId,
        'familia_id': widget.familiaId,
        'modalidade_entrada': 'texto',
        'dados_entrada': {'texto': texto},
        'tipo_refeicao': _tipoRefeicao,
        'apenas_analisar': true,
      });

      if (resp['status'] == 'aguardando_clarificacao') {
        setState(() {
          _aguardandoClarificacao = true;
          _perguntaClarificacao = resp['pergunta_agente'] as String?;
          _textoCtrl.clear();
          _loading = false;
        });
      } else {
        setState(() {
          _analise = resp;
          _aguardandoClarificacao = false;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _responderClarificacao() async {
    final resposta = _textoCtrl.text.trim();
    if (resposta.isEmpty) return;
    setState(() => _loading = true);
    try {
      final resp = await SaudeApiService.registrarRefeicao({
        'membro_id': widget.membroId,
        'familia_id': widget.familiaId,
        'modalidade_entrada': 'texto',
        'dados_entrada': {'texto': resposta},
        'tipo_refeicao': _tipoRefeicao,
        'apenas_analisar': true,
        'contexto_clarificacao': _perguntaClarificacao,
      });

      if (resp['status'] == 'aguardando_clarificacao') {
        setState(() {
          _perguntaClarificacao = resp['pergunta_agente'] as String?;
          _textoCtrl.clear();
          _loading = false;
        });
      } else {
        setState(() {
          _analise = resp;
          _aguardandoClarificacao = false;
          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _capturaFoto(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 65, maxWidth: 1024);
    if (file == null) return;
    setState(() => _loading = true);
    try {
      final bytes = await file.readAsBytes();
      final base64 = base64Encode(bytes);
      final resp = await SaudeApiService.registrarRefeicao({
        'membro_id': widget.membroId,
        'familia_id': widget.familiaId,
        'modalidade_entrada': 'foto',
        'dados_entrada': {'imagem_base64': base64, 'mime_type': 'image/jpeg'},
        'tipo_refeicao': _tipoRefeicao,
        'apenas_analisar': true,
      });
      setState(() { _analise = resp; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao analisar foto: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _buscarBarcode(String barcode) async {
    if (_barcodeEncontrado == barcode) return;
    setState(() { _barcodeEncontrado = barcode; _loading = true; });
    try {
      final produto = await SaudeApiService.getProdutoBarcode(barcode, widget.familiaId);
      if (produto != null) {
        final macros = produto['macros_por_100g'] as Map<String, dynamic>? ?? {};
        setState(() {
          _analise = {
            'descricao': produto['nome'] as String? ?? barcode,
            'itens_identificados': [{
              'nome': produto['nome'] ?? barcode,
              'peso_prato_g': 100,
              'fator_coccao': 1.0,
              'peso_cru_g': 100,
              'unidade_medida': 'g',
              'calorias_kcal': macros['calorias_kcal'] ?? 0,
              'proteina_g': macros['proteina_g'] ?? 0,
              'carboidrato_g': macros['carboidrato_g'] ?? 0,
              'gordura_g': macros['gordura_g'] ?? 0,
            }],
            'totais': macros,
            'confianca': 1.0,
            'fonte': produto['fonte'],
          };
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produto não encontrado. Use texto ou foto.')),
          );
        }
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmarRefeicao() async {
    if (_analise == null) return;
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final data = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await SaudeApiService.registrarRefeicao({
        'membro_id': widget.membroId,
        'familia_id': widget.familiaId,
        'tipo_refeicao': _tipoRefeicao,
        'modalidade_entrada': _modalidade,
        'descricao': _analise!['descricao'],
        'itens_identificados': _analise!['itens_identificados'] ?? [],
        'macros_totais': _analise!['totais'] ?? {},
        'confianca_ia': _analise!['confianca'] ?? 0.0,
        'confirmado_usuario': true,
        'is_cheat_meal': _isCheatMeal,
        'data_refeicao': data,
        'replicar_para': _replicarPara.toList(),
        'modo_replicacao': 'igual',
      });

      ref.invalidate(extratoDiarioProvider);
      ref.invalidate(refeicoesDiaProvider);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }
}

class _BotaoGrande extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BotaoGrande({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
